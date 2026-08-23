; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using line_pos as the read position,
; and render the line in buffer, using buffer_pos as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr and next_line_ptr to list the program.
; It's possible that LIST is being called from within the program, so we save the existing next_line_ptr value
; on the stack and restore it after so we can resume execution after the LIST statement.

.assert TOK_PRINT = $40, error

exec_list:
        ldphaa  next_line_ptr
        ldpha   next_line_pos
        jsr     reset_next_line_ptr
        lda     #$FF
        sta     line_number             ; Set line number to max in case user did not provide arguments
        sta     line_number+1
        jsr     peek_byte               ; Look to see if there are arguments
        beq     @next_line              ; Nothing after LIST, just go
        jsr     get_line_number         ; Go get start line number
        jsr     find_line               ; Stores the line number in line_number
        jsr     peek_byte               ; Anything else?
        beq     @next_line              ; Nope: the value in line_number becomes the terminating line number
        inc     line_pos                ; There's another arg, so skip over the ','
        jsr     get_line_number         ; Save the ending line number in line_number
        stax    line_number

@next_line:
        jsr     compare_next_line_to_target ; Verify we haven't crossed the ending line number
        bcc     @print                  ; < limit => print it 
        bne     @done                   ; > limit => stop listing

@print:
        mvaa    next_line_ptr, line_ptr
        jsr     list_line
        beq     @done                   ; If it was zero bytes then no more lines
        lday    #buffer
        jsr     print_string
        jsr     newline
        jsr     advance_next_line_ptr
        bne     @next_line              ; Unconditional: advance_next_line_ptr leaves Y=3 (Z=0)

@done:
        plsta   next_line_pos
        plstaa  next_line_ptr
        rts

; Outputs a line with a line number and all statements separated by ':'.
; line_ptr = the line to write

.assert Line::next_line_offset = 0, error

list_line:
        ldy     #Line::next_line_offset ; Load next_line_offset
        lda     (line_ptr),y
        beq     @null_line              ; If it's the null statement then we're at the end of the program
        jsr     line_number_to_fp
        jsr     fp_to_string
        mva     #.sizeof(Line), line_pos

@next:
        jsr     list_statement
        ldy     #Line::next_line_offset
        lda     line_pos                ; Current position
        cmp     (line_ptr),y            ; At next line offset?
        bcs     @finish                 ; Yep
        lda     #':'                    ; Else write ':' and next statement
        jsr     append_buffer
        bcc     @next

@finish:
        ldx     buffer_pos
        jmp     finalize_buffer_string

@null_line:
        sta     buffer                  ; Store 0 length
        rts

; Outputs a statement.

list_statement:
        inc     line_pos                ; Skip past the next statement offset

@next_token:
        jsr     get_byte                ; Get next token byte
        bne     @not_eol                ; 0 = TOK_EOL
@done:
        rts

@not_eol:
        cmp     #TOK_NUM
        beq     @list_num_or_name
        cmp     #TOK_NAME
        beq     @list_num_or_name
        cmp     #TOK_STRING
        beq     @list_string
        sta     C                       ; Save token in C
        lsr     A                       ; Divide by 16 to get block index of token
        lsr     A
        lsr     A
        lsr     A
        tax
        lda     C                       ; Intra-block offset
        and     #$0F
        clc
        adc     keyword_block_offsets,x ; Base keyword index for block
        tay
        ldax    #keywords
        jsr     expand_tokenized_name
        lda     C                       ; Get back the original token
        sbc     #TOK_PRINT              ; Range $40..$7F maps to 0..63 (C=1 from expand_tokenized_name)
        cmp     #64                     ; Statement token?
        bcs     @skip_statement_space
        jsr     peek_byte               ; Check if more tokens on line
        beq     @skip_statement_space   ; If at EOL, don't add space
        jsr     add_whitespace          ; Space after keyword (ignores '?')

@skip_statement_space:
        lda     C                       ; Get back original token
        cmp     #TOK_DATA
        beq     @rem_data_loop
        cmp     #TOK_REM
        bne     @next_token

@rem_data_loop:
        jsr     get_byte
        beq     @done
        jsr     append_buffer
        bne     @rem_data_loop          ; Unconditional

@list_string:
        jsr     add_whitespace
        inc     line_pos                ; Skip the length byte
        lda     #'"'
        bne     @append

@list_num_or_name:
        jsr     add_whitespace
@num_name_loop:
        jsr     get_byte
@append:
        pha
        and     #<~EOT
        jsr     append_buffer
        pla
        bpl     @num_name_loop
        bmi     @next_token             ; Unconditional


; Given a name table index obtained from a token, list the name from the name table.
; AX = pointer to the start of the name table
; Y = index number

expand_tokenized_name:
        jsr     lookup_name             ; Get the statement name
        ldy     #0
        lda     (name_ptr),y
        and     #<~EOT                  ; In case EOT is set
        sec
        sbc     #'?'                    ; Skip whitespace if character outside the range '?'-'Z'
        cmp     #28
        bcs     @next_name_byte
        jsr     add_whitespace

@next_name_byte:
        lda     (name_ptr),y
        cmp     #EOT                    ; Sets C=1 if EOT bit was set
        and     #<~EOT                  ; Clear if it was (preserves C)
        jsr     append_buffer           ; Preserves C
        iny                             ; Preserves C
        bcc     @next_name_byte         ; Loop if EOT was not set
        rts

; Adds whitespace to the output if necessary.
; Whitespace is necessary if buffer_pos > 0 and if buffer[buffer_pos-1] is a name character or is a ')' or '"'.
; Y SAFE, BC SAFE, DE SAFE

add_whitespace:
        ldx     buffer_pos              ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
        cmp     #'$'
        beq     append_buffer_space
        cmp     #')'
        beq     append_buffer_space
        cmp     #'"'
        beq     append_buffer_space
        cmp     #'_'
        beq     append_buffer_space
        sec
        sbc     #'0'
        cmp     #10
        bcc     append_buffer_space
        sbc     #'A'-'0'
        cmp     #26
        bcc     append_buffer_space

@done:
        rts

; Writes a single byte to buffer at position buffer_pos and increments buffer_pos.
; Does not check for buffer overflow; we assume this can't happen.
; INC will leave zero flag set as long as buffer_pos hasn't overrun.
; A = the byte to write (preserved)
; buffer_pos = the buffer position (updated)
; Y SAFE, BC SAFE, DE SAFE

append_buffer_space:
        lda     #' '

append_buffer:
        ldx     buffer_pos              ; Load position
        inc     buffer_pos              ; Increment position
        sta     buffer,x                ; Store A in buffer
        rts
