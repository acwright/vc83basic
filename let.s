.include "macros.inc"
.include "target.inc"
.include "basic.inc"

.zeropage

let_variable_ptr: .res 2

.code 

; LET statement:

exec_let:
        jsr     decode_byte             ; Read the variable
        jsr     get_variable_value_ptr  ; Address of variable data in AX
        stax    let_variable_ptr        ; Set up for storing value
        jsr     get_argument_value      ; Value is in AX
        ldy     #0                      ; Index variable value with Y
        sta     (let_variable_ptr),y    ; Low byte
        iny
        txa
        sta     (let_variable_ptr),y    ; High byte
        rts
