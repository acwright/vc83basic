; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT
;
; ac6502 BASIC extensions. Adds hardware-specific statements and
; functions that mirror the Integer BASIC built into the 6502-BIOS:
; CLS, LOCATE, COLOR, SOUND, VOL, PAUSE, WAIT, TIME, DATE, SETTIME,
; SETDATE, NVRAM, BANK, MEM, SYS and JOY(), INKEY(), NVRAM().
;
; Missing hardware is handled gracefully: statements print "NO DEVICE"
; (or silently skip for video/sound commands, matching the BIOS); the
; hardware-reading functions return 0.

.setcpu "65C02"

TOK_CLS     = $5E
TOK_LOCATE  = $5F
TOK_COLOR   = $60
TOK_SOUND   = $61
TOK_VOL     = $62
TOK_PAUSE   = $63
TOK_WAIT    = $64
TOK_TIME    = $65
TOK_DATE    = $66
TOK_SETTIME = $67
TOK_SETDATE = $68
TOK_NVRAM_W = $69
TOK_BANK    = $6A
TOK_MEM     = $6B
TOK_SYS     = $6C

TOK_JOY     = $9A
TOK_INKEY   = $9B
TOK_NVRAM_F = $9C

.macro extension_statement_keywords
:       name_table_entry "CLS"
:       name_table_entry "LOCATE"
KEYWORD_BLOCK_6_OFFSET = keyword_counter
:       name_table_entry "COLOR"
:       name_table_entry "SOUND"
:       name_table_entry "VOL"
:       name_table_entry "PAUSE"
:       name_table_entry "WAIT"
:       name_table_entry "TIME"
:       name_table_entry "DATE"
:       name_table_entry "SETTIME"
:       name_table_entry "SETDATE"
:       name_table_entry "NVRAM"
:       name_table_entry "BANK"
:       name_table_entry "MEM"
:       name_table_entry "SYS"
:       name_table_entry ""             ; Padding for even statement count
.endmacro

.macro extension_function_keywords
:       name_table_entry "JOY"
:       name_table_entry "INKEY"
:       name_table_entry "NVRAM"
:       name_table_entry ""             ; Padding for even function count
.endmacro

.macro extension_pvm_statements
        BRANCH_IF TOK_CLS, @done
        BRANCH_IF TOK_LOCATE, pvm_arg_2
        BRANCH_IF TOK_COLOR, pvm_arg_2
        BRANCH_IF TOK_SOUND, pvm_arg_3
        BRANCH_IF TOK_VOL, pvm_expression
        BRANCH_IF TOK_PAUSE, pvm_expression
        BRANCH_IF TOK_WAIT, pvm_arg_2
        BRANCH_IF TOK_TIME, @done
        BRANCH_IF TOK_DATE, @done
        BRANCH_IF TOK_SETTIME, pvm_arg_3
        BRANCH_IF TOK_SETDATE, pvm_arg_4
        BRANCH_IF TOK_NVRAM_W, pvm_arg_2
        BRANCH_IF TOK_BANK, pvm_expression
        BRANCH_IF TOK_MEM, @done
        BRANCH_IF TOK_SYS, pvm_expression
.endmacro

.macro extension_parser_code
pvm_arg_4:
        CALL    pvm_expression
        MATCH   TOK_COMMA
        JUMP    pvm_arg_3
.endmacro

.macro extension_pvm_functions
        BRANCH_IF_RANGE TOK_JOY, 3, pvm_fun_1
.endmacro

.macro extension_statement_vectors_l
        .byte   <(exec_cls-1)
        .byte   <(exec_locate-1)
        .byte   <(exec_color-1)
        .byte   <(exec_sound-1)
        .byte   <(exec_vol-1)
        .byte   <(exec_pause-1)
        .byte   <(exec_wait-1)
        .byte   <(exec_time-1)
        .byte   <(exec_date-1)
        .byte   <(exec_settime-1)
        .byte   <(exec_setdate-1)
        .byte   <(exec_nvram_w-1)
        .byte   <(exec_bank-1)
        .byte   <(exec_mem-1)
        .byte   <(exec_sys-1)
        .byte   0
.endmacro

