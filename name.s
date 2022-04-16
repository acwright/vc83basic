; cc65 runtime
.include "zeropage.inc"

.include "target.inc"
.include "basic.inc"

.zeropage

name_ptr: .res 2

.code

; Matches the input against names from a table.
; Each name table entry consists of a name, which is a sequence of character bytes in the range $20-$5F,
; followed by any number of extra data bytes. The last byte of the name table entry must have bit 7 set.
; name_ptr = pointer to the first entry of the name table
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On match, returns the number of the matched name in A and the next position in the name table
; after the matched name in Y.
; If no match, then name_ptr points to the 0 at the end of the name table.

find_name:

@index = tmp1

        lda     #0              ; Name table index
        sta     @index      
@compare_name:
        ldy     #0              ; Y is the read position in the name table entry
        lda     (name_ptr),y    ; Get name character
        beq     @error          ; If it's 0 then out of names to match
        jsr     match_character_sequence
        bcc     @match
        jsr     advance_y_next_name     ; No match, move to next entry
        inc     @index          ; Increment name table index
        jmp     @compare_name

@match:
        clc                     ; Signal success
        lda     @index          ; Return number of matched name in A
        rts

@error:
        sec                     ; Signal failure
        rts

; Skips to the start of the next name in the name table. Sets name_ptr to the start of that name.
; name_ptr = the start of the current name
; Y = the read position in the name table entry

advance_y_next_name:
        lda     (name_ptr),y    ; Load current position
        tax                     ; Temporarily park in X
        iny                     ; Advance past
        txa                     ; Get the loaded character back to check bit 7
        bpl     advance_y_next_name     ; Keep searching if bit 7 not set
        tya                     ; Y is now the offset of the next rule
        clc                     ; Add to name_ptr to get updated name_ptr
        adc     name_ptr      
        sta     name_ptr
        bcc     @return         ; Don't have to increment high byte
        inc     name_ptr+1
@return:
        rts


; Matches a character sequence from the name table with characters from buffer.
; name_ptr = pointer to the current name table entry
; Y = the current read position in the name table entry
; r = read position in buffer (updated on success)
; Returns carry clear if the name matched and carry set if it didn't match any name.
; On success, Y will point to the next byte past the matched word, or will point to the first unmatched
; character on failure.

match_character_sequence:
        ldx     r               ; Load read position into X
@compare_byte:
        lda     (name_ptr),y    ; Get name character
        and     #$60            ; Check if it's a string literal character
        beq     @match          ; If not, then we've reached the end of the string and have a match
        lda     (name_ptr),y    ; Reload the character from name table
        pha                     ; Save it to check for end bit later
        and     #$7F            ; Clear bit 7, if it's set
        cmp     buffer,x        ; Compare with character from buffer
        bne     @no_match       ; Doesn't match
        iny                     ; Next position
        inx
        pla                     ; Recover the name table byte
        bpl     @compare_byte   ; If bit 7 not set then continue

; We reached a character with bit 7 set, or a non-character byte, so we have a match.
; TODO: if last character was letter, make sure next one in buffer is not letter.

@match:
        stx     r               ; Update r

        clc                     ; Signal success
        rts

@no_match:
        pla                     ; Get rid of the name table type previously saved
        sec                     ; Signal failure
        rts

; Add a new name to the variable name table.

