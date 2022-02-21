; Wrappers around assembly language functions to make them callable from C.
; The assembly language functions don't use the C stack, so the wrapper functions
; pop arguments from the C stack and put them in the right places before calling
; the assembly function.
; C prototypes are in test.h.

; cc65 runtime
.include "zeropage.inc"
.import popptr1, incsp2

.include "basic.inc"

.export _initialize_program, _copy_bytes, _copy_bytes_back

; Same as popptr1 but for ptr2.
popptr2:
        ldy     #1
        lda     (sp),y
        sta     ptr2+1
        dey           
        lda     (sp),y
        sta     ptr2
        jmp     incsp2

_initialize_program:
        jsr     initialize_program
        rts

_copy_bytes:
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     copy_bytes

_copy_bytes_back:
        sta     sreg
        stx     sreg+1
        jsr     popptr1
        jsr     popptr2
        jmp     copy_bytes_back
