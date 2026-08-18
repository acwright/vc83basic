; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; cc65 runtime
.import push0, push1, pusha0, pushax

; sim65 POSIX vectors
.import _open, _close, _read, _write

.export io_open, io_close, io_close_all, io_get, io_put
.export io_read, io_write, io_readline, io_xio
.export readline, write, newline, putch
.export channel_fds

; Mode flag constants for cc65 / POSIX open()
; Mode 1 (Read):   O_RDONLY = $01
; Mode 2 (Write):  O_WRONLY | O_CREAT | O_TRUNC = $02 | $10 | $20 = $32
; Mode 3 (Update): O_RDWR | O_CREAT = $03 | $10 = $13
; Mode 4 (Append): O_WRONLY | O_CREAT | O_APPEND = $02 | $10 | $40 = $52

mode_flags_table:
        .byte   $01                     ; Mode 1: Read
        .byte   $32                     ; Mode 2: Write
        .byte   $13                     ; Mode 3: Update
        .byte   $52                     ; Mode 4: Append

.data

channel_fds:
        .byte   0, $FF, $FF, $FF, $FF, $FF, $FF, $FF   ; Ch 0 = stdin/stdout, 1..7 = closed

.bss

open_channel:     .res 1
open_mode:        .res 1
get_nonblocking:  .res 1
get_byte_buf:     .res 1
put_byte_buf:     .res 1

.code

; Opens a file on channel.
; AX = pointer to null-terminated filename
; Y = mode (1..4)
; channel = channel index (0..7)
; Returns carry clear if ok, carry set if error.

io_open:
        stax    src_ptr                 ; Save filename pointer immediately
        sty     open_mode               ; Save mode (1..4)
        lda     channel
        and     #$07
        sta     open_channel            ; Save channel index (0..7)
        tax
        lda     channel_fds,x           ; Check if already open
        cmp     #$FF
        bne     @error                  ; Already open -> fail

        ldax    src_ptr
        jsr     pushax                  ; Push filename pointer
        ldx     open_mode
        lda     mode_flags_table-1,x    ; Get open flags
        ldx     #0
        jsr     pushax                  ; Push open flags
        lda     #$FF                    ; Mode 0777 permission ($01FF)
        ldx     #$01
        jsr     pushax
        ldy     #6                      ; 3 arguments (6 bytes)
        jsr     _open                   ; Call C open()
        cpx     #$80                    ; Negative return value?
        bcs     @error
        tay                             ; Save fd in Y
        lda     channel
        and     #$07
        tax                             ; Channel index in X
        tya                             ; Restore fd in A
        sta     channel_fds,x           ; Save file descriptor
        clc
        rts

@error:
        sec
        rts

; Closes channel.
; channel = channel (0..7)
; Returns carry clear if ok, carry set if error.

io_close:
        lda     channel
        and     #$07
        tax
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @not_open
        cpx     #0                      ; Channel 0 (console) is never closed
        beq     @ok
        pha
        lda     #$FF                    ; Mark closed
        sta     channel_fds,x
        pla
        ldx     #0
        jsr     _close
@ok:
        clc
        rts

@not_open:
        sec
        rts

; Closes all open channels (1..7). Called by NEW / CLR.

io_close_all:
        lda     #1
@loop:
        pha
        tax
        lda     channel_fds,x
        cmp     #$FF
        beq     @skip
        tay                             ; Save fd in Y
        lda     #$FF
        sta     channel_fds,x
        tya                             ; Pass fd in A
        ldx     #0
        jsr     _close
@skip:
        pla
        clc
        adc     #1
        cmp     #8
        bcc     @loop
        rts

; Gets a single byte from channel.
; A = non-blocking flag: 0 = blocking, 1 = non-blocking (INKEY$)
; channel = channel (0..7)
; Returns byte in A and carry clear if ok, carry set if EOF / error.

io_get:
        cmp     #1                      ; Non-blocking requested?
        beq     @nonblock
        lda     channel
        and     #$07
        tax
        cpx     #0
        bne     @check_open
        lda     #0                      ; fd 0 (stdin)
        beq     @do_read
@check_open:
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @error
@do_read:
        ldx     #0
        jsr     pushax                  ; Push fd
        ldax    #get_byte_buf           ; Buffer = &get_byte_buf
        jsr     pushax                  ; Push buffer address
        lda     #1                      ; Length = 1
        ldx     #0
        jsr     _read                   ; Returns bytes read in AX
        cpx     #$80                    ; Error?
        bcs     @error
        cmp     #0
        bne     @got_byte
        cpx     #0
        beq     @error                  ; 0 bytes read = EOF
@got_byte:
        lda     get_byte_buf            ; Load byte read
        clc
        rts

@nonblock:
        ; On headless sim6502, non-blocking keyboard poll returns no key (carry set)
        sec
        rts

@error:
        sec
        rts

; Puts a single byte to channel.
; A = byte to put
; channel = channel (0..7)
; Returns carry clear if ok, carry set if error.

