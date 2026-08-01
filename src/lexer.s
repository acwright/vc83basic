; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

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

.assert TOK_EOL = 0, error
.assert TOK_AND = $80, error

next_token:
        ldx     buffer_pos
        ldy     line_pos                ; Prepare to write into line_buffer using Y
        sty     decode_name_ptr         ; Start of token in decode_name_ptr so we can tokenize it later
        lda     #>line_buffer           ; High byte
        sta     decode_name_ptr+1
@whitespace:
        lda     buffer,x                ; Load next character
        debug $00
        beq     @write_token            ; Return TOK_EOL
        inx                             ; It's not EOL, so we're going to eat it, whatever it is
        cmp     #' '                    ; Space?
        beq     @whitespace             ; Pretend we didn't see it

; Single-character tokens

        cmp     #','
        beq     @write_token
        cmp     #';'
        beq     @write_token
        cmp     #'('
        beq     @write_token
        cmp     #')'
        beq     @write_token

; Strings

        cmp     #'"'
        bne     @number
@next_string_char:
        sta     line_buffer,y           ; Store string character in line_buffer
        iny
        lda     buffer,x
        beq     @write_token            ; Abandon string and return TOK_EOL
        inx
        cmp     #'"'
        bne     @next_string_char
        sta     line_buffer,y           ; Write this quote out to line_buffer
        iny
        cmp     buffer,x                ; If two double quotes in a row, string continues
        bne     @done                   ; It wasn't so string ends with '"' still in A
        inx                             ; Consume the quote
        bne     @next_string_char       ; Unconditional

@tokenize:
        lda     line_buffer-1,y         ; Get the previously-written character
        ora     #EOT
        ldax    #operators
        jsr     find_name               ; Was it an operator?
        bcc     @write_token            ; It was! Replace name with token
        ldax    #keywords
        jsr     find_name               ; Was it a keyword?
        ora     #TOK_AND                ; Equivalent to ADC because TOK_AND = $80 but doesn't set carry     
        bcc     @write_token            ; It was! Replace name with token
        lda     #TOK_NAME               ; Couldn't tokenize, so it's a name
        bcs     @done

@write_token:
        ldy     line_pos                ; Restore original line_pos
        sta     line_buffer,y
        iny
@done:
        sta     token                   ; Store token and update position variables
        stx     buffer_pos
        sty     line_pos
        rts

@number:

; Operators
; We've already handled spaces and double quotes so anything in the $2x ASCII range is an
; operator, plus relational symbols.

@operator:
        sec
        sbc     #' '
        cmp     #16
        bcc     @tokenize
        sbc     #('<' - ' ')
        cmp     #3
        bcs     @name
        lda     buffer,x                ; Relational operators are potentially two characters
        sbc     #('<' - 1)              ; Carry is clear so result will one less than expected
        cmp     #3
        bcs     @tokenize               ; Tokenize without the next character
        inx                             ; Include the next character

@name:
        rts

