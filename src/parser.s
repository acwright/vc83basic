; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

; All "parse" functions use:
; buffer = the buffer containing the user-entered program source
; buffer_pos = the read position in buffer (modified on success)
; line_buffer = the buffer containing the tokenized output
; line_pos = the token write position in line_buffer (modified on success)

; Parses a line from the buffer. The line is an optional line number followed by statements.
; If the line number is missing, set it to -1.
; Returns normally if buffer was a valid program line, or raises an exception.

; We assume that RETURN is the first of a list of unparameterized opcodes in the range $F0-$FF.
.assert PVM_RETURN = $F0, error

parse_line:
        mva     #0, buffer_pos              ; Initialize the read pointer
        mva     #.sizeof(Line), line_pos    ; Initialize write pointer
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives work
        ldy     buffer_pos
        jsr     skip_whitespace
        jsr     string_to_fp_2          ; Parse line number
        sty     buffer_pos              ; Initialize buffer_pos to wherever the number ended
        bcs     @no_line_number         ; Line number was provided so store it
        jsr     truncate_fp_to_int      ; Truncate line number to integer
        bcc     @store_line_number
@no_line_number:
        lda     #$FF                    ; Otherwise store -1 ($FFFF) instead
        tax
@store_line_number:
        stax    line_buffer+Line::number
        ldy     buffer_pos
        jsr     skip_whitespace         ; Detect a blank line; returns non-blank character in A, may be zero
        beq     @finish_line            ; Was zero

; Parse one statement. The statement must be found because the line is not blank and this is either the first
; statement or we just parsed a ':'.

@next_statement:
        mva     line_pos, statement_line_pos        ; Save start of statement position
        inc     line_pos                ; Begin tokenizing statement at next position
        ldax    #pvm_statement
        jsr     parse_pvm
        lda     #0                      ; Store 0 at end of statement
        ldx     line_pos
        sta     line_buffer,x
        inc     line_pos
        lda     line_pos                ; Write position is next statement offset
        ldx     statement_line_pos      ; Store at start of statement
        sta     line_buffer,x
        ldy     buffer_pos              ; Look for statement separator
        jsr     skip_whitespace
        beq     @finish_line            ; Reached end of line
        iny                             ; Move past whatever other character it was and update buffer_pos
        sty     buffer_pos
        cmp     #':'                    ; If not EOL it has to be ':'
        beq     @next_statement         ; It was ':'
        bne     syntax_error            ; It wasn't

@finish_line:
        mva     line_pos, line_buffer+Line::next_line_offset    ; Write position is next line offset
        ldx     buffer_pos
        lda     buffer,x                ; Verify the line ends with 0 as expected
        bne     syntax_error            ; Nope, fail
        rts

syntax_error:
        raise   ERR_SYNTAX_ERROR

; Invokes parsing virtual machine (PVM).
; AX = address of first PVM opcode
; buffer_pos = where to read from buffer
; line_pos = where to write to line_buffer

parse_pvm:
        stax    pvm_program_ptr
        mvax    #buffer, read_ptr       ; Set up read_ptr so parsing primitives in util module work
        jsr     run_pvm_next_token
        bcs     syntax_error
        mva     D, buffer_pos           ; Put back the last token that was read but not matched
        mva     E, line_pos
        rts

; Resume processing opcodes.
; Returns carry clear if the parse succeeded, or carry set if it failed.
; Returns with pvm_program_ptr pointing to the opcode after the the one that caused run_pvm to exit,
; and the last opcode in B.

run_pvm_next_token:
        mva     buffer_pos, D           ; Save state so we can put back the last token
        mva     line_pos, E
        jsr     next_token              ; Clobbers BC, but we can use after
        sta     C                       ; Hold the token we just read in C
run_pvm:
        jsr     get_next_pvm_byte       ; Load PVM opcode

; Handle the opcode

        cmp     #PVM_RETURN
        bcc     @try_branch_if          ; Some opcode not in the $F0-FF range
        clc                             ; Return with carry set if it's RETURN
        beq     @return
        cmp     #PVM_SLURP
        beq     @slurp
        cmp     #PVM_GUARD
        beq     @guard
        sec                             ; Wan't anything else so treat as FAIL
@return:
        rts

@slurp:
        ldx     D                       ; Read from D (buffer_pos before speculative next_token)
        ldy     E                       ; Write to E (line_pos before speculative next_token)
@slurp_whitespace:
        lda     buffer,x
        beq     @done
        cmp     #' '
        bne     @slurp_next
        inx
        bne     @slurp_whitespace
@slurp_next:             
        lda     buffer,x
        beq     @done
        sta     line_buffer,y
        inx
        iny
        bne     @slurp_next
@done:
        stx     D
        sty     E
        clc                             ; There can't be anything more to parse so return success
        rts

