; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.include "lexer_data.inc"

.segment "PARSER"

; Encodes string using .byte and sets bit 7 (EOT) on the last character.

.macro name s
    .local @length
    @length = .strlen(s)

    .if (@length > 0)
        ; Output all characters *except* the last one, if any.
        .if (@length > 1)
            .repeat @length - 1, i
                .byte   .strat(s, i)
            .endrep
        .endif
        
        ; Output the last character, bitwise OR'd with EOT
        .byte   .strat(s, @length - 1) | EOT
    .else
        ; If string is empty then just output a single EOT byte.
        .byte   EOT
    .endif
.endmacro

.macro name_table_entry s
        .byte   :+ - *
        name s
.endmacro

.macro name_table_end
        .byte   0
.endmacro

keywords:
        name_table_entry "+"
:       name_table_entry "-"
:       name_table_entry "*"
:       name_table_entry "/"
:       name_table_entry "^"
:       name_table_entry "&"
:       name_table_entry "="
:       name_table_entry "<"
:       name_table_entry ">"
:       name_table_entry "<>"
:       name_table_entry "<="
:       name_table_entry ">="
:       name_table_entry "AND"
:       name_table_entry "OR"
:       name_table_entry "NOT"
:       name_table_entry "LET"
:       name_table_entry "RUN"
:       name_table_entry "PRINT"
:       name_table_entry "?"
:       name_table_entry "LIST"
:       name_table_entry "GOTO"
:       name_table_entry "GOSUB"
:       name_table_entry "RETURN"
:       name_table_entry "POP"
:       name_table_entry "ON"
:       name_table_entry "FOR"
:       name_table_entry "NEXT"
:       name_table_entry "STOP"
:       name_table_entry "CONT"
:       name_table_entry "NEW"
:       name_table_entry "CLR"
:       name_table_entry "DIM"
:       name_table_entry "REM"
:       name_table_entry "DATA"
:       name_table_entry "READ"
:       name_table_entry "RESTORE"
:       name_table_entry "POKE"
:       name_table_entry "DPOKE"
:       name_table_entry "END"
:       name_table_entry "INPUT"
:       name_table_entry "IF"
:       name_table_entry "THEN"
:       name_table_end

keyword_tokens:
        .byte TOK_ADD
        .byte TOK_SUB
        .byte TOK_MUL
        .byte TOK_DIV
        .byte TOK_EXP
        .byte TOK_CONCAT
        .byte TOK_EQ
        .byte TOK_LT
        .byte TOK_GT
        .byte TOK_NE
        .byte TOK_LE
        .byte TOK_GE
        .byte TOK_AND
        .byte TOK_OR
        .byte TOK_NOT
        .byte TOK_LET
        .byte TOK_RUN
        .byte TOK_PRINT
        .byte TOK_ALT_PRINT
        .byte TOK_LIST
        .byte TOK_GOTO
        .byte TOK_GOSUB
        .byte TOK_RETURN
        .byte TOK_POP
        .byte TOK_ON
        .byte TOK_FOR
        .byte TOK_NEXT
        .byte TOK_STOP
        .byte TOK_CONT
        .byte TOK_NEW
        .byte TOK_CLR
        .byte TOK_DIM
        .byte TOK_REM
        .byte TOK_DATA
        .byte TOK_READ
        .byte TOK_RESTORE
        .byte TOK_POKE
        .byte TOK_DPOKE
        .byte TOK_END
        .byte TOK_INPUT
        .byte TOK_IF
        .byte TOK_THEN

; Parses the next token from buffer using the DFA data tables in lexer_data.inc.
; Writes token characters or matched token byte into line_buffer.
; Reads using X (buffer_pos) and writes using Y (line_pos).
; Skips leading whitespace. Returns the next token in line_buffer at position line_pos, then the
; token value in the following positions. Updates line_pos.
; Returns the next token in A.
; DE SAFE

; Buffers must be page-aligned.
.assert <buffer = 0, error
.assert <line_buffer = 0, error

.assert TOK_EOL = 0, error

next_token:
        ldx     buffer_pos
        dex                             ; Negate initial inx

@whitespace:
        inx
        lda     buffer,x                ; Load next character
        beq     @eol                    ; Idempotent return if EOL reached
        cmp     #' '                    ; Space?
        beq     @whitespace             ; Skip space

@init_dfa:
        inc     line_pos                ; Leave space for token; we'll encode value after it
        lda     line_pos                ; Set up decode_name_ptr now in case we have to tokenize a keyword
        sta     decode_name_ptr         ; Start of token value in decode_name_ptr
        lda     #>line_buffer           
        sta     decode_name_ptr+1       ; High byte
        mva     #0, B                   ; B = current DFA state byte offset (relative to state_0)
