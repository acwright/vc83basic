; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; POKE

exec_poke:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; Pop the value
        pha                             ; Push the low byte; high byte doesn't matter
        jsr     pop_int_fp0             ; Pop the address
        stax    BC                      ; Park it
        ldy     #0                      ; Prepare to store
        pla                             ; Recover the value
        sta     (BC),y                  ; Store it
        rts