@guard:
        jsr     get_next_pvm_byte       ; Read the token we want to match
        jsr     match_token
        bne     run_pvm                 ; If it didn't match then just carry on with the next instruction
        clc                             ; Else the guard stops this function and causes it to return success
        rts

@try_match:
        jsr     match_token
        beq     run_pvm_next_token      ; It matched; continue
@fail:
        sec                             ; Set carry to indicate failure and return
        rts

@try_branch_if:
        cmp     #PVM_BRANCH_IF
        bcc     @try_jump
        jsr     calculate_address_12    ; Get the address: call address in AX
        stax    vector_ptr
        jsr     get_next_pvm_byte       ; A is the byte we have to match
        jsr     match_token             ; Try to match it
        bne     run_pvm                 ; If it didn't match then just carry on
        mvax    vector_ptr, pvm_program_ptr     ; Continue at the branch address
        bne     run_pvm_next_token      ; Unconditional

@try_jump:
        cmp     #PVM_JUMP
        bcc     @try_call
        jsr     calculate_address_12    ; Get the address: call address in AX
        stax    pvm_program_ptr
        jmp     run_pvm
        
@try_call:
        cmp     #PVM_CALL
        bcc     @try_match
        jsr     calculate_address_12    ; Get the address: pvm_program_ptr is return address, call address in AX
        tay
        ldphaa  pvm_program_ptr         ; Save the return address
        sty     pvm_program_ptr
        stx     pvm_program_ptr+1       ; Save new address
        jsr     run_pvm                 ; Call it
        plstaa  pvm_program_ptr         ; Recover return address
        bcs     @fail                   ; If the called function failed then just keep failing
        jmp     run_pvm

; Matches the token in C with the opcode.
; A = the opcode
; Z flag will indicate whether it was matched or not
; X SAFE, Y SAFE, BC SAFE, DE SAFE

match_token:
        pha                             ; Push the original opcode
        cmp     #TOK_ANY_OP_2X          ; Tokens below this must be matched exactly
        bcc     @exact_match
        and     #$0F                    ; See if this is a class match
        bne     @exact_match            ; If not then do exact match
        pla                             ; Reload the opcode
        eor     C                       ; Class match: EOR the opcode with the token
        and     #$F0                    ; If top 4 bits match then they will be 0 and Z will be set
        rts

@exact_match:
        pla                             ; Reload the opcode
        cmp     C                       ; Compare opcode, now the token we need to match, to the next token
        rts

; Gets the next byte from the PVM program and returns it in A.
; Increments pvm_program_ptr.
; X SAFE, BC SAFE, DE SAFE

get_next_pvm_byte:
        ldy     #0
        lda     (pvm_program_ptr),y     ; Load PVM opcode
        inc     pvm_program_ptr
        bne     @skip_inc
        inc     pvm_program_ptr+1
@skip_inc:
        rts

; Calculates the address of JUMP or CALL using 4 bits from the opcode plus the next byte, for 12 bits total.
; A = the opcode
; Return the new pvm_program_ptr value in AX

calculate_address_12:
        and     #$0F                    ; Ignore top four bits of opcode
        cmp     #$08                    ; Test bit 3, which is the sign bit of the offset field
        bcc     @positive               ; Was positive so just leave it
        ora     #$F0                    ; Sign extend to high nybble
@positive:
        tax                             ; Save high byte
        jsr     get_next_pvm_byte  
        clc
        adc     pvm_program_ptr         ; Add to pvm_program_ptr
        pha
        txa
        adc     pvm_program_ptr+1
        tax
        pla
        rts

; PVM macros

.macro MATCH t
        .assert t < $C0, error, "Can only match tokens not opcodes"
        .byte t    
.endmacro

.macro write_opcode_address opcode, address
        .assert (address - (* + 2)) >= -2048 .and (address - (* + 2)) <= 2047, error, "Address offset out of range"
        .byte   opcode + >(address - (* + 2)) & $0F, <(address - (* + 1))
.endmacro

.macro CALL address
        write_opcode_address PVM_CALL, address
.endmacro

.macro JUMP address
        write_opcode_address PVM_JUMP, address
.endmacro

.macro BRANCH_IF token, address
        write_opcode_address PVM_BRANCH_IF, address
        .byte token
.endmacro

.macro RETURN
        .byte PVM_RETURN
.endmacro

.macro FAIL
        .byte PVM_FAIL
.endmacro

.macro GUARD token
        .byte PVM_GUARD, token
.endmacro

.macro SLURP
        .byte PVM_SLURP
.endmacro

; PVM program