@dfa_loop:
        ldy     B                       ; Y = state byte offset
        lda     state_0,y               ; Read terminal token tag at offset 0
        cmp     #$80                    ; Carry = 1 if bit 7 (case fold flag) set, else 0
        and     #$7F                    ; Forget the case fold flag
        sta     C                       ; Will need the terminal token without the case fold flag later
        lda     buffer,x                ; Read input character
        bcc     @char_ready             ; Carry clear -> no case folding needed
        cmp     #'a'
        bcc     @char_ready
        cmp     #'z'+1
        bcs     @char_ready
        and     #$DF                    ; Convert 'a'..'z' -> 'A'..'Z'
@char_ready:
        pha                             ; Save the character on the stack
        iny                             ; Y = state + 1 (transition count offset)
        lda     state_0,y               ; Read transition count
        beq     @finish_token           ; 0 transitions -> finish token matching
        sta     B                       ; Re-use B for counting down the number of transitions
        iny                             ; Y = state + 2 (first min_char offset)
@check_range:
        pla                             ; Read character from D
        pha                             ; Keep it on the stack
        sec
        sbc     state_0,y               ; A = char - min_char
        iny                             ; Y points to count_chars
        cmp     state_0,y               ; Compare (char - min_char) to count_chars
        bcc     @range_matched          ; Carry clear -> in range [0, count-1]
        iny                             ; Skip dest_state
        iny                             ; Point to next min_char
        dec     B                       ; Decrement number of remaining transition records
        bne     @check_range            ; If more than check them, else @finish_token

@finish_token:
        pla                             ; Don't need the character on the stack anymore
        stx     buffer_pos        
        ldy     line_pos                ; Always safe to set EOT bit on last character written
        lda     line_buffer-1,y         ; It will either be necessary (names, numbers),
        ora     #EOT                    ;     overwritten (single-character tokens), or discarded (strings)
        sta     line_buffer-1,y
        lda     C                       ; Read back the terminal token we saved earlier
        ldy     decode_name_ptr         ; Get the line_pos+1 value we saved earlier
        sta     line_buffer-1,y         ; Save the terminal token into the position we reserved for it

; When we entered this function, line_pos was L. Now we have set up:
;     L   = the matched token
;     L+1 = the first character of the token value (decode_name_ptr points here)
;     ...
;     L+n = the last character of the token value, with EOT bit set
; Note that n may be zero, if the first character didn't match anything in state 0; token will be NON_TERMINAL.
; Now we adjust the token and/or value encoding based on the token type.
; If OPERATOR or NAME, try to map the token value to a keyword. If matched, replace token at L with the keyword
; token and discard the value. Otherwise, just return the original toke and the full value.
; If NUM, everything is already formatted correctly, so just return.
; If STRING, the character at L+1 is a quote; replace it with the length byte and discard the last character of
; the value, which will be the end quote.
; All other tokens have no value, so discard the value before returning.

        cmp     #TOK_OPERATOR
        beq     @encode_operator_or_name
        cmp     #TOK_NAME
        beq     @encode_operator_or_name
        cmp     #TOK_NUM
        beq     @encode_number
        cmp     #TOK_STRING
        beq     @encode_string
        sty     line_pos                ; The rest of the tokens have no value
@eol:
        rts

@range_matched:
        iny                             ; Y points to target_state byte offset
        lda     state_0,y
        sta     B                       ; B is once again the state byte offset relative to state_0
        pla                             ; Read character from stack
        ldy     line_pos                ; Y goes back to being the line_buffer write position
        sta     line_buffer,y           ; Store in line_buffer
        inc     line_pos
        inx
        bne     @dfa_loop               ; Unconditional

; If we get here then we have an operator or a name. Look it up in `keywords` name tables, and if successful,
; output that token instead. Note: Although we have one keyword table, we have separate tokens for operators and
; names, because if we can't tokenize the keyword, the parser has to be able to distinguish between them.

@encode_operator_or_name:
        ldax    #keywords
        jsr     find_name
        bcs     @return_terminal_token
        tax                             ; Use the name index to look up the token
        lda     keyword_tokens,x
        ldy     decode_name_ptr         ; Reload line_pos+1 since find_name clobbered it
        sta     line_buffer-1,y         ; Overwrite the original token with the keyword token
        sty     line_pos                ; This will become the new line_pos since we replaced the token
@encode_number:
        rts

@encode_string:
        dec     line_pos                ; Remove the last quote; the first quote will become length byte
        lda     line_pos                ; Now points one past the end of the string
        clc                             ; We have original line_pos+1 but we want to subtract line_pos+2 so clear carry
        sbc     decode_name_ptr         ; This is the original line_pos+1
        ldy     decode_name_ptr         ; Will point to the quote at the start of the string
        sta     line_buffer,y           ; Replace with length byte

@return_terminal_token:
        lda     C
        rts
