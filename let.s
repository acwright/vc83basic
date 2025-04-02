.include "macros.inc"
.include "basic.inc"

; LET statement:

exec_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        lda     decode_name_arity       ; Is it an array?
        beq     @not_array              ; No, just go ahead and evaluate the value
        phzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Remember the decoded name
        jsr     evaluate_argument_list  ; Evaluate the array arguments
        plzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE   ; Recover the decoded name
        ldax    array_name_table_ptr
        jsr     find_name               ; Look for a variable with this name
        bcc     @found_array
        mva     decode_name_arity, B    ; B will count down number of times we have to push 10
        lday    #fp_ten
        jsr     load_fp0                ; Set FP0 to 10
@push:
        jsr     push_fp0
        bcs     @error
        dec     B
        bne     @push                   ; Push one more
        jsr     dimension_array         ; Returns with name_ptr set to array data
        bcs     @error
@found_array:
        jsr     find_array_element      ; On return name_ptr points to the location of the element
        bcc     @evaluate 

@error:
        rts

@not_array:
        jsr     find_or_add_variable
        bcs     @error
@evaluate:
        ldphaa  name_ptr                ; Remember name_ptr 
        jsr     evaluate_expression     ; Value is now on the evaluation stack
        plstaa  name_ptr                ; Restore name so we can assign it
        bcs     @error

; Fall through

; Pops a value from the stack and copies it into the variable identified by name_ptr.
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        mvax    name_ptr, dst_ptr       ; Copy into variable data
        lda     decode_name_type        ; Load the variable type
        tax                             ; While we're here, load the size of the variable type into Y
        ldy     type_size_table,x       ; Replace Y with the size of the type
        jsr     stack_free_value_with_type
        bcs     @error
        txa                             ; Becomes low byte of source address
        ldx     #>stack                 ; Stack page
        jsr     copy_y_from             ; Copy from stack into variable data
        clc                             ; Success
@error:
        rts
