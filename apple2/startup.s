; cc65 runtime
.include "zeropage.inc"

.include "arch.inc"

.import main, newline

.segment "STARTUP"

        cld                     ; Clear decimal flag
        ldx     #$FF
        txs                     ; Initialize the stack to $FF
        jsr     init            ; One-time initialization
        jsr     main
        jmp     DOSWARM         ; Exit to resident program

; The ONCE and INIT segments have to exist or the linker will complain.

.segment "ONCE"

init:
        lda     #$FF            ; Print in normal mode
        sta     COUTMASK
        jsr     newline         ; Apple doesn't automatically start new line after BRUN
        rts

.segment "INIT"

dummy:
        rts

