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
        jsr     tab
@empty_space:
        inc     line_pos                ; Skip over the empty space or tab token
        jsr     peek_byte               ; Peek at next character
        bne     @continue               ; It's not the end of the PRINT so continue
        rts
        
@newline:
        jmp     newline

; Prints the line number of line_ptr to standard output.

print_line_number:
        jsr     line_number_to_fp       ; Convert line number in (line_ptr) to FP0 and fall through

; Prints the value in FP0 to standard output.

print_number:
        jsr     fp_to_string            ; Format into buffer (buffer[0] = length, buffer[1..] = chars)
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
        jsr     putch
        inc     S0                      ; Advance S0 pointer
        bne     @no_inc
        inc     S0+1
@no_inc:
        dec     B
        bne     @loop
@done:
        rts
