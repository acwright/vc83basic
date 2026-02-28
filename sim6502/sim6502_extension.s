; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; exit function provided by sim6502
.import exit

ex_statement_name_table:
        name_table_entry "BYE"
            RETURN
:       name_table_end

ex_statement_exec_vectors:
        .word   exec_bye-1

; BYE: exits the interpeter

exec_bye:
        jmp     exit
