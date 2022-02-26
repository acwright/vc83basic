; cc65 runtime
.include "zeropage.inc"

.include "basic.inc"

ready_message: .byte "READY"
ready_length = * - ready_message

error_message: .byte "ERROR"
error_length = * - error_message

keyword_list: .byte 'L', 'I', 'S', 'T'+$80
keyword_run: .byte 'R', 'U', 'N'+$80

main:
        jsr     initialize_arch
        jsr     initialize_program
ready:
        jsr     print_ready
@wait_for_input:
        jsr     readline
        ldy     #0                      ; Y will be the read pointer
        jsr     parse_number            ; Leaves line number in AX and Y points to next character in buffer
        bcs     @immediate_mode         ; Wasn't a number, maybe an immediate mode command
        jsr     insert_or_update_line   ; Delete an existing line, if it exists
        jmp     @wait_for_input

@immediate_mode:
        lda     #<keyword_list
        ldx     #>keyword_list
        jsr     parse_keyword           ; Was it "LIST"?
        bcs     @not_list
        jmp     list

@not_list:
        lda     #<keyword_run
        ldx     #>keyword_run
        jsr     parse_keyword           ; Was it "RUN"?
        bcs     @not_run
        jmp     run

@not_run:
        lda     #<error_message         ; Pass address of message in ptr1
        ldx     #>error_message
        ldy     #error_length
        jsr     write
        jsr     newline
        jmp     @wait_for_input

list:
        jsr     reset_line_ptr
@next_line:
        ldy     #1                      ; High byte of line number
        lda     (line_ptr),y
        bmi     @end                    ; If MSB of line number is set, we're at end of program
        tax
        dey
        lda     (line_ptr),y            ; Low byte of line number
        jsr     print_number
        lda     #' '
        jsr     putchar
        ldy     #2                      ; Line length
        lda     (line_ptr),y
        tay
        jsr     get_line_start          ; Puts pointer to start of line data in AX
        jsr     write
        jsr     newline
        jsr     advance_line_ptr
        jmp     @next_line

@end:
        jmp     ready

run:
        jmp     ready

; Prints the number in AX to the console.

print_number:
        sta     tmp1                    ; Start with high byte in tmp1
        lda     #0                      ; Push 0 on the stack
        pha
@next_digit:
        lda     tmp1                    ; Recover low byte from tmp1
        jsr     div10                   ; Divide AX by 10
        sta     tmp1                    ; Save low byte in tmp1
        tya                             ; Transfer remainder into A
        clc
        adc     #'0'
        pha                             ; Push digit
        txa                             ; High byte into A
        ora     tmp1                    ; OR with low byte
        bne     @next_digit             ; Still more to digits
@print_digit:
        pla                             ; Get a digit
        beq     @done                   ; If it's 0 then we're done
        jsr     putchar                 ; Print it
        jmp     @print_digit

@done:
        rts

print_ready:
        lda     #<ready_message         ; Pass address of message in ptr1
        ldx     #>ready_message
        ldy     #ready_length
        jsr     write
        jsr     newline
        rts
                                