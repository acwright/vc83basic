; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.segment "ONCE"

; We only need the start message at startup, so we put it in the ONCE segment so it can later be overwritten by
; program data. Free memory is a constant; subtract 5 in order to account for null line (3 bytes) and end byte
; for variable and array name tables.

startup_message:
        .byte   startup_message_text_end - startup_message_text
startup_message_text:
        .byte   "VC83 BASIC "
.if .defined(__APPLE2__)    ; If Apple II then remap version number to uppercase
                .pushcharmap
                .repeat 26, i
                .charmap $61 + i, $41 + i
                .endrep
.endif
.include "version.inc"
.if .defined(__APPLE2__)
                .popcharmap
.endif
                .byte   " <> "
startup_message_text_end:

free_message:   .byte 11, " BYTES FREE"

fp_64k:         .byte $00, $00, $00, $00, 144

display_startup_banner:
        lday    #startup_message
        jsr     print_string
        ldax    #((__MAIN_START__ + __MAIN_SIZE__) - (__BSS_RUN__ + __BSS_SIZE__ + 4) - 5)
        jsr     int_to_fp               ; Load into FP0
        lda     FP0s                    ; Check if it was negative
        bpl     @positive
        lday    #fp_64k                 ; Add 64K to get the correct number
        jsr     fadd
@positive:
        jsr     print_number
        lday    #free_message
        jsr     print_string
        jmp     io_end_record

.code
