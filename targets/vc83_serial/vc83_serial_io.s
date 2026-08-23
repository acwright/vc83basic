; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Gets a single byte/key from serial UART (blocking).
; Returns carry clear and byte in A if ok, carry set if error.

getch:
        jsr     inkey
        bcs     getch
        rts

; Polls for a key from serial UART without blocking.
; Returns carry clear and byte in A if available, carry set if no byte.

inkey:
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

putch:
        pha
@wait:
        lda     UART_TX_LEVEL
        cmp     #8
        bcs     @wait                   ; Wait if FIFO full
        pla
        sta     UART_TX_DATA
        rts

; Emits record delimiter (CR + LF).

newline:
        lda     #$0D                    ; Carriage Return
        jsr     putch
        lda     #$0A                    ; Line Feed
        jmp     putch

; Emits field separator (tabs across zones).

tab:
        ldx     #4
:       lda     #' '
        jsr     putch
        dex
        bne     :-
        clc
        rts

; Reads a text record (line) from serial into buffer.
; NUL-terminates at EOL, returns length in A.

readline:
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
        jsr     putch                   ; Echo
        inx
        jmp     @loop

@bs:
        cpx     #0
        beq     @loop                   ; Ignore backspace at start of line
        dex
        lda     #$08                    ; BS
        jsr     putch
        lda     #' '                    ; Space
        jsr     putch
        lda     #$08                    ; BS
        jsr     putch
        jmp     @loop

@cr:
        lda     #0
        sta     buffer,x                ; Null-terminate
        txa                             ; Return length in A
        pha
        jsr     newline                 ; Echo newline
        pla
        clc
        rts

; Save/load not supported on vc83_serial.

save:
load:
        sec
        rts