.macro extension_statement_vectors_h
        .byte   >(exec_cls-1)
        .byte   >(exec_locate-1)
        .byte   >(exec_color-1)
        .byte   >(exec_sound-1)
        .byte   >(exec_vol-1)
        .byte   >(exec_pause-1)
        .byte   >(exec_wait-1)
        .byte   >(exec_time-1)
        .byte   >(exec_date-1)
        .byte   >(exec_settime-1)
        .byte   >(exec_setdate-1)
        .byte   >(exec_nvram_w-1)
        .byte   >(exec_bank-1)
        .byte   >(exec_mem-1)
        .byte   >(exec_sys-1)
        .byte   0
.endmacro

.macro extension_statement_flags
        .byte   0 | (PROLOG_POP_INT << 4)                               ; CLS, LOCATE
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; COLOR, SOUND
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; VOL, PAUSE
        .byte   PROLOG_POP_INT | (0 << 4)                               ; WAIT, TIME
        .byte   0 | (PROLOG_POP_INT << 4)                               ; DATE, SETTIME
        .byte   PROLOG_POP_INT | (PROLOG_POP_INT << 4)                  ; SETDATE, NVRAM
        .byte   PROLOG_POP_INT | (0 << 4)                               ; BANK, MEM
        .byte   PROLOG_POP_INT | (0 << 4)                               ; SYS, padding
.endmacro

.macro extension_function_vectors_l
        .byte   <(fun_joy-1)
        .byte   <(fun_inkey-1)
        .byte   <(fun_nvram-1)
        .byte   0
.endmacro

.macro extension_function_vectors_h
        .byte   >(fun_joy-1)
        .byte   >(fun_inkey-1)
        .byte   >(fun_nvram-1)
        .byte   0
.endmacro

.macro extension_function_flags
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | ((PROLOG_POP_INT | EPILOG_PUSH_INT) << 4) ; JOY, INKEY
        .byte   (PROLOG_POP_INT | EPILOG_PUSH_INT) | (0 << 4)                                   ; NVRAM, padding
.endmacro

.macro extension_code

; ---------------------------------------------------------------------------
; Small utilities
; ---------------------------------------------------------------------------

; Print a null-terminated string pointed to by AX (no newline).
ex_print_cstr:
        stax    BC
        ldy     #0
@next:
        lda     (BC),y
        beq     @done
        jsr     putch
        iny
        bne     @next
@done:
        rts

; Print a null-terminated string pointed to by AX followed by a newline.
ex_print_cstr_nl:
        jsr     ex_print_cstr
        jmp     newline

; Print "NO DEVICE" + newline.
ex_no_device:
        ldax    #ex_str_no_device
        jmp     ex_print_cstr_nl

ex_str_no_device:
        .byte   "NO DEVICE", 0

; Print A as two decimal digits (A must be 0-99).
ex_print_2d:
        ldx     #0
