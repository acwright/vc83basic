; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Decodes and executes statements and functions from the token stream.

.assert TOK_PRINT = $40, error

dispatch_statement:
        mva     stack_pos, reset_stack_pos      ; Save stack pos in case we have to roll it back
        mva     #OP_STACK_SIZE, op_stack_pos    ; Clear op stack
        jsr     decode_byte                     ; Get statement number
        cmp     #TOK_NAME
        beq     @impl_let
        and     #$3F                            ; Isolate statement offset from 0 to 63
        bpl     dispatch_entry                  ; Unconditional (X < 128)

@impl_let:
        jmp     exec_impl_let

dispatch_function:
        and     #$3F                            ; Isolate function offset from 0 to 63
        clc
        adc     #statement_count                ; Offset by statement_count to form unified index

dispatch_entry:
        tax                                     ; Save dispatch vector offset in X
        lsr     A                               ; Byte offset in flags table = X / 2
        tay
        lda     dispatch_flags,y
        bcc     @even                           ; Even index -> low nibble
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
statement_count = * - dispatch_vectors_l

        ; --- Functions ---
        .byte   <(fun_len-1)
        .byte   <(fun_str_s-1)
        .byte   <(fun_chr_s-1)
        .byte   <(fun_asc-1)
        .byte   <(fun_left_s-1)
        .byte   <(fun_right_s-1)
        .byte   <(fun_mid_s-1)
        .byte   <(fun_val-1)
        .byte   <(fun_fre-1)
        .byte   <(fun_peek-1)
        .byte   <(fun_dpeek-1)
        .byte   <(fun_adr-1)
        .byte   <(fun_usr-1)
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
.ifdef TARGET_SIM6502
        .byte   <(fun_ver_s-1)
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
        ; --- Functions ---
        .byte   >(fun_len-1)
        .byte   >(fun_str_s-1)
        .byte   >(fun_chr_s-1)
        .byte   >(fun_asc-1)
        .byte   >(fun_left_s-1)
        .byte   >(fun_right_s-1)
        .byte   >(fun_mid_s-1)
        .byte   >(fun_val-1)
        .byte   >(fun_fre-1)
        .byte   >(fun_peek-1)
        .byte   >(fun_dpeek-1)
        .byte   >(fun_adr-1)
        .byte   >(fun_usr-1)
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
.ifdef TARGET_SIM6502
        .byte   >(fun_ver_s-1)
.endif
.assert (* - dispatch_vectors_h) = dispatch_count, error

dispatch_flags:
.ifndef TARGET_SIM6502
        ; --- Statements (apple2: 26 statements = 13 bytes) ---
        .byte   0, 0, 0, 0, 0, 0
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; POKE (12), DPOKE (13)
        .byte   0, 0, 0, 0, 0, 0

        ; --- Functions (apple2: 24 functions = 12 bytes) ---
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_INT) | ((PROLOG_POP_FP | EPILOG_PUSH_STRING) << 4)    ; LEN (26), STR$ (27)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_STRING | EPILOG_PUSH_INT) << 4)   ; CHR$ (28), ASC (29)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)  ; LEFT$ (30), RIGHT$ (31)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_STRING | EPILOG_PUSH_FP) << 4)   ; MID$ (32), VAL (33)
        .byte   (PROLOG_NONE | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)            ; FRE (34), PEEK (35)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_STRING | EPILOG_PUSH_INT) << 4)     ; DPEEK (36), ADR (37)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)           ; USR (38), INT (39)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; LOG (40), EXP (41)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; SIN (42), COS (43)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; TAN (44), ATN (45)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; ABS (46), SGN (47)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; SQR (48), RND (49)
.else
        ; --- Statements (sim6502: 27 statements, BYE at 26) ---
        .byte   0, 0, 0, 0, 0, 0
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)  ; POKE (12), DPOKE (13)
        .byte   0, 0, 0, 0, 0, 0

        ; Byte 13: BYE (26) | (LEN (27) << 4)
        .byte   0 | ((PROLOG_POP_STRING | EPILOG_PUSH_INT) << 4)
        ; Bytes 14..25: remaining 24 functions shifted by 1 nibble
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)   ; STR$ (28), CHR$ (29)
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)  ; ASC (30), LEFT$ (31)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_STRING) << 4)  ; RIGHT$ (32), MID$ (33)
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_FP) | ((PROLOG_NONE | EPILOG_PUSH_INT) << 4)          ; VAL (34), FRE (35)
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)        ; PEEK (36), DPEEK (37)
        .byte   (PROLOG_POP_STRING | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)     ; ADR (38), USR (39)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; INT (40), LOG (41)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; EXP (42), SIN (43)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; COS (44), TAN (45)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; ATN (46), ABS (47)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_FP) << 4)             ; SGN (48), SQR (49)
        .byte   (PROLOG_POP_FP | EPILOG_PUSH_FP) | ((PROLOG_POP_FP | EPILOG_PUSH_STRING) << 4)        ; RND (50), VER$ (51)
.endif
.assert (* - dispatch_flags) = ((dispatch_count + 1) / 2), error
