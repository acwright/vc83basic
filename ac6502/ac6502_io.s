; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

readline:
        ldy     #0
@waitchar:
        jsr     CHRIN
        bcc     @waitchar
        ; Check for backspace
        cmp     #CH_BKSP
        beq     @backspace
        ; Check for CR (end of line)
        cmp     #CH_CR
        beq     @done
        ; Skip non-printable control characters (LF, NUL, ESC, etc.)
        cmp     #CH_SPACE
        bcc     @waitchar
        ; Skip DEL ($7F)
        cmp     #$7F
        beq     @waitchar
        ; Ignore if buffer full
        cpy     #BAS_LINBUF_SIZE
        bcs     @waitchar
        ; Store character
        sta     buffer,y
        iny
        jmp     @waitchar

@backspace:
        cpy     #0
        beq     @waitchar               ; Nothing to delete
        dey
        jmp     @waitchar

@done:
        lda     #0
        sta     buffer,y                ; Null-terminate
        lda     #CH_LF
        jsr     putch                   ; Echo newline (Chrin echoed the CR)
        rts

write:
        stax    BC
        tya
        tax
        beq     @done
        ldy     #0
@next:
        lda     (BC),y
        jsr     putch
        iny
        dex
        bne     @next
@done:
        rts

putch := CHROUT

newline:
        lda     #CH_CR
        jsr     putch
        lda     #CH_LF
        jmp     putch

.code
        