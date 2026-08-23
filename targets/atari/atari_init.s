; SPDX-FileCopyrightText: 2026 Willis Blackburn and Daniel Serpell
;
; SPDX-License-Identifier: MIT

; Buffers

.segment "BUFFERS"

buffer: .res BUFFER_SIZE
line_buffer: .res BUFFER_SIZE

; Primary stack
stack: .res PRIMARY_STACK_SIZE
; Operator stack
op_stack: .res OP_STACK_SIZE

.bss

old_dosini:     .res 2

.code

initialize_target:
        mvax    DOSINI, old_dosini      ; Save original DOS/OS init vector
        mvax    #reset_handler, DOSINI  ; System Reset returns to BASIC
        jsr     init_k_vector
        jmp     display_startup_banner

reset_handler:
        jsr     call_old_dosini         ; Initialize DOS buffers / FMS
        mvax    #reset_handler, DOSINI  ; Reassert in case DOS reset it
        raise   PS_READY

call_old_dosini:
        jmp     (old_dosini)
