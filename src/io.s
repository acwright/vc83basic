; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; I/O statements and functions

; Copies the string currently described in AY to buffer with a null terminator.

copy_s0_to_buffer_nul:
        jsr     load_s0                 ; Load string into S0, length in A
        tay
        beq     @empty
        tax                             ; Save length in X
        ldy     #0
@loop:
        lda     (S0),y
        sta     buffer,y
        iny
        dex
        bne     @loop
@empty:
        lda     #0
        sta     buffer,y
        rts

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
        sta     $101,x                  ; Replace default mode on stack with evaluated mode
@no_mode:
        jsr     pop_string
        jsr     copy_s0_to_buffer_nul
        pla                             ; Mode in A
        tay                             ; Mode in Y (1..4)
        ldax    #buffer
        jsr     io_open
        bcs     @open_error
        rts

@open_error:
        jmp     raise_io_error

@range_error:
        pla                             ; Clean stack
        raise   ERR_OUT_OF_RANGE

; CLOSE [#channel]

exec_close:
        lda     channel
        and     #$07
        tax
        jsr     io_close
        bcs     raise_io_error
        rts

; GET [#channel] {numeric_variable}

exec_get:
        inc     line_pos                ; Skip TOK_NAME
        jsr     decode_name
        jsr     find_or_add_variable
        lda     channel
        and     #$07
        tax
        lda     #0                      ; Blocking
        jsr     io_get
        bcc     @got_byte
        mvaa    #0, io_bytes
        ldax    #$FFFF                  ; -1 in AX
        jsr     int_to_fp
        jsr     push_fp0
        jmp     assign_variable

@got_byte:
        pha
        mvaa    #1, io_bytes
        pla
        ldx     #0                      ; Byte in A, high byte 0 in X
        jsr     int_to_fp
        jsr     push_fp0
        jmp     assign_variable

; PUT [#channel] {expression}

exec_put:
        jsr     evaluate_expression
        jsr     pop_int_fp0             ; Byte in A
        pha
        lda     channel
        and     #$07
        tax
        pla
        jsr     io_put
        bcs     raise_io_error
        mvaa    #1, io_bytes
        rts

; BGET [#channel] {address},{length}

exec_bget:
        jsr     evaluate_expression     ; Address -> on stack
        inc     line_pos                ; Skip comma
        jsr     evaluate_expression     ; Length -> on stack
        jsr     pop_int_fp0             ; Length in AX
        stax    DE                      ; Length in DE
        jsr     pop_int_fp0             ; Address in AX
        stax    dst_ptr
        ldax    dst_ptr
        jsr     io_read
        bcs     raise_io_error
        stax    io_bytes                ; Store actual bytes read
        rts

raise_io_error:
        raise   ERR_IO_ERROR

; BPUT [#channel] {address},{length}

exec_bput:
        jsr     evaluate_expression     ; Address -> on stack
        inc     line_pos                ; Skip comma
        jsr     evaluate_expression     ; Length -> on stack
        jsr     pop_int_fp0             ; Length in AX
        stax    DE                      ; Length in DE
        jsr     pop_int_fp0             ; Address in AX
        stax    src_ptr
        ldax    src_ptr
        jsr     io_write
        bcs     raise_io_error
        stax    io_bytes                ; Store actual bytes written
        rts

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
        lda     channel
        and     #$07
        tax
        lda     B                       ; Command in A
        jsr     io_xio
        bcs     raise_io_error
        rts

; SAVE {name} and LOAD {name}

vbas_header:
        .byte   "VBAS"
VBAS_HEADER_LEN = 4

exec_save:
        mva     #7, channel             ; Save uses Channel 7
        jsr     evaluate_expression     ; Filename
        jsr     pop_string
        jsr     copy_s0_to_buffer_nul
        ldy     #2                      ; Mode 2 (Write)
        ldax    #buffer
        jsr     io_open
        bcs     @error_close

        ; Write "VBAS" header
        mva     #0, DE+1
        mva     #VBAS_HEADER_LEN, DE
        ldax    #vbas_header
        jsr     io_write
        bcs     @error_close

        ; Calculate program size = variable_name_table_ptr - program_ptr
        sec
        lda     variable_name_table_ptr
        sbc     program_ptr
        sta     DE
        lda     variable_name_table_ptr+1
        sbc     program_ptr+1
        sta     DE+1

        ; Write program memory
        ldax    program_ptr
        jsr     io_write
        bcs     @error_close

        jsr     io_close
        rts

@error_close:
        jsr     io_close
        jmp     raise_io_error

exec_load:
        ldy     #Line::next_line_offset
        lda     (program_ptr),y
        raine   ERR_ALREADY_DIMENSIONED ; Program exists: user must do NEW first!

        mva     #7, channel             ; Load uses Channel 7
        jsr     evaluate_expression     ; Filename
        jsr     pop_string
        jsr     copy_s0_to_buffer_nul
        ldy     #1                      ; Mode 1 (Read)
        ldax    #buffer
        jsr     io_open
        bcs     @error_close

        ; Read 4-byte header into buffer
        mva     #0, DE+1
        mva     #VBAS_HEADER_LEN, DE
        ldax    #buffer
        jsr     io_read
        bcs     @error_close
        cpx     #0
        bne     @format_close
        cmp     #VBAS_HEADER_LEN
        bne     @format_close

        ; Check "VBAS" header
        ldy     #3
@check_hdr:
        lda     buffer,y
        cmp     vbas_header,y
        bne     @format_close
        dey
        bpl     @check_hdr

        ; Calculate max size = himem_ptr - program_ptr
        sec
        lda     himem_ptr
        sbc     program_ptr
        sta     DE
        lda     himem_ptr+1
        sbc     program_ptr+1
        sta     DE+1

        ; Read program data into program_ptr
        ldx     #7
        ldax    program_ptr
        jsr     io_read
        bcs     @error_close

        ; Check that at least null line was read (.sizeof(Line) = 3)
        cpx     #0
        bne     @len_ok
        cmp     #.sizeof(Line)
        bcc     @format_close
@len_ok:
        ; variable_name_table_ptr = program_ptr + bytes_read (in AX)
        clc
        adc     program_ptr
        sta     variable_name_table_ptr
        txa
        adc     program_ptr+1
        sta     variable_name_table_ptr+1

        jsr     io_close
        jsr     clear_variables
        jsr     reset_program
        rts

@format_close:
        jsr     io_close
        raise   ERR_FORMAT_ERROR

@error_close:
        jsr     io_close
        jmp     raise_io_error

; INKEY$() function

fun_inkey_s:
        ldx     #0                      ; Channel 0 (console)
        lda     #1                      ; Non-blocking
        jsr     io_get
        bcs     @no_key
        pha                             ; Save character
        mvaa    #1, io_bytes
        lda     #1
        jsr     string_alloc_for_copy
        pla
        ldy     #0
        sta     (dst_ptr),y
        rts

@no_key:
        mvaa    #0, io_bytes
        lda     #0
        jmp     string_alloc_for_copy

; COUNT() function

fun_count:
        ldax    io_bytes
        rts
