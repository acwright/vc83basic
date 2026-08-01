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

; Parses the next token from buffer and writes the token value to line_buffer.
; For single-character tokens, e.g., ',', as well as operators and keywords, the token value is the token itself.
; For strings, names, and numbers, the token value is the list of characters read from the buffer.
; Sets the EOT bit on the last character of names to facilitate name lookups at runtime.
; Returns the next token in A.

next_token:
        ldx     buffer_pos
        ldy     line_pos                ; Prepare to write into line_buffer using Y
        sty     decode_name_ptr         ; Start of token in decode_name_ptr so we can tokenize it later
        lda     #>line_buffer           ; High byte
        sta     decode_name_ptr+1
@whitespace:
        lda     buffer,x                ; Load next character
        beq     @write                  ; Return TOK_EOL
        inx
        debug $00
        cmp     #' '                    ; Space?
        beq     @whitespace             ; Pretend we didn't see it

; Single-character tokens

        cmp     #','
        beq     @write
        cmp     #';'
        beq     @write
        cmp     #'('
        beq     @write
        cmp     #')'
        beq     @write

; Strings

        cmp     #'"'
        bne     @number
@next_string_char:
        sta     line_buffer,y           ; Store string character in line_buffer
        iny
        lda     buffer,x
        beq     @write                  ; Abandon string and return TOK_EOL
        inx
        cmp     #'"'
        bne     @next_string_char
        sta     line_buffer,y           ; Write this quote out to line_buffer
        iny
        cmp     buffer,x                ; If two double quotes in a row, string continues
        bne     @done                   ; It wasn't so string ends with '"' still in A
        inx                             ; Consume the quote
        bne     @next_string_char       ; Unconditional

; X points to the next character after the token in buffer. Y is same for line_buffer.
; Write out both so we can reuse X and Y in the tokenization process.
; If we find a token, we'll rewind line_pos to decode_name_ptr and write the token.

@tokenize:
        stx     buffer_pos
        sty     line_pos
        lda     line_buffer-1,y         ; Get the previously-written character
        ora     #EOT                    ; Set EOT bit to flag end of token for find_name
        sta     line_buffer-1,y
        ldax    #operators
        jsr     find_name               ; Was it an operator?
        bcc     @replace                ; It was! Replace name with token
        ldax    #keywords
        jsr     find_name               ; Was it a keyword?
        ora     #TOK_AND                ; Equivalent to ADC because TOK_AND = $80 but doesn't set carry     
        bcc     @replace                ; It was! Replace name with token
        lda     #TOK_NAME               ; Couldn't tokenize, so it's a name
        rts

@replace:
        ldy     decode_name_ptr         ; Restore original line_pos from decode_name_ptr
        sta     line_buffer,y
        iny
        sty     line_pos
        rts

; We reach here when we want to write the character in A out and also return it as the token.
; X has already moved the past the source of the token in buffer, but Y points to the next write position
; in line_buffer.

@write:
        sta     line_buffer,y         
        iny
@done:
        sty     line_pos
        stx     buffer_pos
        rts

@number:

; Operators
; We've already handled spaces and double quotes so anything in the $2x ASCII range is an
; operator, plus relational symbols.

@operator:
        sta     line_buffer,y           ; Store it
        iny
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
        sta     line_buffer,y           ; Store it
        iny
        bne     @tokenize               ; Unconditional

@name:
        rts

