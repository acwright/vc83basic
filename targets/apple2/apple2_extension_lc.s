; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

TOK_AT    = $15

TOK_GR    = $5E
TOK_TEXT  = $5F
TOK_HOME  = $60
TOK_COLOR = $61
TOK_PLOT  = $62
TOK_HLIN  = $63
TOK_VLIN  = $64

TOK_PDL   = $99
TOK_SCRN  = $9A

.macro extension_custom_keywords
:       name_table_entry "AT"
.endmacro

.macro extension_statement_keywords
:       name_table_entry "GR"
:       name_table_entry "TEXT"
KEYWORD_BLOCK_6_OFFSET = keyword_counter
:       name_table_entry "HOME"
:       name_table_entry "COLOR"
:       name_table_entry "PLOT"
:       name_table_entry "HLIN"
:       name_table_entry "VLIN"
:       name_table_entry ""             ; Padding for even statement count
.endmacro

.macro extension_function_keywords
:       name_table_entry "PDL"
:       name_table_entry "SCRN"
.endmacro

.macro extension_pvm_statements
        BRANCH_IF_RANGE TOK_GR, 3, @done       ; GR, TEXT, HOME
        BRANCH_IF TOK_COLOR, pvm_expression
        BRANCH_IF TOK_PLOT, pvm_arg_2
        BRANCH_IF TOK_HLIN, pvm_hlin_vlin
        BRANCH_IF TOK_VLIN, pvm_hlin_vlin
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_PDL, pvm_fun_1
        BRANCH_IF TOK_SCRN, pvm_fun_2
.endmacro

.macro extension_statement_vectors_l
        .byte   <(SETGR-1)
        .byte   <(SETTXT-1)
        .byte   <(HOME-1)
        .byte   <(exec_color-1)
        .byte   <(exec_plot-1)
        .byte   <(exec_hlin-1)
        .byte   <(exec_vlin-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(SETGR-1)
        .byte   >(SETTXT-1)
        .byte   >(HOME-1)
        .byte   >(exec_color-1)
        .byte   >(exec_plot-1)
        .byte   >(exec_hlin-1)
        .byte   >(exec_vlin-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0                       ; GR, TEXT
        .byte   0                       ; HOME, COLOR
        .byte   0                       ; PLOT, HLIN
        .byte   0                       ; VLIN, padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_pdl-1)
        .byte   <(fun_scrn-1)
        .byte   0
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_pdl-1)
        .byte   >(fun_scrn-1)
        .byte   0
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4)        ; INKEY$, PDL
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | (0 << 4)                                           ; SCRN, padding
.endmacro

.macro extension_parser_code
pvm_hlin_vlin:
        CALL    pvm_arg_2
        MATCH   TOK_AT
        JUMP    pvm_expression
.endmacro

.macro extension_code
exec_color:
        jsr     evaluate_expression
        bne     @type_mismatch
        jsr     truncate_fp_to_int      ; Color value in AX
        jmp     SETCOL

@type_mismatch:
        jmp     raise_type_mismatch

exec_plot:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; Pop the Y value
        pha                             ; We'll move it into A later
        jsr     pop_int_fp0             ; Pop the X value
        tay                             ; Move X into Y for PLOT
        pla                             ; Get back Y from stack into A
        jmp     PLOT

exec_hlin:
        jsr     get_hlin_vlin_arguments
        jmp     HLINE

exec_vlin:
        jsr     get_hlin_vlin_arguments
        tax                             ; Swap A (column) and Y (start row)
        tya
        pha
        txa
        tay
        pla
        jmp     VLINE

get_hlin_vlin_arguments:
        jsr     evaluate_argument_list  ; Evaluate start and end
        inc     line_pos                ; Skip TOK_AT
        jsr     evaluate_expression
        bne     @type_mismatch
        jsr     truncate_fp_to_int      ; Get coordinate (Row for HLIN, Column for VLIN)
        pha                             ; Save on hardware stack
        jsr     pop_int_fp0             ; Get end point (H2/V2)
        sta     H2
        sta     V2
        jsr     pop_int_fp0             ; Get start point
        tay                             ; Start point into Y
        pla                             ; Coordinate into A
        rts

@type_mismatch:
        jmp     raise_type_mismatch

fun_pdl:
        tax
        jsr     PREAD                   ; Returns result in Y
        tya
        ldx     #0
        rts

fun_scrn:
        pha                             ; Save Y value (second arg)
        jsr     pop_int_fp0             ; Pop X value (first arg)
        tay                             ; Move X into Y
        pla                             ; Get back Y into A
        jsr     SCRN
        ldx     #0                      ; Make sure high byte is 0
        rts
.endmacro
