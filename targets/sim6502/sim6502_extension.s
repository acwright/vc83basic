; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

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
