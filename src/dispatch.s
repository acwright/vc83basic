; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Decodes and executes statements and functions from the token stream.

.assert TOK_PRINT = $40, error
.assert TOK_LEN = $80, error

dispatch_statement:
        mva     stack_pos, reset_stack_pos      ; Save stack pos in case we have to roll it back
        mva     #OP_STACK_SIZE, op_stack_pos    ; Clear op stack
        jsr     decode_byte                     ; Get statement number
        cmp     #TOK_NAME
        beq     exec_impl_let
        pha                                     ; Save statement token
        ldx     #$80                            ; Default channel = $80 (bit 7 set = default)
        jsr     peek_byte
        sec
        sbc     #TOK_CHANNEL_0
        cmp     #8                              ; Channel in range 0..7?
        bcs     @not_channel                    ; If taken, C is already set!
        inc     line_pos                        ; Consume channel token
        tax                                     ; Channel index 0..7 into X (bit 7 clear)
        sec                                     ; Set C for sbc when branch was not taken
@not_channel:
        stx     channel                         ; Store final channel (default $80 or explicit 0..7)
        pla                                     ; Restore statement token
        sbc     #TOK_PRINT                      ; Convert token to unified index
        bpl     dispatch                        ; Unconditional (index < 128)

; LET statement:

exec_let:
        inc     line_pos                ; Skip TOK_NAME
exec_impl_let:
        jsr     decode_name             ; Sets decode_name_ptr and decode_name_length
        jsr     find_or_add_variable
        inc     line_pos                ; Skip terminator
        ldphaa  name_ptr                ; Remember name_ptr 
        jsr     evaluate_expression     ; Value is now on the evaluation stack
        plstaa  name_ptr                ; Restore name so we can assign it

; Fall through

; Pops a value from the stack and copies it into the variable identified by name_ptr.
; name_ptr = pointer to the variable's data in the variable name table

assign_variable:
        ldy     decode_name_type        ; Load the target variable type index
        tya                             ; Pass type in A
        jsr     stack_free_value_with_type  ; Drop the actively evaluated item from top of stack and yield X (preserves Y)
        lda     type_size_table,y       ; Fetch structural footprint directly mapping index (5 for numeric, 2 for string offset)
        sta     B                       ; Save loop delimiter threshold inside B locally
        ldy     #0                      ; Init sequence relative iteration pointer to exactly 0 to offset naturally up
@copy_loop:
        lda     stack,x                 ; Pull byte directly mapping baseline evaluation layer
        sta     (name_ptr),y            ; Bind into memory aligned table space
        inx                             ; Traverse source footprint
        iny                             ; Traverse destination footprint
        cpy     B                       ; Evaluate alignment matching our explicitly retained structural delimiter
        bne     @copy_loop
        rts

dispatch_function:
        sbc     #(TOK_LEN - statement_count)    ; C is set from CMP in caller; convert token to unified index

dispatch:
        tax                                     ; Save dispatch vector offset in X
        cpx     #16                             ; Statement with no prolog/epilog?
        bcc     @shift                          ; If so, A is 0..15, 4 LSRs will make A=0
        lsr     A                               ; Byte offset in flags table = X / 2
        tay
        lda     dispatch_flags-8,y
        bcc     @even                           ; Even index -> low nibble
@shift:
        lsr     A                               ; Odd index -> high nibble
        lsr     A
        lsr     A
        lsr     A
@even:
        sta     C                               ; C = %0000_pp_ee
        and     #$03                            ; Epilog bits 0-1
        beq     @skip_epilog
        asl     A                               ; A = 2, 4, 6
        tay
        lda     dispatch_epilogs-1,y            ; Push epilog
        pha
        lda     dispatch_epilogs-2,y
        pha
