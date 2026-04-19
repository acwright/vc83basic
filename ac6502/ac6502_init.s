; SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
;
; SPDX-License-Identifier: MIT

; Buffers

buffer := $400
line_buffer := $500

; Ensure that primary stack and operator stack fit together in page 6
.assert PRIMARY_STACK_SIZE + OP_STACK_SIZE = 208, error

; Primary stack
stack := $600
; Operator stack
op_stack := $600 + PRIMARY_STACK_SIZE

.segment "ONCE"     

initialize_target:        
        cli
        jmp     display_startup_banner

.code