io_put:
        sta     put_byte_buf            ; Store byte in put_byte_buf
        lda     channel
        and     #$07
        tax
        cpx     #0
        beq     @stdout
        lda     channel_fds,x
        cmp     #$FF
        beq     @error
        jmp     @write_fd

@stdout:
        lda     #1                      ; fd 1 (stdout)

@write_fd:
        ldx     #0
        jsr     pushax                  ; Push fd
        ldax    #put_byte_buf           ; Buffer = &put_byte_buf
        jsr     pushax                  ; Push buffer address
        lda     #1                      ; Length = 1
        ldx     #0
        jsr     _write                  ; Call C write()
        cpx     #$80
        bcs     @error
        clc
        rts

@error:
        sec
        rts




; Binary block read into memory.
; AX = target buffer pointer (dst_ptr)
; DE = length
; Returns actual bytes read in AX and carry clear if ok, carry set on error.

io_read:
        stax    dst_ptr                 ; Save buffer pointer immediately
        lda     channel
        and     #$07
        tax
        cpx     #0
        bne     @check_open
        lda     #0                      ; fd 0 (stdin)
        bne     @do_push
@check_open:
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @read_err
@do_push:
        ldx     #0
        jsr     pushax                  ; Push fd
        ldax    dst_ptr
        jsr     pushax                  ; Push buffer pointer
        ldax    DE                      ; Length in AX
        jsr     _read                   ; Call C read()
        cpx     #$80
        bcs     @read_err
        clc
        rts
@read_err:
        sec
        rts

; Binary block write from memory.
; AX = source buffer pointer (src_ptr)
; DE = length
; Returns actual bytes written in AX and carry clear if ok, carry set on error.

io_write:
        stax    src_ptr                 ; Save buffer pointer immediately
        lda     channel
        and     #$07
        tax
        cpx     #0
        bne     @check_open
        lda     #1                      ; fd 1 (stdout)
        bne     @do_push
@check_open:
        lda     channel_fds,x           ; Get fd
        cmp     #$FF
        beq     @write_err
@do_push:
        ldx     #0
        jsr     pushax                  ; Push fd
        ldax    src_ptr
        jsr     pushax                  ; Push buffer pointer
        ldax    DE                      ; Length in AX
        jsr     _write                  ; Call C write()
        cpx     #$80
        bcs     @write_err
        clc
        rts
@write_err:
        sec
        rts

; Reads a text line from channel X into buffer and adds a terminating NUL.
; X = channel (0..7)
; Returns line length in A and carry clear if ok, carry set on EOF / error.

io_readline:
        cpx     #0
        bne     @file_channel
        ; Channel 0 (console stdin)
        jsr     push0                   ; fd 0
        lda     #<buffer
        ldx     #>buffer
        jsr     pushax
        lda     #BUFFER_SIZE-1
        ldx     #0
        jsr     _read
        cpx     #$80
        bcs     @fc_err
        tax                             ; Length in X
        lda     #0
        sta     buffer-1,x              ; Overwrite LF with NUL
        txa                             ; Return length in A
        clc
        rts

@file_channel:
        lda     channel_fds,x           ; Check if open
        cmp     #$FF
        beq     @fc_err
        txa
        pha                             ; Push channel index onto hardware stack
        lda     #0
        pha                             ; Push buffer offset (0) onto hardware stack
@read_loop:
        tsx
        lda     $102,x                  ; Channel index
        sta     channel
        lda     #0                      ; Blocking
        jsr     io_get                  ; Read 1 byte
        bcs     @eof_check
        tsx
        ldy     $101,x                  ; Buffer offset
        cmp     #$0A                    ; Line feed (LF)?
        beq     @line_done
        cmp     #$0D                    ; Carriage return (CR)?
        beq     @line_done
        sta     buffer,y
        iny
        tya
        tsx
        sta     $101,x                  ; Save updated buffer offset
        cpy     #BUFFER_SIZE-1
        bcc     @read_loop
@line_done:
        tsx
        ldy     $101,x                  ; Buffer offset
        lda     #0
        sta     buffer,y                ; Null terminate
        pla                             ; Pop buffer offset
        pla                             ; Pop channel index
        tya                             ; Return length in A
        clc
        rts

@eof_check:
        tsx
        ldy     $101,x                  ; Buffer offset
        cpy     #0
        bne     @line_done
        pla
        pla
@fc_err:
        sec
        rts

; Device-specific control operation.
; X = channel (0..7), A = command
; Returns carry clear if ok, carry set if error.

io_xio:
        clc
        rts

; --- Legacy Bridge Entry Points ---

readline:
        lda     channel
        and     #$07
        tax
        jmp     io_readline

write:
        stax    src_ptr                 ; Save buffer address immediately
        mva     #0, DE+1
        sty     DE                      ; Length in DE
        lda     channel
        and     #$07
        tax                             ; Channel in X
        ldax    src_ptr                 ; Buffer address in AX
        jmp     io_write

newline:
        lda     #$0A
        jmp     putch

putch:
        pha                             ; Save character
        lda     channel
        and     #$07
        tax                             ; Channel in X
        pla                             ; Restore character in A
        jmp     io_put
