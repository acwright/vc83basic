; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

ex_statement_name_table:
        name_table_entry "GR"
            RETURN
:       name_table_entry "TEXT"
            RETURN
:       name_table_end

ex_statement_exec_vectors:
        .word   exec_gr-1
        .word   exec_text-1

exec_gr:
        jsr     SETGR
        rts

exec_text:
        jsr     SETTXT
        rts
