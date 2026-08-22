; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; PRINT statement:

.assert TYPE_NUMBER = $00, error

exec_print:
@loop:
        jsr     peek_byte               ; Peek at next character
        beq     @newline                ; Found 0
@continue:
        cmp     #TOK_SEMI
        beq     @empty_space
        cmp     #TOK_COMMA
        beq     @tab
        jsr     evaluate_expression     ; Leaves value in FP0 or S0, type in A
        beq     @print_num
        lday    S0
        jsr     print_string
        beq     @loop                   ; Unconditional: Z=1 from print_s0

@print_num:
        jsr     print_number            ; Print the number (already in FP0)
        beq     @loop                   ; Unconditional: Z=1 from print_s0

@tab:
        jsr     io_end_field
@empty_space:
        inc     line_pos                ; Skip over the empty space or tab token
        jsr     peek_byte               ; Peek at next character
        bne     @continue               ; It's not the end of the PRINT so continue
        rts
        
@newline:
        jmp     io_end_record

; Prints the value in FP0 to standard output.

print_number:
        mva     #1, buffer_pos          ; Start printing at buffer column 1
        jsr     fp_to_string            ; Format into buffer
        ldx     buffer_pos              ; Load length (including the length byte)
        dex                             ; Length is one less than buffer_pos
        stx     buffer                  ; Store the length in the first character of buffer; it is now a string
        lday    #buffer                 ; Load the address in AY and fall through to print_string

; Prints the string pointed to by AY to standard output.

print_string:
        jsr     load_s0                 ; Get string address into S0 and length into A
print_s0:
        sta     B                       ; Save length in B
        beq     @done
@loop:
        ldy     #0
        lda     (S0),y                  ; Load next character
        jsr     io_put
        inc     S0                      ; Advance S0 pointer
        bne     @no_inc
        inc     S0+1
@no_inc:
        dec     B
        bne     @loop
@done:
        rts
