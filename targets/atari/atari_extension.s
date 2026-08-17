; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

TOK_DOS   = $5A

.macro extension_statement_keywords
:       name_table_entry "DOS"
:       name_table_entry ""             ; Padding for even statement count
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_DOS, @done
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_dos-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_dos-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0
.endmacro

.macro extension_code
exec_dos:
        jmp     (DOSVEC)
.endmacro