@skip_epilog:
        lda     dispatch_vectors_h,x            ; Push handler vector
        pha
        lda     dispatch_vectors_l,x
        pha
        lda     C
        and     #$0C                            ; Prolog bits in positions 2-3 (values 0, 4, 8, 12)
        beq     @done
        lsr     A                               ; Shift to offset 2, 4, 6
        tay
        lda     dispatch_prologs-1,y            ; Push prolog
        pha
        lda     dispatch_prologs-2,y
        pha
        jmp     evaluate_argument_list          ; Will chain to handler etc.

@done:
        rts

dispatch_prologs:
        .word   pop_fp0-1
        .word   pop_int_fp0-1
        .word   pop_string_s0-1

dispatch_epilogs:
        .word   push_fp0-1
        .word   push_int_fp0-1
        .word   push_string-1

dispatch_vectors_l:
        ; --- Statements ---
        .byte   <(exec_print-1)
        .byte   <(exec_print-1)
        .byte   <(exec_let-1)
        .byte   <(exec_for-1)
        .byte   <(exec_next-1)
        .byte   <(exec_if-1)
        .byte   <(exec_input-1)
        .byte   <(exec_read-1)
        .byte   <(exec_on_goto_gosub-1)
        .byte   <(exec_goto-1)
        .byte   <(exec_gosub-1)
        .byte   <(exec_list-1)
        .byte   <(exec_rem-1)
        .byte   <(exec_restore-1)
        .byte   <(exec_dim-1)
        .byte   <(exec_data-1)
        .byte   <(exec_poke-1)
        .byte   <(exec_dpoke-1)
        .byte   <(exec_run-1)
        .byte   <(exec_stop-1)
        .byte   <(exec_end-1)
        .byte   <(exec_cont-1)
        .byte   <(initialize_program-1)
        .byte   <(clear_variables-1)
        .byte   <(exec_return-1)
        .byte   <(exec_pop-1)
        .byte   <(exec_open-1)
        .byte   <(exec_close-1)
        .byte   <(exec_get-1)
        .byte   <(exec_put-1)
        .byte   <(exec_xio-1)
        .byte   <(exec_save-1)
        .byte   <(exec_load-1)
.if .definedmacro(extension_statement_vectors_l)
        extension_statement_vectors_l
.else
        .byte   0
.endif

statement_count = * - dispatch_vectors_l

        ; --- Functions ---
        .byte   <(fun_len-1)
        .byte   <(fun_str_s-1)
        .byte   <(fun_chr_s-1)
        .byte   <(fun_asc-1)
        .byte   <(fun_val-1)
        .byte   <(fun_peek-1)
        .byte   <(fun_dpeek-1)
        .byte   <(fun_adr-1)
        .byte   <(floor-1)
        .byte   <(flog-1)
        .byte   <(fexp-1)
        .byte   <(fsin-1)
        .byte   <(fcos-1)
        .byte   <(ftan-1)
        .byte   <(fatn-1)
        .byte   <(fun_abs-1)
        .byte   <(fun_sgn-1)
        .byte   <(fun_sqr-1)
        .byte   <(fun_rnd-1)
        .byte   <(fun_left_s-1)
        .byte   <(fun_right_s-1)
        .byte   <(fun_usr-1)
        .byte   <(fun_mid_s-1)
        .byte   <(fun_fre-1)
        .byte   <(fun_inkey_s-1)
.if .definedmacro(extension_function_vectors_l)
        extension_function_vectors_l
.else
        .byte   0
.endif

dispatch_count = * - dispatch_vectors_l
function_count = dispatch_count - statement_count

