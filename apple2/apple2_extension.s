; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "PARSER"

ex_statement_name_table:
        name_table_entry "GR"
            RETURN
:       name_table_entry "TEXT"
            RETURN
:       name_table_end

ex_function_name_table:
        name_table_entry "PDL"
:       name_table_end

.segment "VECTORS"

ex_statement_vectors:
        .word   exec_gr-1
        .word   exec_text-1

.code

exec_gr:
        jsr     SETGR
        rts

exec_text:
        jsr     SETTXT
        rts

.segment "FUNCTABS"

ex_function_table:
        .word   fun_pdl-1
        .byte   1 | PROLOG_POP_INT | EPILOG_PUSH_INT

.code

fun_pdl:
        jsr     PREAD                   ; Returns result in Y
        tya
        ldx     #0
        rts
