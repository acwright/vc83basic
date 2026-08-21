; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn / 2026 A.C. Wright
;
; SPDX-License-Identifier: MIT

.export io_get, io_put
.export io_read_record, io_end_record, io_end_field
.export io_save, io_load
.export putch, newline

.code

; Gets a single byte/key from console.
; A = mode (0 = blocking, 1 = non-blocking)
; Returns carry clear and byte in A if ok, carry set if no byte / error.

io_get:
        cmp     #1                      ; Non-blocking mode (INKEY$)?
        beq     @non_blocking
@wait_key:
        jsr     Chrin                   ; Non-blocking poll (C=1 if char available)
        bcc     @wait_key               ; Keep polling until key pressed
        clc
        rts

@non_blocking:
        jsr     Chrin                   ; C=1 if char available
        bcs     @got_key
        sec
        rts
@got_key:
        clc
        rts

; Puts a single character to the console.
; A = ASCII character
; Polls for ESC or CTRL-C while a BASIC program is running to allow break.

io_put:
putch:
        pha                             ; Save character to output
        lda     program_state           ; Only poll keyboard while a program is running
        bne     @output                 ; PS_READY (non-zero): skip break check
        jsr     Chrin                   ; Non-blocking poll (C=1 if char available)
        bcc     @output                 ; Nothing in the buffer
        cmp     #CH_ESC
        beq     @break
        cmp     #CH_CTRLC
        bne     @output                 ; Not a break key; continue
@break:
        pla                             ; Discard the saved character
        raise   ERR_STOPPED
@output:
        pla                             ; Restore character
        jmp     Chrout

; Emits record delimiter (CR + LF).

io_end_record:
newline:
        lda     #CH_CR
        jsr     io_put
        lda     #CH_LF
        jmp     io_put

; Emits field separator (tabs across zones).

io_end_field:
        bit     HW_PRESENT              ; Video present? (Bit 7 = HW_VID)
        bpl     @serial_tab
        lda     IO_MODE                 ; Video mode (0)?
        bne     @serial_tab
:       lda     #' '
        jsr     io_put
        lda     VID_CURSOR_X
        and     #$07                    ; 8-column tab zone
        bne     :-
        clc
        rts
@serial_tab:
        ldx     #4
:       lda     #' '
        jsr     io_put
        dex
        bne     :-
        clc
        rts

; Reads a text record (line) from console into buffer.
; NUL-terminates at EOL, returns length in A.

io_read_record:
readline:
        ldy     #0
@waitchar:
        jsr     Chrin
        bcc     @waitchar
        ; Check for break keys (ESC or CTRL-C) to interrupt a running program
        cmp     #CH_ESC
        beq     @check_break
        cmp     #CH_CTRLC
        beq     @check_break
        ; Check for backspace / delete
        cmp     #CH_BKSP
        beq     @backspace
        cmp     #CH_DEL
        beq     @backspace
        ; Check for CR (end of line)
        cmp     #CH_CR
        beq     @done
        ; Skip other non-printable control characters (< space)
        cmp     #CH_SPACE
        bcc     @waitchar
        ; Ignore if buffer full
        cpy     #BAS_LINBUF_SIZE
        bcs     @waitchar
        ; Store character and echo
        sta     buffer,y
        iny
        jsr     io_put
        jmp     @waitchar

@check_break:
        lda     program_state           ; Only break when a program is running
        bne     @waitchar               ; PS_READY (non-zero): discard and keep waiting
        raise   ERR_STOPPED

@backspace:
        cpy     #0
        beq     @waitchar               ; Nothing to delete
        dey
        lda     #CH_BKSP
        jsr     io_put
        jmp     @waitchar

@done:
        lda     #0
        sta     buffer,y                ; Null-terminate
        tya                             ; Return length in A
        pha
        jsr     io_end_record           ; Echo newline
        pla
        clc
        rts

; Copies string currently described in S0 (length in BC) to buffer with a NUL terminator.

copy_s0_to_buffer_nul:
        ldy     #0
        lda     (BC),y                  ; Length byte
        tay
        beq     @empty
        tax                             ; Length in X
        ldy     #0
@loop:
        lda     (S0),y
        sta     buffer,y
        iny
        dex
        bne     @loop
@empty:
        lda     #0                      ; NUL terminator
        sta     buffer,y
        rts

; Saves program memory to file via CompactFlash filesystem.
; S0 = filename string

io_save:
        jsr     copy_s0_to_buffer_nul
        lda     #<buffer
        sta     STR_PTR
        lda     #>buffer
        sta     STR_PTR+1
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR+1
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_FILE_SIZE
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_FILE_SIZE+1
        jsr     FsSaveFileAddr
        rts                             ; FsSaveFileAddr returns C=0 on success, C=1 on error

; Loads program memory from file via CompactFlash filesystem.
; S0 = filename string

io_load:
        jsr     copy_s0_to_buffer_nul
        lda     #<buffer
        sta     STR_PTR
        lda     #>buffer
        sta     STR_PTR+1
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        sta     FS_IO_ADDR+1
        jsr     FsLoadFileAddr
        bcs     @err                    ; Carry set = file not found or card error

        ; Validate header signature
        ldy     #3
@check_magic:
        lda     __BSS_RUN__ + __BSS_SIZE__,y
        cmp     vbas_header,y
        bne     @format_err
        dey
        bpl     @check_magic

        ; Walk line offsets to rebuild variable_name_table_ptr
        mvax    #(__BSS_RUN__ + __BSS_SIZE__ + 4), BC
        ldy     #Line::next_line_offset
@walk_loop:
        lda     (BC),y
        beq     @found_end
        clc
        adc     BC
        sta     BC
        bcc     @walk_loop
        inc     BC+1
        bne     @walk_loop
@found_end:
        clc
        lda     BC
        adc     #.sizeof(Line)
        sta     variable_name_table_ptr
        lda     BC+1
        adc     #0
        sta     variable_name_table_ptr+1

        jsr     clear_variables
        jsr     reset_program
        clc
        rts

@format_err:
        jsr     initialize_program
        sec
        rts

@err:
        sec
        rts

        