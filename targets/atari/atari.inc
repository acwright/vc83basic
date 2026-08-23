; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

DOSINI = $0C
DOSVEC = $0A
BRKKEY = $11
COLCRS = $55

CH     = $02FC
HATABS = $031A

ICCOM  = $0342
ICSTA  = $0343
ICBAL  = $0344
ICBAH  = $0345
ICPTL  = $0346
ICPTH  = $0347
ICBLL  = $0348
ICBLH  = $0349
ICAX1  = $034A
ICAX2  = $034B

CIOV   = $E456

TOK_DOS   = $62

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
        .byte   0                       ; DOS + padding
.endmacro
