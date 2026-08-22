; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Gets a single byte/key from serial UART (blocking).
; Returns carry clear and byte in A if ok, carry set if error.

io_get:
        jsr     io_inkey
        bcs     io_get
        rts

; Polls for a key from serial UART without blocking.
; Returns carry clear and byte in A if available, carry set if no byte.

io_inkey:
        lda     UART_RX_LEVEL
        beq     @no_key
        lda     UART_RX_DATA
        clc
        rts
@no_key:
        sec
        rts

; Outputs a single character to serial UART.
; A = character

io_put:
        pha
@wait:
        lda     UART_TX_LEVEL
        cmp     #8
        bcs     @wait                   ; Wait if FIFO full
        pla
        sta     UART_TX_DATA
        rts

; Emits record delimiter (CR + LF).

io_end_record:
        lda     #$0D                    ; Carriage Return
        jsr     io_put
        lda     #$0A                    ; Line Feed
        jmp     io_put

; Emits field separator (tabs across zones).

io_end_field:
        ldx     #4
:       lda     #' '
        jsr     io_put
        dex
        bne     :-
        clc
        rts

; Reads a text record (line) from serial into buffer.
; NUL-terminates at EOL, returns length in A.

io_read_record:
        ldx     #0
@loop:
@wait_rx:
        lda     UART_RX_LEVEL
        beq     @wait_rx
        lda     UART_RX_DATA
        cmp     #$0D                    ; Carriage Return?
        beq     @cr
        cmp     #$08                    ; Backspace (Ctrl-H)?
        beq     @bs
        cmp     #$7F                    ; Delete?
        beq     @bs
        cmp     #$20                    ; Ignore control chars < space
        bcc     @loop
        cpx     #BUFFER_SIZE-1
        bcs     @loop

        ; Standard character
        sta     buffer,x
        jsr     io_put                  ; Echo
        inx
        jmp     @loop

@bs:
        cpx     #0
        beq     @loop                   ; Ignore backspace at start of line
        dex
        lda     #$08                    ; BS
        jsr     io_put
        lda     #' '                    ; Space
        jsr     io_put
        lda     #$08                    ; BS
        jsr     io_put
        jmp     @loop

@cr:
        lda     #0
        sta     buffer,x                ; Null-terminate
        txa                             ; Return length in A
        pha
        jsr     io_end_record           ; Echo newline
        pla
        clc
        rts

; Save/load not supported on vc83_serial.

io_save:
io_load:
        sec
        rts
