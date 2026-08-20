; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

.export io_open, io_close, io_close_all, io_get, io_put
.export io_read_record, io_end_record, io_end_field
.export io_save, io_load, io_xio

.code

; Opens a file on channel.
; channel = channel (0..7), A = mode, S0 = filename string
; Returns carry clear if ok, carry set if error.

io_open:
        clc
        rts

; Closes channel.
; channel = channel (0..7)
; Returns carry clear.

io_close:
        clc
        rts

; Closes all open channels.

io_close_all:
        rts

; Gets a single byte/key from channel.
; channel = channel (0..7), A = mode (0 = blocking, 1 = non-blocking)
; Returns carry clear and byte in A if ok, carry set if no byte / error.

io_get:
        tax                             ; Save mode in X (0 = blocking, 1 = non-blocking)
@wait_key:
        lda     $C000                   ; Read Apple II keyboard
        bpl     @no_key                 ; Bit 7 clear -> no key pressed
        bit     $C010                   ; Clear keyboard strobe
        and     #$7F                    ; Convert to standard ASCII
        clc
        rts
@no_key:
        cpx     #0                      ; Blocking mode?
        beq     @wait_key
        sec
        rts

; Puts a single character on channel.
; channel = channel (0..7), A = ASCII character

io_put:
        cmp     #10                     ; Line feed?
        bne     @not_lf
        lda     #$8D                    ; Apple II CR
@not_lf:
        ora     #$80
        jmp     COUT

; Reads a text record (line) from console into buffer.
; Suppresses prompt, strips bit 7, NUL-terminates at CR, returns length in A.

io_read_record:
        mva     #$80, PROMPT            ; Suppress prompt character in GETLN
        jsr     GETLN                   ; Apple II ROM GETLN reads into buffer ($0200), length in X
        lda     #0
        sta     buffer,x                ; Replace CR with NUL
        txa                             ; Save length in A
        pha
@loop:
        dex
        bmi     @done
        lda     buffer,x
        and     #$7F                    ; Strip high bit
        sta     buffer,x
        bpl     @loop                   ; Unconditional
@done:
        pla                             ; Restore length in A
        clc
        rts

; Emits record delimiter (newline).

io_end_record = CROUT

; Emits field separator (tabs to next 16-column boundary).

io_end_field:
:       lda     #' ' | $80
        jsr     COUT
        lda     $24                     ; Cursor horizontal position CH
        and     #$0F                    ; 16-column tab zones
        bne     :-
        clc
        rts

; Prints filename from S0 to COUT (with high bit set).

print_s0_cout:
        ldy     #0
        lda     (BC),y                  ; Length byte
        jmp     print_s0

; Prints NUL-terminated string to COUT.

print_string_cout:
        stax    src_ptr
@loop:
        ldy     #0
        lda     (src_ptr),y
        beq     @done
        jsr     io_put
        inc     src_ptr
        bne     @loop
        inc     src_ptr+1
        bne     @loop
@done:
        rts

; Saves program memory to file via DOS CHR$(4) BSAVE.
; S0 = filename string

io_save:
        jsr     CROUT
        lda     #4 | $80                ; Ctrl-D
        jsr     COUT
        ldax    #bsave_cmd
        jsr     print_string_cout
        jsr     print_s0_cout
        ldax    #addr_cmd
        jsr     print_string_cout
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     PRBYTE
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        jsr     PRBYTE
        ldax    #len_cmd
        jsr     print_string_cout
        sec
        lda     variable_name_table_ptr
        sbc     #<(__BSS_RUN__ + __BSS_SIZE__)
        pha
        lda     variable_name_table_ptr+1
        sbc     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     PRBYTE
        pla
        jsr     PRBYTE
        jsr     CROUT
        clc
        rts

; Loads program memory from file via DOS CHR$(4) BLOAD.
; S0 = filename string

io_load:
        jsr     CROUT
        lda     #4 | $80                ; Ctrl-D
        jsr     COUT
        ldax    #bload_cmd
        jsr     print_string_cout
        jsr     print_s0_cout
        ldax    #addr_cmd
        jsr     print_string_cout
        lda     #>(__BSS_RUN__ + __BSS_SIZE__)
        jsr     PRBYTE
        lda     #<(__BSS_RUN__ + __BSS_SIZE__)
        jsr     PRBYTE
        jsr     CROUT

        ; Validate and re-index loaded program
        ldy     #3
@check_magic:
        lda     __BSS_RUN__ + __BSS_SIZE__,y
        cmp     vbas_header,y
        bne     @format_err
        dey
        bpl     @check_magic

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

; Device-specific control operation.

io_xio:
        clc
        rts

bsave_cmd:      .asciiz "BSAVE "
bload_cmd:      .asciiz "BLOAD "
addr_cmd:       .asciiz ",A$"
len_cmd:        .asciiz ",L$"
        