; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; exit function provided by sim6502
.import exit

ex_statement_name_table:
        name_table_entry "BYE"
            RETURN
:       name_table_end

ex_statement_vectors:
        .word   exec_bye-1

; BYE: exits the interpeter

exec_bye:
        jmp     exit

ex_function_name_table:
        name_table_entry "VER"
:       name_table_end

ex_function_arity_table:
        .byte   1                       ; VER

ex_function_vectors:
        .word   fun_ver-1

fun_ver:
        jsr     pop_fp0                 ; Ignore argument
        lday    #fp_one
        jsr     load_fp0
        jmp     push_fp0
