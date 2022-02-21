; cc65 runtime
.include "zeropage.inc"
.include "basic.inc"

; Copies bytes from a source address to a destination address.
; The source and destination byte ranges must not overlap unless the destination address is lower than the
; source address.
; Alters ptr1 and ptr2.
; ptr1 = source
; ptr2 = destination (must be <=ptr1)
; sreg = number of bytes to copy

copy_bytes:
        ldy     #0                  ; Y = 0 meaning 256 bytes per block
        ldx     sreg+1              ; Number of 256-byte blocks
        beq     @remaining          ; If no blocks, just do remaining bytes
@next_byte:
        lda     (ptr1),y            ; Copy one byte
        sta     (ptr2),y            
        iny                         ; Next byte
        bne     @next_byte          ; More to move
        inc     ptr1+1              ; Add 256
        inc     ptr2+1              ; to both ptr1 and ptr2
        dex                         ; Decrement number of blocks
        bne     @next_byte          ; Move to move

; Copy the remaining bytes.
; Y = 0 when we first reach this point

@remaining:
        cpy     sreg                ; Compare Y with number of remaining bytes
        beq     @return             ; If equal then we're done
        lda     (ptr1),y            ; Otherwise move one more byte
        sta     (ptr2),y           
        iny
        jmp     @remaining          ; TODO: optimize for 65C02

@return:
        rts

; Copy bytes backwards from a source address to a destination address.
; Used when the source and destination byte ranges overlap and destination address is higher than the source address.
; Alters ptr1 and ptr2.
; ptr1 = source
; ptr2 = destination (must be <=ptr1)
; sreg = number of bytes to copy

copy_bytes_back:
        clc
        lda     ptr1                ; Add sreg (the length) to ptr1 and ptr2
        pha                         ; and save the original values on the stack
        adc     sreg
        sta     ptr1
        lda     ptr1+1
        pha
        adc     sreg+1
        sta     ptr1+1
        clc
        lda     ptr2              
        pha                         
        adc     sreg
        sta     ptr2
        lda     ptr2+1
        pha
        adc     sreg+1
        sta     ptr2+1

; The stack contains the original ptr1 and ptr2; we'll use these to move the last bytes.
; The current values of ptr1 and ptr2 are one past the end of the move ranges.
; The number of bytes to move is in sreg.

        ldy     #0                  ; Y = 0 meaning 256 bytes per block
        ldx     sreg+1              ; Number of 256-byte blocks
        beq     @remaining          ; If no blocks, just do remaining bytes
@next_block:
        beq     @remaining          ; No more blocks, copy remaining bytes
        dec     ptr1+1              ; Subtract 256 from ptr1
        dec     ptr2+1              ; and ptr2
        jsr     @copy
        dex                         ; Done with this block
        bne     @next_block         ; More to copy

; Upon reaching this point, both X and Y will be zero.

@remaining:
        pla                         ; Recover original ptr1 and ptr2 from stack
        sta     ptr2+1
        pla
        sta     ptr2
        pla
        sta     ptr1+1
        pla
        sta     ptr1
        ldy     sreg                ; Number of bytes left to copy (may be 0)
        beq     @skip_copy          ; No bytes to copy, otherwise fall through to @copy

; Copies bytes from offsets Y-1 to 0. Will copy 256 bytes if Y = 0.
; Y will be 0 on exit.

@copy:
        dey                         ; Decrement Y
        beq     @copy_last_byte     ; Y is 0 but we still have to copy one last byte
        lda     (ptr1),y            ; Copy one byte
        sta     (ptr2),y  
        jmp     @copy               ; TODO: optimize for 65C02
@copy_last_byte:
        lda     (ptr1),y            ; Copy last byte (Y will be 0) (TODO: optimize for 65C02)
        sta     (ptr2),y
@skip_copy:
        rts




