.include "apple2.inc"
.include "../target.inc"

buffer := $200

.bss

buffer_length: .res 1

output_buffer: .res 256
output_buffer_length: .res 1

.code 

getchar = KEYIN
newline = CROUT

readline:
        jsr     GETLNNOPMPT
        ldx     #$FF                    ; Go looking for the "RETURN" character
@next:      
        inx     
        lda     buffer,x        
        and     #$7F                    ; Clear bit 7 if it's set
        sta     buffer,x                ; Store back
        cmp     #$0D        
        bne     @next       
        lda     #0      
        sta     buffer,x                ; Replace "RETURN" with 0
        stx     buffer_length
        rts

write:
        stax    DE
        sty     B
        ldy     #0
@next:
        cpy     B
        beq     @done
        lda     (DE),y
        jsr     putchar
        iny
        jmp     @next

@done:
        rts

putchar:
        ora     #$80
        jmp     COUT
        