@tens:
        cmp     #10
        bcc     @done
        sec
        sbc     #10
        inx
        bne     @tens                   ; unconditional (X was just incremented so it's non-zero)
@done:
        pha
        txa
        clc
        adc     #'0'
        jsr     putch
        pla
        clc
        adc     #'0'
        jmp     putch

; Print A as two hex digits.
ex_print_2h:
        pha
        lsr     A
        lsr     A
        lsr     A
        lsr     A
        jsr     ex_print_nib
        pla
        and     #$0F
ex_print_nib:
        cmp     #10
        bcc     @digit
        clc
        adc     #'A' - 10
        jmp     putch
@digit:
        clc
        adc     #'0'
        jmp     putch

; Convert AX (16-bit signed int) to FP0 and print as a number.
ex_print_ax:
        jsr     int_to_fp
        jmp     print_number

; ---------------------------------------------------------------------------
; Video statements: CLS, LOCATE, COLOR
; ---------------------------------------------------------------------------

exec_cls:
        bit     HW_PRESENT              ; HW_VID is bit 7
        bpl     @skip
        jmp     VideoClear
@skip:
        rts

exec_locate:
        tay                             ; Y = row (last arg popped by prolog)
        jsr     pop_int_fp0             ; col -> AX
        tax                             ; X = col
        bit     HW_PRESENT
        bpl     @skip
        jmp     VideoSetCursor
@skip:
        rts

exec_color:
        and     #$0F
        sta     D                       ; D = bg nibble (last arg popped by prolog)
        jsr     pop_int_fp0             ; fg -> AX
        asl     A
        asl     A
        asl     A
        asl     A
        ora     D                       ; (fg<<4) | bg
        bit     HW_PRESENT
        bpl     @skip
        jmp     VideoSetColor
@skip:
        rts

; ---------------------------------------------------------------------------
; Sound statements: SOUND voice, freq, dur / VOL n
; ---------------------------------------------------------------------------

exec_sound:
        pha                             ; push dur_lo on CPU stack (dur in AX from prolog)
        txa
        pha                             ; push dur_hi on CPU stack
        jsr     pop_int_fp0             ; freq (Hz) -> AX (A=lo, X=hi)
        ; Convert Hz to SID register: reg = Hz*16 + Hz - Hz/4 (= Hz * 16.75)
        ; Matches the conversion in the BIOS BASIC BasCmdSound routine.
        sta     B                       ; B = Hz_lo (original)
        stx     C                       ; C = Hz_hi (original)
        lda     B                       ; copy into D:E for the shifted accumulator
        sta     D
        lda     C
        sta     E
        asl     D                       ; D:E = Hz * 16 (4 left shifts)
        rol     E
        asl     D
        rol     E
        asl     D
        rol     E
        asl     D
        rol     E
        clc                             ; D:E = Hz * 17
        lda     D
        adc     B
        sta     D
        lda     E
        adc     C
        sta     E
        lsr     C                       ; B:C = Hz / 4 (2 right shifts)
        ror     B
        lsr     C
        ror     B
        sec                             ; D:E = Hz * 17 - Hz/4 = Hz * 16.75
        lda     D
        sbc     B
        sta     D
        lda     E
        sbc     C
        sta     E
        ; Push converted SID freq (D=lo, E=hi) so we can pop voice next
        lda     E
        pha                             ; push freqHi on CPU stack
        lda     D
        pha                             ; push freqLo on CPU stack
        jsr     pop_int_fp0             ; voice (1-3) -> A
        dec     A                       ; convert to 0-indexed (0-2)
        sta     E                       ; E = voice
        lda     HW_PRESENT
        and     #HW_SID
        beq     @no_sid
        pla                             ; freqLo
        tax                             ; X = freqLo
        pla                             ; freqHi
        tay                             ; Y = freqHi
        lda     E                       ; A = voice (0-indexed)
        jsr     SidPlayNote
        pla                             ; dur_hi
        tax                             ; X = dur_hi
        pla                             ; dur_lo
        jsr     SysDelay
        jmp     SidSilence
@no_sid:
        pla                             ; discard freqLo
        pla                             ; discard freqHi
        pla                             ; discard dur_hi
        pla                             ; discard dur_lo
        rts

exec_vol:
        sta     D                       ; level in A from prolog
        lda     HW_PRESENT
        and     #HW_SID
        beq     @skip
        lda     D
        jmp     SidSetVolume
@skip:
        rts

; ---------------------------------------------------------------------------
; Timing statements: PAUSE n / WAIT addr, mask
; ---------------------------------------------------------------------------

exec_pause:
        jmp     SysDelay                ; count in AX from prolog

exec_wait:
        sta     D                       ; D = mask (from prolog)
        jsr     pop_int_fp0             ; address -> AX
        stax    BC                      ; BC = pointer
@loop:
        jsr     check_break             ; From ac6502_io.s: peeks, so non-break keys survive
        ldy     #0
        lda     (BC),y
        and     D
        beq     @loop
        rts

; ---------------------------------------------------------------------------
; Time / date statements
; ---------------------------------------------------------------------------

exec_time:
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       jsr     RtcReadTime             ; A=hours, X=minutes, Y=seconds
        phy                             ; save seconds
        phx                             ; save minutes
        jsr     ex_print_2d             ; hours
        lda     #':'
        jsr     putch
        pla                             ; minutes
        jsr     ex_print_2d
        lda     #':'
        jsr     putch
        pla                             ; seconds
        jsr     ex_print_2d
        jmp     newline

exec_date:
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       jsr     RtcReadDate             ; A=day, X=month, Y=year; RTC_BUF_CENT=century
        pha                             ; save day (last out)
        phx                             ; save month
        phy                             ; save year (first out)
        lda     RTC_BUF_CENT
        jsr     ex_print_2d             ; century
        pla                             ; year
        jsr     ex_print_2d
        lda     #'-'
        jsr     putch
        pla                             ; month
        jsr     ex_print_2d
        lda     #'-'
        jsr     putch
        pla                             ; day
        jsr     ex_print_2d
        jmp     newline

exec_settime:
        sta     C                       ; C = seconds (from prolog)
        jsr     pop_int_fp0             ; mm -> AX
        sta     D                       ; D = minutes
        jsr     pop_int_fp0             ; hh -> AX
        sta     E                       ; E = hours
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       lda     E                       ; A = hours
        ldx     D                       ; X = minutes
        ldy     C                       ; Y = seconds
        jmp     RtcWriteTime

exec_setdate:
        sta     B                       ; B = day (from prolog)
        jsr     pop_int_fp0             ; mm -> AX
        sta     C                       ; C = month
        jsr     pop_int_fp0             ; yy -> AX
        sta     D                       ; D = year
        jsr     pop_int_fp0             ; cc -> AX
        sta     RTC_BUF_CENT
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       lda     B                       ; A = day
        ldx     C                       ; X = month
        ldy     D                       ; Y = year
        jmp     RtcWriteDate

; ---------------------------------------------------------------------------
; NVRAM addr, value (write)
; ---------------------------------------------------------------------------

exec_nvram_w:
        sta     D                       ; D = value (from prolog)
        jsr     pop_int_fp0             ; address -> AX
        sta     E                       ; E = address
        lda     HW_PRESENT
        and     #HW_RTC
        bne     :+
        jmp     ex_no_device
:       ldx     E                       ; X = address
        lda     D                       ; A = value
        jmp     RtcWriteNVRAM

; ---------------------------------------------------------------------------
; System statements: BANK, MEM, SYS
; ---------------------------------------------------------------------------

exec_bank:
        sta     D                       ; bank in A from prolog
        lda     HW_PRESENT
        and     #HW_RAM_L
        bne     :+
        jmp     ex_no_device
:       lda     D
        sta     RAM_BANK_L
        rts

exec_mem:
        jsr     fun_fre                 ; A=lo, X=hi of free bytes
        jsr     ex_print_ax             ; print free bytes
        ldax    #ex_str_free
        jsr     ex_print_cstr_nl
        ldax    #ex_str_hw
        jsr     ex_print_cstr
        lda     #'$'
        jsr     putch
        lda     HW_PRESENT
        jsr     ex_print_2h
        jsr     newline
        ldax    #ex_str_io
        jsr     ex_print_cstr
        lda     IO_MODE
        beq     @video
        ldax    #ex_str_serial
        jmp     ex_print_cstr_nl
@video:
        ldax    #ex_str_video
        jmp     ex_print_cstr_nl

ex_str_free:    .byte   " FREE", 0
ex_str_hw:      .byte   "HW=", 0
ex_str_io:      .byte   "IO=", 0
ex_str_video:   .byte   "VIDEO", 0
ex_str_serial:  .byte   "SERIAL", 0

exec_sys:
        stax    BC                      ; address in AX from prolog
        jmp     (BC)

; ---------------------------------------------------------------------------
; Functions
; ---------------------------------------------------------------------------

; JOY(n) -- return joystick bitmask for port n (1 or 2); 0 if GPIO absent.
fun_joy:
        sta     D                       ; save port number (from prolog)
        lda     HW_PRESENT
        and     #HW_GPIO
        beq     @none
        lda     D
        cmp     #2
        bcs     @p2                     ; n >= 2 -> port 2
        jsr     ReadJoystick1
        ldx     #0
        rts
@p2:
        jsr     ReadJoystick2
        ldx     #0
        rts
@none:
        lda     #0
        tax
        rts

; INKEY(x) -- return ASCII code of a pending key, or 0 if none.
; The argument is ignored (vc83 functions require at least one arg).
fun_inkey:
        jsr     get_key                 ; Raw, non-echoing (C=1 if char available)
        bcs     @got
        lda     #0
@got:
        ldx     #0
        rts

; NVRAM(addr) -- read RTC NVRAM byte; returns 0 if RTC absent.
fun_nvram:
        sta     D                       ; D = address (from prolog)
        lda     HW_PRESENT
        and     #HW_RTC
        beq     @none
        ldx     D                       ; X = address
        jsr     RtcReadNVRAM            ; returns byte in A
        ldx     #0
        rts
@none:
        lda     #0
        tax
        rts

.endmacro
