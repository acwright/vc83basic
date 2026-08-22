; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

TOK_BYE   = $62
TOK_VER_S = $9A

.macro extension_statement_keywords
:       name_table_entry "BYE"
:       name_table_entry ""             ; Padding for even statement count
.endmacro

.macro extension_function_keywords
:       name_table_entry "VER$"
:       name_table_entry ""             ; Padding for even function count
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_BYE, @done
.endmacro

.macro extension_pvm_functions
        BRANCH_IF TOK_VER_S, pvm_fun_0
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_bye-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_bye-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0                       ; BYE + padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_ver_s-1)
        .byte   0
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_ver_s-1)
        .byte   0
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_NONE | EPILOG_PUSH_STRING) | (0 << 4)                                   ; VER$ + padding
.endmacro

.macro extension_code
; exit function provided by sim6502
.import exit

; BYE: exits the interpeter

exec_bye:
        jmp     exit

version:
.include "version.inc"
version_length = * - version

fun_ver_s:
        lda     #version_length         ; Ignore argument
        jsr     string_alloc_for_copy
        ldax    #version
        jmp     copy_y_from
.endmacro
