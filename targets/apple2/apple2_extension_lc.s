; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.code

exec_color:
        jsr     evaluate_expression
        bne     @type_mismatch
        jsr     truncate_fp_to_int      ; Color value in AX
        jmp     SETCOL

@type_mismatch:
        jmp     raise_type_mismatch

exec_plot:
        jsr     evaluate_argument_list
        jsr     pop_int_fp0             ; Pop the Y value
        pha                             ; We'll move it into A later
        jsr     pop_int_fp0             ; Pop the X value
        tay                             ; Move X into Y for PLOT
        pla                             ; Get back Y from stack into A
        jmp     PLOT

exec_hlin:
        jsr     get_hlin_vlin_arguments
        jmp     HLINE

exec_vlin:
        jsr     get_hlin_vlin_arguments
        tax                             ; Swap A (column) and Y (start row)
        tya
        pha
        txa
        tay
        pla
        jmp     VLINE

get_hlin_vlin_arguments:
        jsr     evaluate_argument_list  ; Evaluate start and end
        inc     line_pos                ; Skip TOK_AT
        jsr     evaluate_expression
        bne     @type_mismatch
        jsr     truncate_fp_to_int      ; Get coordinate (Row for HLIN, Column for VLIN)
        pha                             ; Save on hardware stack
        jsr     pop_int_fp0             ; Get end point (H2/V2)
        sta     H2
        sta     V2
        jsr     pop_int_fp0             ; Get start point
        tay                             ; Start point into Y
        pla                             ; Coordinate into A
        rts

@type_mismatch:
        jmp     raise_type_mismatch

fun_pdl:
        tax
        jsr     PREAD                   ; Returns result in Y
        tya
        ldx     #0
        rts

fun_scrn:
        pha                             ; Save Y value (second arg)
        jsr     pop_int_fp0             ; Pop X value (first arg)
        tay                             ; Move X into Y
        pla                             ; Get back Y into A
        jsr     SCRN
        ldx     #0                      ; Make sure high byte is 0
        rts
