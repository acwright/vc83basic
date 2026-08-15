; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Decodes and executes one statement from the token stream.

.assert TOK_PRINT = $40, error

exec_statement:
        mva     stack_pos, reset_stack_pos      ; Save stack pos in case we have to roll it back
        mva     #OP_STACK_SIZE, op_stack_pos    ; Clear op stack
        jsr     decode_byte             ; Get statement number
        cmp     #TOK_NAME
        beq     @impl_let
        and     #$3F                    ; Isolate statement offset from 0 to 63
        tax
        lda     statement_vectors_h,x
        pha
        lda     statement_vectors_l,x
        pha
        rts                             ; This does the jump to the statement handler

@impl_let:
        jmp     exec_impl_let

statement_vectors_l:
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
        .byte   <(exec_poke-1)
        .byte   <(exec_dpoke-1)
        .byte   <(exec_dim-1)
        .byte   <(exec_data-1)
        .byte   <(exec_rem-1)
        .byte   <(exec_restore-1)
        .byte   <(exec_run-1)
        .byte   <(exec_stop-1)
        .byte   <(exec_end-1)
        .byte   <(exec_cont-1)
        .byte   <(initialize_program-1)
        .byte   <(clear_variables-1)
        .byte   <(exec_return-1)
        .byte   <(exec_pop-1)
.ifdef TARGET_SIM6502
        .byte   <(exec_bye-1)
.endif

statement_count = * - statement_vectors_l

statement_vectors_h:
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
        .byte   >(exec_poke-1)
        .byte   >(exec_dpoke-1)
        .byte   >(exec_dim-1)
        .byte   >(exec_data-1)
        .byte   >(exec_rem-1)
        .byte   >(exec_restore-1)
        .byte   >(exec_run-1)
        .byte   >(exec_stop-1)
        .byte   >(exec_end-1)
        .byte   >(exec_cont-1)
        .byte   >(initialize_program-1)
        .byte   >(clear_variables-1)
        .byte   >(exec_return-1)
        .byte   >(exec_pop-1)
.ifdef TARGET_SIM6502
        .byte   >(exec_bye-1)
.endif

.assert (* - statement_vectors_h) = statement_count, error
