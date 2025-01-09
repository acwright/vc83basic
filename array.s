.include "macros.inc"
.include "basic.inc"

; DIM statement:

.assert TYPE_ARRAY = $80, error

exec_dim:
        jsr     decode_name             ; Get the name and type
        clc
        lda     decode_name_type        ; See if it's an array name
        bpl     @done                   ; Nope; nothing to do

; Calculate space required for this array.

        and     #$7F                    ; Clear the array bit
        tax                             ; Transfer into X
        lda     type_size_table,x       ; In order to look up the size for this type
        ldx     #0                      ; AX is the 16-bit size
        jsr     int_to_fp               ; Load as float into FP0
        jsr     push_fp0                ; Push onto the stack
        bcs     @done                   ; Out of space
@next:
        jsr     evaluate_expression     ; Evaluate the next expression; the value is now on the stack
        bcs     @done
        jsr     push_value_1            ; We have to add one to the value
        bcs     @done
        jsr     op_add
        jsr     op_mul                  ; Multiply the two stack values together
        ldy     line_pos
        lda     (line_ptr),y            ; Peek at next character
        bne     @next                   ; Keep decoding more dimensions
        jsr     truncate_fp_to_int
        bcs     @done                   ; Value was too large
        sec                             ; Set carry in case next check fails
        bmi     @done                   ; Value was negative
        jsr     add_variable            ; Add the space for the variable
        

        
        
        
        




@done:
        rts


; Multiply the 16-bit operand in BC with the 16-bit operand in AX. Returns the result in AX.
; Returns carry clear on success or carry set if the result overflowed.

imul_16:
        stax    S1                      ; Hold operand in S1
        ldx     #16                     ; Number of shift operations
        mva     #0, S0                  ; Accumulate product in S0
        sta     S0+1
@next:
        asl     S0
        rol     S0+1
        bcs     @error                  ; Product overflowed
        asl     S1
        rol     S1+1
        bcc     @skip_add
        clc
        lda     S0
        adc     B
        sta     S0
        lda     S0+1
        adc     C
        sta     S0+1
@skip_add:
        dex
        bne     @next
        ldax    S0
@error:
        rts    


        


