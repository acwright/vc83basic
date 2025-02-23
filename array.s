.include "macros.inc"
.include "basic.inc"

; DIM statement:

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
@next:
        stax    array_element_size      ; Update current size
        ldy     line_pos                ; Peek at next byte
        lda     (line_ptr),y
        beq     @no_more_dimensions
        jsr     evaluate_expression     ; Evaluate the next expression; the value is now on the stack
        bcs     @done
        jsr     pop_fp0                 ; Load into FP0
        jsr     truncate_fp_to_int      ; Convert to 16-bit integer
        bcs     @done                   ; Value was too large
        clc
        adc     #1                      ; Add one because DIM(n) creates n+1 elements from 0 to n
        bcc     @skip_inx
        inx
@skip_inx:
        jsr     imul_16                 ; Multiply the current element size by the new value
        bcs     @done
        sec                             ; In case next check fails
        bmi     @done                   ; Size exceeded 32K
        bpl     @next

@no_more_dimensions:
        ldax    array_element_size      ; Use this as the size of the variable
        jsr     add_variable

@done:
        rts

; Multiply the 16-bit operand in array_element_size with the 16-bit operand in AX. Returns the result in AX.
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
        adc     array_element_size
        sta     S0
        lda     S0+1
        adc     array_element_size+1
        sta     S0+1
@skip_add:
        dex
        bne     @next
        ldax    S0
@error:
        rts
