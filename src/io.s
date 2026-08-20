; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; I/O statements and functions

; OPEN [#channel] {name} [,{mode}]

exec_open:
        jsr     evaluate_expression     ; Evaluates filename -> on stack
        lda     #1                      ; Default mode = 1 (Read)
        pha
        jsr     peek_byte
        beq     @no_mode
        inc     line_pos
        jsr     evaluate_expression     ; Evaluates mode
        jsr     pop_int_fp0             ; Mode in A
        tsx
        sta     $101,x                  ; Replace default mode on stack
@no_mode:
        jsr     pop_string_s0           ; Pop filename into S0
        pla                             ; Mode in A
        jsr     io_open
        bcs     raise_io_error
        rts

; CLOSE [#channel]

exec_close:
        jsr     io_close
        bcs     raise_io_error
        rts

; GET [#channel] {numeric_variable}

exec_get:
        inc     line_pos                ; Skip TOK_NAME
        jsr     decode_name
        jsr     find_or_add_variable
        lda     #0                      ; Blocking
        jsr     io_get
        ldx     #0                      ; High byte 0
        bcc     @got_byte               ; If not EOF then byte is in A
        lda     #$FF                    ; -1 in AX on EOF ($FFFF)
        dex
@got_byte:
        jsr     int_to_fp
        jsr     push_fp0
        jmp     assign_variable

; PUT [#channel] {expression}
; PROLOG_POP_INT has already evaluated the expression and popped the byte into A!

exec_put:
        jsr     io_put
        bcs     raise_io_error
        rts

raise_io_error:
        raise   ERR_IO_ERROR

; XIO [#channel] {command}[,{arg1}[,{arg2}]]

exec_xio:
        jsr     evaluate_expression     ; Command
        jsr     pop_int_fp0
        sta     B                       ; Command in B
        lda     #0
        sta     BC                      ; Default arg1 = 0
        sta     BC+1
        sta     DE                      ; Default arg2 = 0
        sta     DE+1
        jsr     peek_byte
        beq     @do_xio
        inc     line_pos
        jsr     evaluate_expression     ; Arg1
        jsr     pop_int_fp0
        stax    BC
        jsr     peek_byte
        beq     @do_xio
        inc     line_pos
        jsr     evaluate_expression     ; Arg2
        jsr     pop_int_fp0
        stax    DE

@do_xio:
        lda     B                       ; Command in A
        jsr     io_xio
        bcs     raise_io_error
        rts

; SAVE {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_save:
        jsr     io_save
        bcs     raise_io_error
        rts

; LOAD {name}
; PROLOG_POP_STRING has already evaluated the filename and loaded S0!

exec_load:
        ldy     #Line::next_line_offset
        lda     (program_ptr),y
        raine   ERR_ALREADY_DIMENSIONED ; Program exists: user must do NEW first!

        jsr     io_load
        bcs     raise_io_error
        rts

; INKEY$() function
; EPILOG_PUSH_STRING pushes string returned in S0 / string_ptr

fun_inkey_s:
        mva     #$80, channel           ; Console channel
        lda     #1                      ; Non-blocking
        jsr     io_get
        bcs     @no_key
        pha                             ; Save character
        lda     #1
        jsr     string_alloc_for_copy
        pla
        ldy     #0
        sta     (dst_ptr),y
        rts

@no_key:
        lda     #0
        jmp     string_alloc
