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

old_brkvd:      .res 2

.code

initialize_target:
        mvax    #reset_handler, WARMSV  ; System Reset returns to BASIC
        mvax    BRKVD, old_brkvd        ; Save original OS Break vector
        mvax    #brk_handler, BRKVD     ; Install Break handler
        jsr     init_k_vector
        jmp     display_startup_banner

reset_handler:
        mvax    BRKVD, old_brkvd        ; Re-save vector in case warmstart reset it
        mvax    #brk_handler, BRKVD     ; Reinstall Break handler
        raise   PS_READY

brk_handler:
        inc     BRKKEY                  ; Acknowledge / clear break flag
        lda     program_state           ; Only stop if a program is running
        bne     @default
        cli                             ; Re-enable interrupts
        raise   ERR_STOPPED             ; Stop and return to READY

@default:
        jmp     (old_brkvd)