dispatch_vectors_h:
        ; --- Statements ---
        .byte   >(exec_print-1)
        .byte   >(exec_print-1)
        .byte   >(exec_let-1)
        .byte   >(exec_for-1)
        .byte   >(exec_next-1)
        .byte   >(exec_if-1)
        .byte   >(exec_input-1)
        .byte   >(exec_read-1)
        .byte   >(exec_on_goto_gosub-1)
        .byte   >(exec_goto-1)
        .byte   >(exec_gosub-1)
        .byte   >(exec_list-1)
        .byte   >(exec_rem-1)
        .byte   >(exec_restore-1)
        .byte   >(exec_dim-1)
        .byte   >(exec_data-1)
        .byte   >(exec_poke-1)
        .byte   >(exec_dpoke-1)
        .byte   >(exec_run-1)
        .byte   >(exec_stop-1)
        .byte   >(exec_end-1)
        .byte   >(exec_cont-1)
        .byte   >(initialize_program-1)
        .byte   >(clear_variables-1)
        .byte   >(exec_return-1)
        .byte   >(exec_pop-1)
        .byte   >(exec_open-1)
        .byte   >(exec_close-1)
        .byte   >(exec_get-1)
        .byte   >(exec_put-1)
        .byte   >(exec_xio-1)
        .byte   >(exec_save-1)
        .byte   >(exec_load-1)
.if .definedmacro(extension_statement_vectors_h)
        extension_statement_vectors_h
.else
        .byte   0
.endif

        ; --- Functions ---
        .byte   >(fun_len-1)
        .byte   >(fun_str_s-1)
        .byte   >(fun_chr_s-1)
        .byte   >(fun_asc-1)
        .byte   >(fun_val-1)
        .byte   >(fun_peek-1)
        .byte   >(fun_dpeek-1)
        .byte   >(fun_adr-1)
        .byte   >(floor-1)
        .byte   >(flog-1)
        .byte   >(fexp-1)
        .byte   >(fsin-1)
        .byte   >(fcos-1)
        .byte   >(ftan-1)
        .byte   >(fatn-1)
        .byte   >(fun_abs-1)
        .byte   >(fun_sgn-1)
        .byte   >(fun_sqr-1)
        .byte   >(fun_rnd-1)
        .byte   >(fun_left_s-1)
        .byte   >(fun_right_s-1)
        .byte   >(fun_usr-1)
        .byte   >(fun_mid_s-1)
        .byte   >(fun_fre-1)
        .byte   >(fun_inkey_s-1)
.if .definedmacro(extension_function_vectors_h)
        extension_function_vectors_h
.else
        .byte   0
.endif

.assert (* - dispatch_vectors_h) = dispatch_count, error

dispatch_flags:
        ; --- Statements ---
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                                                  ; POKE, DPOKE
        .byte   0, 0, 0, 0                                                                              ; RUN..POP
        .byte   0                                                                                       ; OPEN, CLOSE
        .byte   PROLOG_NONE | (PROLOG_POP_INT << 4)                                                    ; GET, PUT
        .byte   PROLOG_NONE | (PROLOG_POP_STRING << 4)                                                  ; XIO, SAVE
        .byte   PROLOG_POP_STRING | (PROLOG_NONE << 4)                                                  ; LOAD + BYE/padding
        invoke_if_defined extension_statement_flags

        ; --- Functions ---
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_INT) | ((PROLOG_POP_FP | EPILOG_PUSH_STRING) << 4)    ; LEN, STR$
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_STRING | EPILOG_PUSH_INT) << 4)   ; CHR$, ASC
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_FP) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)       ; VAL, PEEK
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_STRING | EPILOG_PUSH_INT) << 4)     ; DPEEK, ADR
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; INT, LOG
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; EXP, SIN
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; COS, TAN
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; ATN, ABS
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; SGN, SQR
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)       ; RND, LEFT$
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)     ; RIGHT$, USR
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_NONE | EPILOG_PUSH_INT) << 4)        ; MID$, FRE
.if .definedmacro(extension_function_vectors_l)
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | ((PROLOG_NONE | EPILOG_PUSH_STRING) << 4)        ; INKEY$, VER$
.else
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | (0 << 4)                                           ; INKEY$ + padding
.endif

.assert (* - dispatch_flags) = ((dispatch_count - 16 + 1) / 2), error
