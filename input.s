.include "macros.inc"
.include "basic.inc"

; INPUT statement:

.assert TYPE_NUM = 0, error

exec_input:
        lda     #'?'                    ; Prepare to print '?' prompt
        jsr     putch
        jsr     readline
        mva     #0, buffer_pos          ; Reset the read position
@next_var:
        jsr     decode_name             ; Read the variable name
        jsr     find_or_add_variable
        bcs     @done
        mvax    name_ptr, variable_ptr  ; Set up target for assign_variable
        mva     name_type, variable_type
        bne     @string
        ldax    #buffer                 ; Point to buffer
        ldy     buffer_pos              ; Starting at buffer_pos
        jsr     string_to_fp            ; Parse the number
        bcs     @done                   ; Failed to read a number
        sty     buffer_pos              ; Update buffer_pos
        jsr     push_fp0                ; Push FP0 onto the value stack

@assign:
        jsr     assign_variable         ; Store the value
        ldy     line_pos                ; Peek at the next byte
        lda     (line_ptr),y
        clc                             ; Clear carry in case we're done            
        beq     @done                   ; It was TOKEN_NO_VALUE, nothing more to read
        jsr     parse_argument_separator    ; We read something from ths line so need a ',' to continue
        bcc     exec_input              ; Didn't find ',' so issue a new prompt
        bcs     @next_var               ; Otherwise just read the next variable
@done:
        rts

@string:
        lda     #0                      ; Allocate 0-byte string
        jsr     string_alloc            ; Don't care about the address of this string
        bcs     @done
        lda     #255                    ; Allocate second 255-byte string
        jsr     string_alloc
        bcs     @done
        stax    dst_ptr                 ; Write the string here
        mva     #0, di                  ; Length byte at index 0
        mvax    #buffer, src_ptr        ; Read from buffer
        mva     buffer_pos, si
        jsr     read_string
        bcs     @done
        mva     si, buffer_pos          ; Update buffer_pos to move past string
        lda     di                      ; Add di + 3 to dst_ptr and store in BC
        ldx     #0                      ; High byte of 3
        adc     #3                      ; Carry is already clear
        bne     @skip_inx               ; No carry
        inx
@skip_inx:
        clc
        adc     dst_ptr
        sta     B
        txa
        adc     dst_ptr+1
        sta     C
        sec
        lda     #255                    ; Calculate length of unused remainder string
        sbc     di
        ldy     #0                      ; Length byte
        sta     (BC),y                  ; Update length byte
        ldax    dst_ptr                 ; Address of the string we just read
        jsr     push_string             ; Push it onto stack
        jmp     @assign