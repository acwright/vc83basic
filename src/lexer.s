; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

.assert TOK_EOL = 0, error

next_token:
        mvx     buffer_pos, token_pos   ; Whatever the token, it starts here
@whitespace:
        lda     buffer,x                ; Load next character
        debug $00
        sta     token                   ; In some cases the character *is* the token so just in case
        bne     @not_eol
        rts

@operator_2:
        iny
@operator_1:
        iny
@operator:
        tya
        stx     buffer_pos
        rts

@not_eol:
        inx                             ; It's not EOL, so we're going to eat it, whatever it is
        cmp     #' '                    ; Space?
        beq     @whitespace

; Operators

        ldy     #TOK_EQ
        cmp     #'='
        beq     @operator
        iny                             ; TOK_LT
        cmp     #'<'
        bne     @not_lt
        lda     buffer,x
        inx
        cmp     #'='
        beq     @operator_1             ; TOK_LE
        cmp     #'>'
        beq     @operator_2             ; TOK_NE
        bne     @operator

@not_lt:
        ldy     #TOK_GT
        cmp     #'>'
        bne     @not_gt
        lda     buffer,x
        inx
        cmp     #'='
        beq     @operator_1             ; TOK_GE
        bne     @operator

@not_gt:
        ldy     #TOK_ADD
        cmp     '+'
        beq     @operator
        iny                             ; TOK_SUB
        cmp     '-'
        beq     @operator
        iny                             ; TOK_MUL
        cmp     '*'
        beq     @operator
        iny                             ; TOK_DIV
        cmp     '/'
        beq     @operator
        iny                             ; TOK_EXP
        cmp     '^'
        beq     @operator
        iny                             ; TOK_CONCAT
        cmp     '&'
        beq     @operator

; String

        cmp     #'"'



