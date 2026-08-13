; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Functions that decode the tokenized program for display on the console.
; Most functions decode from the line pointed to by line_ptr, using line_pos as the read position,
; and decode into buffer, using buffer_pos as the write position.

; LIST statement:
; Scans through the program and prints each line.
; We use line_ptr and next_line_ptr to list the program.
; It's possible that LIST is being called from within the program, so we save the existing next_line_ptr value
; on the stack and restore it after so we can resume execution after the LIST statement.

exec_list:
        ldphaa  next_line_ptr
        ldpha   next_line_pos
        jsr     reset_next_line_ptr
        lda     #$FF
        sta     line_number             ; Set line number to max in case user did not provide arguments
        sta     line_number+1
        jsr     peek_byte               ; Look to see if there are arguments
        beq     @next_line              ; Nothing after LIST, just go
        cmp     #TOK_NUM
        bne     @next_line
        inc     line_pos                ; Skip TOK_NUM
        jsr     get_line_number         ; Go get start line number
        jsr     find_line               ; Stores the line number in line_number
        jsr     peek_byte               ; Anything else?
        beq     @next_line              ; Nope: the value in line_number becomes the terminating line number
        cmp     #TOK_COMMA
        bne     @next_line
        inc     line_pos                ; There's another arg, so skip over the ','
        jsr     peek_byte
        cmp     #TOK_NUM
        bne     @next_line
        inc     line_pos                ; Skip TOK_NUM
        jsr     get_line_number         ; Save the ending line number in line_number
        stax    line_number

@next_line:
        jsr     compare_next_line_to_target ; Verify we haven't crossed the ending line number
        bcc     @print                  ; < limit => print it 
        bne     @done                   ; > limit => stop listing

@print:
        mvaa    next_line_ptr, line_ptr
        jsr     list_line
        ldax    #buffer
        ldy     buffer_pos              ; buffer_pos will be the amount of data written to the buffer
        beq     @done                   ; If it was zero bytes then no more lines
        jsr     write
        jsr     newline
        jsr     advance_next_line_ptr
        jmp     @next_line

@done:
        plsta   next_line_pos
        plstaa  next_line_ptr
        rts

; Outputs a line with a line number and all statements separated by ':'.
; line_ptr = the line to write

list_line:
        mvy     #0, buffer_pos          ; Initialize write position in buffer (also set Y to next_line_offset)
        lda     (line_ptr),y            ; Next line offset into A
        beq     @done                   ; If it's the null statement then we're at the end of the program
        jsr     line_number_to_string
        mva     #.sizeof(Line), line_pos

@next:
        jsr     list_statement
        ldy     #0
        lda     line_pos                ; Current position
        cmp     (line_ptr),y            ; At next line offset?
        bcs     @done                   ; Yep
        lda     #':'                    ; Else write ':' and next statement
        jsr     append_buffer
        bcc     @next

@done:
        rts

; Outputs a statement.

list_statement:
        inc     line_pos                ; Skip past the next statement offset

@next_token:
        jsr     decode_byte             ; Get next token byte
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
        ldx     #0                      ; Search keyword_tokens for token in B
@find_keyword:
        cmp     keyword_tokens,x
        beq     @found_keyword
        inx
        cpx     #keyword_token_count
        bcc     @find_keyword
        bcs     @next_token

@found_keyword:
        pha                             ; Store the original token
        txa
        tay
        ldax    #keywords
        jsr     expand_tokenized_name
        pla                             ; Get back the original token
        cmp     #TOK_DATA
        beq     @list_rem_data
        cmp     #TOK_REM
        bne     @next_token

@list_rem_data:
        jsr     add_whitespace

@rem_data_loop:
        jsr     decode_byte
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
        jsr     decode_byte
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
        jsr     get_name                ; Get the statement name
        bcs     @done                   ; Shouldn't happen, but just in case
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
        pha                             ; Remember if EOT bit was set
        and     #<~EOT                  ; Clear if it was
        jsr     append_buffer
        iny
        pla
        bpl     @next_name_byte

@done:
        rts

; Adds whitespace to the output if necessary.
; Whitespace is necessary if buffer_pos > 0 and if buffer[buffer_pos-1] is a name character or is a ')' or '"'.
; Y SAFE, BC SAFE, DE SAFE

add_whitespace:
        ldx     buffer_pos              ; Current write position
        beq     @done                   ; Just return if it's zero
        lda     buffer-1,x              ; Get buffer[x-1]
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