pvm_statement:
        BRANCH_IF TOK_PRINT, pvm_print
        BRANCH_IF TOK_ALT_PRINT, pvm_print
        BRANCH_IF TOK_LET, pvm_let
        BRANCH_IF TOK_NAME, pvm_impl_let
        BRANCH_IF TOK_FOR, pvm_for
        BRANCH_IF TOK_NEXT, pvm_next
        BRANCH_IF TOK_IF, pvm_if
        BRANCH_IF TOK_INPUT, pvm_input
        BRANCH_IF TOK_READ, pvm_read
        BRANCH_IF TOK_ON, pvm_on
        BRANCH_IF TOK_GOTO, pvm_goto
        BRANCH_IF TOK_GOSUB, pvm_gosub
        BRANCH_IF TOK_LIST, pvm_list
        BRANCH_IF TOK_POKE, pvm_arg_2
        BRANCH_IF TOK_DPOKE, pvm_arg_2
        BRANCH_IF TOK_DIM, pvm_dim
        BRANCH_IF TOK_DATA, pvm_data
        BRANCH_IF TOK_REM, pvm_rem
        BRANCH_IF TOK_ANY_ST_8X, @done  ; Any other no-arg statement
        BRANCH_IF TOK_ANY_ST_9X, @done
        FAIL
@done:
        RETURN

; Statements

pvm_print:
        BRANCH_IF TOK_SEMI, pvm_print
        BRANCH_IF TOK_COMMA, pvm_print
        GUARD TOK_COLON                 ; Abandon the PRINT statement if we see COLON or EOL
        GUARD TOK_EOL
        CALL pvm_expression             ; Otherwise it has to be an expression
        JUMP pvm_print

pvm_let:
        MATCH TOK_NAME
pvm_impl_let:
        CALL pvm_optional_array
        MATCH TOK_EQ
        JUMP pvm_expression

pvm_for:
        MATCH TOK_NAME
        MATCH TOK_EQ
        CALL pvm_expression
        MATCH TOK_TO
        CALL pvm_expression
        BRANCH_IF TOK_STEP, pvm_expression
        RETURN

pvm_next:
        MATCH TOK_NAME
        RETURN

pvm_if:
        CALL pvm_expression
        MATCH TOK_THEN
        BRANCH_IF TOK_NUM, @done
        JUMP pvm_statement
@done:
        RETURN

pvm_input:
        BRANCH_IF TOK_STRING, @prompt
        JUMP pvm_read
@prompt:
        MATCH TOK_SEMI

pvm_read:
        MATCH TOK_NAME
        CALL pvm_optional_array
        BRANCH_IF TOK_COMMA, pvm_read
        RETURN

pvm_on:
        CALL pvm_expression
        BRANCH_IF TOK_GOTO, @line_number_list
        BRANCH_IF TOK_GOSUB, @line_number_list
        FAIL

@line_number_list:
        MATCH TOK_NUM
        BRANCH_IF TOK_COMMA, @line_number_list
        RETURN

pvm_goto:
pvm_gosub:
        MATCH TOK_NUM
        RETURN

pvm_list:
        GUARD TOK_COLON
        GUARD TOK_EOL
        CALL pvm_expression
        BRANCH_IF TOK_COMMA, pvm_expression
@done:
        RETURN

pvm_dim:
        MATCH TOK_NAME
        CALL pvm_optional_array
        BRANCH_IF TOK_COMMA, pvm_dim
        RETURN

pvm_data:
pvm_rem:
        SLURP

; Expressions

pvm_expression:
        CALL pvm_primary_expression
        BRANCH_IF TOK_ANY_OP_2X, pvm_expression
        RETURN

pvm_primary_expression:
        BRANCH_IF TOK_LPAREN, pvm_subexpression
        BRANCH_IF TOK_ADD, pvm_primary_expression   ; Unary +
        BRANCH_IF TOK_SUB, pvm_primary_expression   ; Unary -
        BRANCH_IF TOK_NOT, pvm_primary_expression   ; Unary NOT
        BRANCH_IF TOK_NUM, @done
        BRANCH_IF TOK_STRING, @done
        BRANCH_IF TOK_NAME, pvm_optional_array
        BRANCH_IF TOK_ANY_FN_4X, pvm_function
        BRANCH_IF TOK_ANY_FN_5X, pvm_function
        FAIL
@done:
        RETURN

pvm_subexpression:
        CALL pvm_expression
        MATCH TOK_RPAREN
        RETURN

pvm_optional_array:
        BRANCH_IF TOK_LPAREN, @array
        RETURN

@array:
        CALL pvm_arg_list
        MATCH TOK_RPAREN
        RETURN

pvm_function:
        MATCH TOK_LPAREN
        CALL pvm_arg_list
        MATCH TOK_RPAREN
        RETURN

; Argument lists

pvm_arg_4:
        CALL pvm_expression
        MATCH TOK_COMMA
pvm_arg_3:
        CALL pvm_expression
        MATCH TOK_COMMA
pvm_arg_2:
        CALL pvm_expression
        MATCH TOK_COMMA
        JUMP pvm_expression

pvm_arg_list:
        CALL pvm_expression
        BRANCH_IF TOK_COMMA, pvm_arg_list
        RETURN
