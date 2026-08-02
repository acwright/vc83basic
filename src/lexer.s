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

operators:
        name_table_entry ""     ; EOL
:       name_table_entry "+"
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
:       name_table_end

keywords:
        name_table_entry "AND"
:       name_table_entry "OR"
:       name_table_entry "NOT"
:       name_table_entry "LET"
:       name_table_entry "IMPL_LET"
:       name_table_entry "RUN"
:       name_table_entry "PRINT"
:       name_table_entry "ALT_PRINT"
:       name_table_entry "LIST"
:       name_table_entry "GOTO"
:       name_table_entry "IMPL_GOTO"
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

; Parses the next token from buffer using the DFA data tables in lexer_data.inc.
; Writes token characters or matched token byte into line_buffer.
; Reads using X (buffer_pos) and writes using Y (line_pos).
; Skips leading whitespace and returns TOK_EOL on NUL (0).
; For TOK_OPERATOR or TOK_NAME, sets EOT on the last character written, then calls find_name.
; Maps operator to index of matched operator name.
; Maps name to index of matched keyword OR'd with TOK_AND ($80).
; Returns the next token in A.

; Buffers must be page-aligned.
.assert <buffer = 0, error
.assert <line_buffer = 0, error

.assert TOK_EOL = 0, error
.assert TOK_AND = $80, error

next_token:
        lda     line_pos                ; Prepare to write into line_buffer using Y
        sta     decode_name_ptr         ; Start of token in decode_name_ptr
        lda     #>line_buffer           ; High byte
        sta     decode_name_ptr+1
        ldx     buffer_pos

@whitespace:
        lda     buffer,x                ; Load next character
        cmp     #' '                    ; Space?
        bne     @init_dfa
        inx
        bne     @whitespace             ; Skip space

@init_dfa:
        mva     #0, B                   ; B = current DFA state byte offset (relative to state_0)
@dfa_loop:
        ldy     B                       ; Y = state byte offset
        lda     state_0,y               ; Read terminal token tag at offset 0
        cmp     #$80                    ; Carry = 1 if bit 7 set (case-fold state), else 0
        lda     buffer,x                ; Read input character
        bcc     @char_ready             ; Carry clear -> no case folding needed
        cmp     #'a'
        bcc     @char_ready
        cmp     #'z'+1
        bcs     @char_ready
        and     #$DF                    ; Convert 'a'..'z' -> 'A'..'Z'

@char_ready:
        sta     D                       ; Save character in D

        iny                             ; Y = B + 1 (transition count offset)
        lda     state_0,y               ; Read transition count
        beq     @finish_token           ; 0 transitions -> finish token matching
        sta     C                       ; C = number of transitions
        iny                             ; Y = B + 2 (first min_char offset)

@check_range:
        lda     D                       ; Read character from D
        sec
        sbc     state_0,y               ; A = char - min_char
        iny                             ; Y points to count_chars
        cmp     state_0,y               ; Compare (char - min_char) to count_chars
        bcc     @range_matched          ; Carry clear -> in range [0, count-1]
        iny                             ; Skip dest_state
        iny                             ; Point to next min_char
        dec     C
        bne     @check_range

@finish_token:
        stx     buffer_pos
        ldy     B                       ; Y = state byte offset
        lda     state_0,y               ; Read terminal token tag
        and     #$7F                    ; Clear bit 7 (case-fold flag)
        cmp     #TOK_OPERATOR
        clc
        beq     @try_replace
        cmp     #TOK_NAME
        sec
        beq     @try_replace
        rts                             ; Standard token or TOK_NON_TERMINAL

@range_matched:
        iny                             ; Y points to target_state byte offset
        lda     state_0,y
        sta     B                       ; B = new state byte offset relative to state_0
        lda     D                       ; Read character from D
        ldy     line_pos
        sta     line_buffer,y           ; Store in line_buffer
        inc     line_pos
        inx
        bne     @dfa_loop

; If we get here then we have an operator or a name. Look it up in the `operators` or `keywords` name tables,
; and if successful, output that token instead.

@try_replace:
        sta     B                       ; Re-use B to remember original token
        ldy     line_pos
        lda     line_buffer-1,y
        ora     #EOT
        sta     line_buffer-1,y
        ldax    #operators
        ldy     #0
        bcc     @call_find_name
        ldax    #keywords
        ldy     #TOK_AND
@call_find_name:
        sty     C
        jsr     find_name
        bcs     @no_match
        ora     C
        ldy     decode_name_ptr         ; Replace string with single token byte
        sta     line_buffer,y
        iny
        sty     line_pos
        rts

@no_match:
        lda     B
        rts
