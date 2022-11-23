.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_variable         ; Read the variable
        pha                             ; Remember it while we figure out the value to assign to it
        jsr     evaluate_expression     ; Leaves the result on the stack
        pla                             ; Get the variable back
        jsr     pop_variable
        clc                             ; Signal success
        rts
