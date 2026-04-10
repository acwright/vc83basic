.include "apple2.inc"
.include "../macros.inc"

.import __MAIN_START__, __MAIN_SIZE__
.import __CODE_LOAD__, __CODE_RUN__
.import __PARSER_LOAD__, __PARSER_RUN__, __PARSER_SIZE__

.export startup

.zeropage

size: .res 2
src_ptr: .res 2
dst_ptr: .res 2
ptr: .res 2

.segment "STARTUP"

SYSTEM_ROM_START = $F800
SYSTEM_ROM_SIZE = $800

startup:
        ldx     #$FF        
        txs                             ; Initialize the stack to $FF
        mvax    #SYSTEM_ROM_START, src_ptr  ; Move system ROM into RAM
        mvax    #system_rom, dst_ptr
        ldax    #SYSTEM_ROM_SIZE
        jsr     copy
        lda     LCRAM                   ; Read LCRAM twice write-enable RAM
        lda     LCRAM
        mvax    #system_rom, src_ptr        ; Copy system ROM into LC
        mvax    #SYSTEM_ROM_START, dst_ptr
        ldax    #SYSTEM_ROM_SIZE
        jsr     copy
        mvax    #__CODE_LOAD__, src_ptr     ; Copy BASIC code into LC
        mvax    #__CODE_RUN__, dst_ptr
        ldax    #(__PARSER_LOAD__ + __PARSER_SIZE__ - __CODE_LOAD__)
        jsr     copy
        lda     LCRAMWP                 ; Write-protect LC RAM
        jsr     print_message
        lda     LCROM                   ; Re-enable LC ROM before returning to Applesoft
        rts

copy:
        stax    size
        lda     #0                      ; Low byte of #256
        sec
        sbc     size                    ; Subtract size from 256; this is initial Y value for short block
        tay                             ; Into Y
        beq     @next_byte              ; Even number of blocks; skip all the short block stuff
        clc                             ; Add size % 256 to source_ptr
        lda     src_ptr
        adc     size
        sta     src_ptr
        bcs     @src_has_carry          ; Need to add 1 to src_ptr high byte; can just skip decrement instead
        dec     src_ptr+1
@src_has_carry:
        clc                             ; Add size % 256 to dst_ptr
        lda     dst_ptr
        adc     size
        sta     dst_ptr
        bcs     @dst_has_carry
        dec     dst_ptr+1
@dst_has_carry:
        inx                             ; Add 1 to number of blocks to account for short block

; Once we get here, X is >0, and either:
; There are X 256-byte blocks to copy, and Y is 0.
; There are X-1 256-byte blocks to copy, plus one short block, and Y is (256 - size of short block).

@next_byte: 
        lda     (src_ptr),y             ; Copy one byte
        sta     (dst_ptr),y                
        iny                             ; Next byte
        bne     @next_byte              ; More to move
        inc     src_ptr+1               ; Add 256
        inc     dst_ptr+1               ; to both src_ptr and dst_ptr
        dex                             ; Decrement number of blocks
        bne     @next_byte              ; More to move

@done:
        rts

system_rom: .res SYSTEM_ROM_SIZE

.segment "ONCE"

.byte 0

.code

message:    .byte 13, 13, "HELLO, WORLD", 13
message_length = * - message

print_message:
        mvax    #message, ptr
        ldy     #0
@next:
        lda     (ptr),y
        ora     #$80
        jsr     COUT
        iny
        cpy     #message_length
        bne     @next
@done:
        rts

.segment "PARSER"

.byte 0

