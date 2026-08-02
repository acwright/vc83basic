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
        mva     #0, B                   ; B = current DFA state index

@dfa_loop:
        ldy     B                       ; Load vector_ptr with address of state_table[B]
        lda     state_table_low,y
        sta     vector_ptr
        lda     state_table_high,y
        sta     vector_ptr+1
        ldy     #1                      ; Read transition count at offset 1
        lda     (vector_ptr),y
        beq     @finish_token           ; 0 transitions -> finish token matching
        sta     C                       ; C = number of transitions
        iny                             ; Offset of first transition range (Y = 2)

@check_range:
        lda     buffer,x                ; Read character to test
        sec
        sbc     (vector_ptr),y          ; A = char - min_char
        iny                             ; Y points to count_chars
        cmp     (vector_ptr),y          ; Compare (char - min_char) to count_chars
        bcc     @range_matched          ; Carry clear -> in range [0, count-1]
        iny                             ; Skip dest_state
        iny                             ; Point to next min_char
        dec     C
        bne     @check_range

@finish_token:
        stx     buffer_pos
        ldy     #0                      ; Read terminal token tag of state B
        lda     (vector_ptr),y
        bmi     @syntax_error           ; Bit 7 set (-1) -> syntax error
        cmp     #TOK_OPERATOR
        clc
        beq     @try_replace
        cmp     #TOK_NAME
        sec
        beq     @try_replace
        rts                             ; Standard token: line_pos & line_buffer already updated

@range_matched:
        iny                             ; Y points to dest_state
        lda     (vector_ptr),y
        sta     B                       ; B = dest_state
        lda     buffer,x                ; Write character to line_buffer
        ldy     line_pos
        sta     line_buffer,y
        inc     line_pos
        inx
        bne     @dfa_loop

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

@write_replacement:
        ldy     decode_name_ptr         ; Replace string with single token byte
        sta     line_buffer,y
        iny
        sty     line_pos
        rts

@no_match:
        lda     B
        rts

@syntax_error:
        jmp     syntax_error

