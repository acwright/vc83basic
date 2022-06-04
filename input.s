.include "macros.inc"
.include "target.inc"
.include "basic.inc"

.zeropage

input_variable_ptr: .res 2

.code 

; INPUT statement:

exec_input:
        jsr     decode_byte             ; Read the variable
        jsr     get_variable_value_ptr  ; Address of variable data in AX
        stax    input_variable_ptr      ; Set up for storing value
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putchar
        jsr     readline
        mva     #0, r                   ; Start parsing at position 0
        jsr     read_number
        ldy     #0                      ; Index variable value with Y
        sta     (input_variable_ptr),y  ; Low byte
        iny
        txa
        sta     (input_variable_ptr),y  ; High byte
        rts
