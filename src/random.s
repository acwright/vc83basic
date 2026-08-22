; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Software implementation of a random number generator.
; Separated out from the rest of functions so we can replace it on a machine that includes a hardware random
; number generator.

; Generates a new random value in rnd_value and outputs it in FP0.

fun_rnd:
        lda     FP0e                    ; 0 -> return previous number, >0 -> return next number, <0 -> reseed
        beq     @output
        lda     FP0s
        bpl     @generate
        ldx     #4                      ; Copy given number into rnd_value
@next_copy_to_value:
        lda     FP0t-1,x
        sta     rnd_value-1,x
        dex
        bne     @next_copy_to_value
@generate:
        ldy     #32                     ; Each iteration generates 1 pseudo-random bit
@next_shift:
        asl     rnd_value
        rol     rnd_value+1
        rol     rnd_value+2
        rol     rnd_value+3
        bcc     @skip_feedback

; Apply polynomial taps: x^32 + x^22 + x^17 + x + 1

        lda     rnd_value+0
        eor     #$03                    ; Taps at x^1 and x^0 (+1)
        sta     rnd_value+0
        lda     rnd_value+2
        eor     #$42                    ; Taps at x^22 ($40) and x^17 ($02)
        sta     rnd_value+2

@skip_feedback:
        dey
        bne     @next_shift
@output:
        ldx     #4                      ; Make random number from rnd_value
@next_copy_to_fp0:
        lda     rnd_value-1,x
        sta     FP0t-1,x
        dex
        bne     @next_copy_to_fp0
        lda     #BIAS-1                 ; This effectively puts the binary point to the left of the mantissa
        sta     FP0e
        stx     FP0s                    ; The purpose of all the -1s was to make X 0 here
        jmp     normalize
