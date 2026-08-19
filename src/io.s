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
        cmp     #TOK_COMMA
        bne     @no_mode
        inc     line_pos
        jsr     evaluate_expression     ; Evaluates mode
        jsr     pop_int_fp0             ; Mode in A
        cmp     #1
        bcc     @range_error
        cmp     #5
        bcs     @range_error
        tsx
        sta     $101,x                  ; Replace default mode on stack
@no_mode:
        jsr     pop_string_s0           ; Pop filename into S0
        pla                             ; Mode in A
        jsr     io_open
        bcs     raise_io_error
        rts

@range_error:
        pla                             ; Clean stack
        raise   ERR_OUT_OF_RANGE

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
        bcc     @got_byte
        ldax    #$FFFF                  ; -1 in AX on EOF
        jsr     int_to_fp
        jsr     push_fp0
        jmp     assign_variable

@got_byte:
        ldx     #0                      ; Byte in A, high byte 0 in X
        jsr     int_to_fp
        jsr     push_fp0
        jmp     assign_variable

; PUT [#channel] {expression}

exec_put:
        jsr     evaluate_expression
        jsr     pop_int_fp0             ; Byte in A
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
        cmp     #TOK_COMMA
        bne     @do_xio
        inc     line_pos
        jsr     evaluate_expression     ; Arg1
        jsr     pop_int_fp0
        stax    BC
        jsr     peek_byte
        cmp     #TOK_COMMA
        bne     @do_xio
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
        jmp     string_alloc_for_copy
