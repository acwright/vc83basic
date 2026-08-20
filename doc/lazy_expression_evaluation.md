# Lazy Expression Evaluation

## Overview

The expression evaluator currently pushes every value onto the value stack immediately, including
simple values that are consumed by the very next operation. This causes unnecessary push/pop
round-trips that cost ~168 cycles each (push: ~83 cycles, pop: ~85 cycles).

This plan describes an optimization where primary expressions leave their result in FP0 (for
numbers) or S0 (for strings) and only push to the stack when the value must be preserved across
a sub-evaluation — i.e., when a binary operator requires evaluating a right operand.

## New Zero Page Variable

Add one new zero page byte:

```
; The type of the most recently evaluated expression value.
; TYPE_NUMBER (0) if the value is in FP0.
; TYPE_STRING (1) if the value is in S0 (header pointer).
expr_type: .res 1
```

This variable is set by every primary expression handler and by every operator that produces a
result. Consumers use it to determine how to handle the pending value.

## S0 as Pending String Header Pointer

In the new scheme, S0 has a dual role depending on context:

1. **After expression evaluation** (pending value): S0 holds the string *header* pointer (the
   address of the length byte). This is the same format as the 2-byte pointer stored in string
   variables and pushed onto the value stack.

2. **After `load_s0`** (ready for use): S0 holds the string *data* pointer (header + 1), and
   the length has been returned in A.

The transition from state 1 to state 2 happens by calling `load_s0` with the header address.
Since `load_s0` reads the length from BC (set from its input AY) and writes the data pointer
to S0, it is safe to call `load_s0` with S0's own value as input:

```
lday    S0              ; A = S0 low (header), Y = S0+1 high (header)
jsr     load_s0         ; S0 now holds data pointer, A = length
```

This works because `load_s0` copies AY into BC first, then reads the length from `(BC),y`
before writing the incremented address to S0.

**Important**: `string_ptr` is NOT used as the pending string pointer. `string_ptr` retains
its existing meaning: the boundary of the string heap (start of string space in memory). It
only coincidentally equals the header address of a freshly allocated string.

### `load_s0_from_s0` Helper

Add this to string.s, placed immediately before `load_s0`:

```
load_s0_from_s0:
        lda     S0
        ldy     S0+1
; fall through
load_s0:
        ldx     #S0
load_s:
        ...
```

Cost: 4 bytes (two ZP loads; the fall-through is free).

Each call site that would otherwise do `lday S0; jsr load_s0` (7 bytes) can instead do
`jsr load_s0_from_s0` (3 bytes), saving 4 bytes per site. The routine pays for itself at 2+
call sites.

Expected call sites in the new scheme:
- `exec_print` string path (converting pending S0 for printing)
- `pop_two_strings` rewrite (loading right operand)
- `op_concat` result setup
- Possibly `assign_variable` string path

With 3-4 sites, net savings: **8-12 bytes**.

## Changes Within `evaluate_expression`

### Primary Expression Handlers

Each primary handler leaves its result in FP0 or S0, and sets `expr_type`, instead of pushing
to the stack.

#### `evaluate_number` (line 88)

Currently:
```
evaluate_number:
        jsr     decode_number           ; Returns number in FP0
        jmp     push_fp0                ; Push number
```

New (shared tail — see below):
```
evaluate_number:
        jsr     decode_number           ; Returns number in FP0
set_expr_type_number:
        lda     #TYPE_NUMBER            ; (= 0)
        sta     expr_type
        rts
```

#### `evaluate_string` (line 93)

Currently:
```
evaluate_string:
        jsr     decode_string           ; Sets string_ptr (allocates new string)
        jmp     push_string
```

New:
```
evaluate_string:
        jsr     decode_string           ; Sets string_ptr (= header of new string)
        mvax    string_ptr, S0          ; S0 = header pointer
set_expr_type_string:
        lda     #TYPE_STRING
        sta     expr_type
        rts
```

#### `evaluate_variable` (line 96)

Currently copies variable data onto the stack via a generic loop. New version loads into
FP0 or S0 directly:

```
evaluate_variable:
        jsr     decode_name
evaluate_decoded_variable:
        jsr     find_or_add_variable    ; name_ptr → variable data
        lda     decode_name_type
        sta     expr_type
        bne     @string
        lday    name_ptr                ; Number: load directly into FP0
        jmp     load_fp0
@string:
        ldy     #0                      ; String: read 2-byte header pointer from variable
        lda     (name_ptr),y            ; Low byte
        sta     S0
        iny
        lda     (name_ptr),y            ; High byte
        sta     S0+1
        rts
```

The string path reads the 2-byte string header pointer from the variable's data area (at
name_ptr) into S0. This replaces the current 15-byte copy loop with ~14 bytes of targeted
code.

**Estimated size change for primary handlers: roughly neutral** (within ±5 bytes).

### Operator Dispatch (the core change)

Currently (lines 35-64), after `@dispatch` evaluates a primary (which pushes to the stack),
the code checks for an operator. In the new scheme, the primary leaves its value in FP0/S0,
and we only push when a binary operator requires preserving the left operand:

```
        jsr     @dispatch               ; Evaluate primary → FP0 or S0 (NOT pushed)
        jsr     peek_byte               ; Check if an operator follows
        and     #$F0
        cmp     #TOK_ADD
        beq     @operator
        lda     #PR_CLOSE_PAREN         ; No operator: process remaining operators
        jsr     process_operators       ; FP0/S0 cascades through
        inc     op_stack_pos            ; Pop the open paren
        plzp    DECODE_NAME_STATE, DECODE_NAME_STATE_SIZE
        rts                             ; Return with value in FP0/S0 + expr_type

@operator:
        jsr     push_pending            ; Push FP0 or S0 to stack now
        jsr     decode_byte             ; Get the operator
        ; ... (precedence lookup, process_operators, push new operator — as before)
        jmp     after_operator
```

### `push_pending` Subroutine

Pushes the pending value (FP0 or S0) onto the value stack based on `expr_type`:

```
push_pending:
        lda     expr_type
        bne     push_string_s0
        jmp     push_fp0

push_string_s0:
        jsr     stack_alloc_value
        tay
        lda     #TYPE_STRING
        sta     stack+Value::type,y
        lda     S0
        sta     stack+Value::string_value_ptr,y
        lda     S0+1
        sta     stack+Value::string_value_ptr+1,y
        rts
```

`push_string_s0` is analogous to `push_string` but pushes from S0 instead of `string_ptr`.
The existing `push_string` (which pushes from `string_ptr`) remains unchanged for callers
that still need it (INPUT, READ, function epilogs).

Cost: ~18 bytes for `push_pending` + `push_string_s0`.

### `call_binary_operator` Simplification

Currently (lines 303-312), `call_binary_operator` pops the right operand into FP0 from the
stack. In the new scheme, FP0 already has the right operand:

Currently:
```
call_binary_operator:
        phax                            ; Push operator handler address -1
        lda     #TYPE_NUMBER
        jsr     stack_free_value_with_type
        txa                             ; Original stack_pos
        pha                             ; Save on stack
        jsr     pop_fp0                 ; Second value into FP0
        pla                             ; Get stack address of first value
        ldy     #>stack
        rts                             ; JMP to operator handler
```

New:
```
call_binary_operator:
        phax                            ; Push operator handler address -1
        lda     #TYPE_NUMBER
        jsr     stack_free_value_with_type
        txa                             ; Address of left operand
        ldy     #>stack
        rts                             ; JMP to handler; FP0 already has right operand
```

**Savings: 7 bytes, ~100 cycles per binary numeric operator.**

### `call_binary_operator_push` Elimination

Currently (lines 344-346):
```
call_binary_operator_push:
        jsr     call_binary_operator
        jmp     push_fp0
```

This is eliminated. Operator handlers (`op_add`, `op_sub`, `op_mul`, `op_div`, `op_pow`)
branch to `call_binary_operator` directly instead of `call_binary_operator_push`. Results
stay in FP0 for the next iteration of `process_operators` or for the caller.

**Savings: 5 bytes.**

### Unary Operator Simplification

Currently:
```
unary_op_minus:
        jsr     pop_fp0                 ; Get value at top of stack
        jsr     fneg                    ; Negate it
        jmp     push_fp0               ; Return to stack

unary_op_not:
        jsr     pop_fp0                 ; Get value
        lda     FP0e
        bne     push_value_0
        beq     push_value_1
```

New — FP0 already has the value, leave result in FP0:
```
unary_op_minus:
        jmp     fneg                    ; Negate FP0 in place

unary_op_not:
        lda     FP0e
        bne     set_value_0             ; Nonzero → return 0
        beq     set_value_1             ; Zero → return 1
```

**Savings: ~8 bytes** (eliminate pop and push calls).

### `push_value_0` / `push_value_1` → `set_value_0` / `set_value_1`

Currently these load a value into FP0 and push it. In the new scheme, just load FP0 (no push):

Currently:
```
push_value_0:
        jsr     clear_fp0
        jmp     push_fp0
push_value_1:
        jsr     load_one_fp0
        jmp     push_fp0
```

New:
```
set_value_0:
        jmp     clear_fp0
set_value_1:
        jmp     load_one_fp0
```

**Savings: 4 bytes** (two `jmp push_fp0` eliminated, one `jmp` changed to `jmp`).

Note: `expr_type` is already TYPE_NUMBER for comparison/logical operators since both operands
are numeric (or the type was already set during the left operand's evaluation).

### Comparison Operators and Type Checking

Currently `compare_values` (line 284) checks types of both operands on the stack. In the new
scheme, the right operand's type is in `expr_type` and the left operand's type is on the stack:

```
compare_values:
        lda     expr_type               ; Type of right operand (in FP0/S0)
        ldx     stack_pos
        cmp     stack+Value::type,x     ; Type of left operand (on stack)
        beq     @match
        jmp     raise_type_mismatch
@match:
        cmp     #TYPE_STRING
        beq     compare_string_values
        lda     #>(fcmp-1)
        ldx     #<(fcmp-1)
        ; fall through to call_binary_operator
```

**Size change: roughly neutral** (±2 bytes).

### String Comparison and Concatenation

`pop_two_strings` currently pops both strings from the stack. In the new scheme, the right
operand is in S0 (header pointer) and the left operand is on the stack:

```
pop_two_strings:
        ; Right operand: S0 holds header pointer. Convert to data pointer + get length.
        jsr     load_s0_from_s0         ; S0 now holds data pointer, A = length
        sta     E                       ; Right string length in E
        lda     S0                      ; Move S0 → S1 (right operand data pointer)
        sta     S1
        lda     S0+1
        sta     S1+1
        jsr     pop_string_s0           ; Left operand from stack → S0, A = length
        sta     D                       ; Left string length in D
        rts
```

Wait — we need to move the right string to S1 before loading the left string into S0. But
we just converted S0 from header to data pointer via `load_s0_from_s0`. Now we copy S0 → S1
before popping the left operand into S0.

Actually, we can do this more efficiently. `pop_string_s0` calls `pop_string` (which returns
the header address in AY) then `jmp load_s0`. So it will overwrite S0. We need S1 set first:

```
pop_two_strings:
        jsr     load_s0_from_s0         ; Convert S0 header → data pointer, A = length
        sta     E                       ; Right string length in E
        mvax    S0, S1                  ; Copy right string data pointer to S1
        jsr     pop_string_s0           ; Left string from stack → S0, A = length
        sta     D                       ; Left string length in D
        rts
```

Hmm, but the current code puts the first (left) string in S0 and second (right) in S1. That's
used by `compare_string_values` which does `lda (S0),y` vs `cmp (S1),y` and by `op_concat`
which copies S0 first then S1. Let me check the ordering...

Current `pop_two_strings`:
```
        jsr     pop_string              ; Get the second string (right, top of stack)
        jsr     load_s1                 ; Load into S1
        sta     E                       ; Length of second string in E
        jsr     pop_string_s0           ; Get first string (left)
        sta     D                       ; Length of first string in D
```

So: right → S1 (length in E), left → S0 (length in D). The new code preserves this mapping:

```
pop_two_strings:
        jsr     load_s0_from_s0         ; S0 header → S0 data, A = right string length
        sta     E                       ; Right string length in E
        mvax    S0, S1                  ; Right string data pointer → S1
        jsr     pop_string_s0           ; Left string from stack → S0, A = length
        sta     D                       ; Left string length in D
        rts
```

The `mvax` is 4 bytes. Total: `jsr`(3) + `sta`(2) + `mvax`(4) + `jsr`(3) + `sta`(2) + `rts`(1)
= 15 bytes. Current version: `jsr`(3) + `jsr`(3) + `sta`(2) + `jsr`(3) + `sta`(2) + `rts`(1)
= 14 bytes. **Size: +1 byte.**

For `op_concat`, the result is a new string allocated via `string_alloc`. After concatenation,
set S0 to the new string's header (which IS `string_ptr` since it was just allocated):

```
op_concat:
        jsr     pop_two_strings
        ...                             ; (concat logic unchanged)
        mvax    string_ptr, S0          ; Result string header → S0
        lda     #TYPE_STRING
        sta     expr_type
        rts
```

This replaces the current `jmp push_string` tail.

### Logical Operators

Currently:
```
set_up_logical_op:
        jsr     pop_int_fp0             ; Right operand from stack
        stax    DE
        jmp     pop_int_fp0             ; Left operand from stack
```

New — FP0 already has the right operand:
```
set_up_logical_op:
        jsr     truncate_fp_to_int      ; FP0 right operand → int in AX
        stax    DE
        jsr     pop_fp0                 ; Left operand from stack → FP0
        jmp     truncate_fp_to_int      ; → int in AX
```

And `finish_logical_op` currently ends with `jmp push_int_fp0`. New:
```
finish_logical_op:
        tax
        pla
        jmp     int_to_fp               ; AX → FP0, no push
```

Note: `set_expr_type_number` should be called (or `expr_type` is already TYPE_NUMBER since both
operands of AND/OR must be numbers). Since `expr_type` was set during the left operand's
evaluation and logical operators only apply to numbers, it will already be TYPE_NUMBER. Confirm
this during implementation.

**Size change: roughly neutral** (±2 bytes).

## Changes to Callers of `evaluate_expression`

### Contract

`evaluate_expression` now returns with the result in FP0 (if `expr_type` = TYPE_NUMBER) or in
S0 as a string header pointer (if `expr_type` = TYPE_STRING). The value is NOT on the stack.

### `exec_impl_let` / `assign_variable` (dispatch.s)

Rewrite `assign_variable` to copy from FP0 or S0 directly to the variable:

```
assign_variable:
        lda     expr_type
        bne     @string
        lday    name_ptr
        jmp     store_fp0               ; FP0 directly to variable
@string:
        ldy     #0
        lda     S0                      ; Copy S0 (header pointer) to variable
        sta     (name_ptr),y
        iny
        lda     S0+1
        sta     (name_ptr),y
        rts
```

~18 bytes, vs the current ~18 bytes. **Size: neutral. Speed: saves ~168 cycles per assignment.**

### `exec_for` (control.s)

Start value: goes through `assign_variable` — covered above.

End value (line 104-109): skip `pop_fp0` since FP0 already has the value.
```
        jsr     evaluate_expression     ; End value — now in FP0
        ; jsr     pop_fp0              ; REMOVED
        lda     stack_pos
        ...
```
**Savings: 3 bytes, ~85 cycles.**

Step value (line 114-116): same. **Savings: 3 bytes, ~85 cycles.**

### `exec_if` (control.s line 199)

```
        jsr     evaluate_expression     ; Result in FP0
        inc     line_pos
        ; jsr     pop_fp0              ; REMOVED
        lda     FP0e                    ; Already in FP0
```
**Savings: 3 bytes, ~85 cycles.**

### `exec_on_goto_gosub` (control.s line 32)

```
        jsr     evaluate_expression     ; Result in FP0
        jsr     decode_byte
        ...
        ; jsr     pop_int_fp0          ; REMOVED
        jsr     truncate_fp_to_int      ; FP0 → int in AX (skip pop)
```
**Savings: ~0 bytes** (pop_int_fp0 = pop_fp0 + truncate; replace with just truncate, but
pop_int_fp0 is a `jsr pop_fp0 / jmp truncate` so the save is 3 bytes for the pop_fp0 call,
minus nothing).

Actually: `pop_int_fp0` is defined as `jsr pop_fp0; jmp truncate_fp_to_int`. So the caller
currently does `jsr pop_int_fp0` (3 bytes). New: `jsr truncate_fp_to_int` (3 bytes).
**Size: neutral. Speed: saves ~85 cycles.**

### `exec_print` (print.s)

Currently checks type on the stack. New version uses `expr_type`:

```
exec_print_number:
        ; jsr     pop_fp0              ; REMOVED — FP0 already loaded
        jsr     print_number
exec_print:
        jsr     peek_byte
        beq     @newline
@continue:
        cmp     #TOK_SEMI
        beq     @empty_space
        cmp     #TOK_COMMA
        beq     @tab
        jsr     evaluate_expression     ; Result in FP0 or S0
        lda     expr_type
        beq     exec_print_number       ; TYPE_NUMBER
        lday    string_ptr              ; *** See note below
        jsr     print_string            ; (calls load_s0 internally)
        jmp     exec_print
```

**Note on printing strings**: `print_string` takes the string header address in AY and calls
`load_s0`. We need to pass the header address, which is in S0. So:

```
        jsr     load_s0_from_s0         ; Convert S0 header → data, A = length
        ; ... but print_string calls load_s0 again, which would be redundant.
```

Better: just pass S0's value to `print_string`:
```
        lday    S0                      ; Header pointer
        jsr     print_string            ; print_string calls load_s0 (safe, idempotent)
        jmp     exec_print
```

Or use `load_s0_from_s0` and then call the print logic directly:
```
        jsr     load_s0_from_s0         ; S0 = data pointer, A = length
        tay                             ; Length into Y for write
        clc
        adc     print_column
        sta     print_column
        ldax    S0
        jsr     write
        jmp     exec_print
```

But inlining `print_string` wastes code space. Passing `lday S0; jsr print_string` is simpler
(7 bytes). Or use `jsr load_s0_from_s0; ...` but then print_string would re-load S0.

Simplest approach: `lday S0; jsr print_string`. The double `load_s0` (once here implicitly,
once inside `print_string`) is wasteful at runtime but correct and saves code space.

**Savings: 3 bytes** (remove `pop_fp0` from `exec_print_number`, change type check from
stack-based to `expr_type`-based). **Speed: ~85 cycles** per PRINT expression.

### `evaluate_argument_list` (expression.s)

Add `jsr push_pending` after each `evaluate_expression`:

```
evaluate_argument_list:
        pha
        jsr     peek_byte
        cmp     #TOK_RPAREN
        beq     @done
@loop:
        jsr     evaluate_expression
        jsr     push_pending            ; Push result onto the stack
        tsx
        dec     $101,x
        jsr     peek_byte
        cmp     #TOK_COMMA
        bne     @done
        inc     line_pos
        jmp     @loop
@done:
        pla
        rts
```

**Cost: +3 bytes** (the `jsr push_pending`).

### INPUT and READ (input.s, read.s)

These parse values and call `push_fp0`/`push_string` before `assign_variable`. With the new
`assign_variable` that reads from FP0/S0 directly:

INPUT numbers (input.s line 38): replace `jsr push_fp0` with `stz expr_type` (or
`lda #0; sta expr_type` on 6502). **Size: +1 byte (6502) or –1 byte (65C02).**

INPUT strings (input.s line 60): replace `jsr push_string` with
`mvax string_ptr, S0; lda #TYPE_STRING; sta expr_type`. **Size: +4 bytes.**

Similarly for READ (read.s lines 51, 69). **Size: +5 bytes per site × 2 = +10 bytes.**

### Function Prologs and Epilogs (dispatch.s)

The dispatch system uses a prolog/epilog mechanism. Prologs pop from the stack (e.g.,
`pop_fp0`, `pop_string_s0`). Epilogs push results back (`push_fp0`, `push_string`).

Since `evaluate_argument_list` now calls `push_pending` for every argument, the prolog/epilog
system continues to work unchanged — arguments are on the stack when the prolog runs, and
epilog results are pushed for the caller.

**However**, function epilogs push results to the stack, but the new `evaluate_expression`
contract expects the result in FP0/S0 (not on stack). The epilog runs *within*
`evaluate_expression` — it's called from `dispatch_function` which is called from `@dispatch`.
The flow is:

1. `@dispatch` calls `dispatch_function`
2. `dispatch_function` sets up epilog → handler → prolog chain, then calls
   `evaluate_argument_list`
3. After `evaluate_argument_list` pushes args, the prolog pops the arg, handler runs,
   epilog pushes the result
4. Control returns to `@dispatch`, which returns to `evaluate_expression`

At step 4, the result is on the stack (pushed by epilog). But `evaluate_expression` now
expects results in FP0/S0. So the epilog needs to change: instead of pushing to the stack,
it should leave the result in FP0/S0 and set `expr_type`.

The epilog vectors (dispatch.s line 102-105) currently point to:
- `push_fp0-1`
- `push_int_fp0-1`
- `push_string-1`

Change to routines that set FP0/S0 + `expr_type` instead of pushing:

For `push_fp0` epilog: FP0 already has the result. Just set `expr_type = TYPE_NUMBER`. Use
`set_expr_type_number` (defined in the primary handler section).

For `push_int_fp0` epilog: `int_to_fp` converts AX → FP0. Then set `expr_type = TYPE_NUMBER`.
Define `epilog_push_int_fp0: jsr int_to_fp; jmp set_expr_type_number`.

For `push_string` epilog: `string_ptr` has the newly allocated string. Copy to S0 and set
`expr_type = TYPE_STRING`. Define
`epilog_push_string: mvax string_ptr, S0; jmp set_expr_type_string`.

These epilog replacements add ~12 bytes but the originals are no longer needed as epilogs
(they still exist for other callers).

Wait — the existing `push_fp0`, `push_int_fp0`, and `push_string` routines are still called
from other places (INPUT, READ, `push_pending`, `evaluate_argument_list`'s `push_pending`).
They remain. The epilog vectors just point to new, smaller routines. Net cost: ~12 bytes.

## String GC Safety

The string garbage collector scans variables, arrays, and the value stack for string references
(string.s `for_all_referenced_strings`). In the new scheme, a string value may be pending in S0
rather than on the stack.

### When Can GC Trigger While S0 Holds a Pending String?

GC triggers during `string_alloc_memory` → `compact`. This happens during any string
allocation. The dangerous scenario is:

1. A string expression is evaluated, leaving the result in S0 (not on stack)
2. Before S0 is consumed, another operation triggers string allocation (and thus GC)
3. GC doesn't find the S0 string referenced anywhere, so it collects it

Example: `CHR$(65) & "hello"`
1. `CHR$(65)` allocates "A", S0 = header of "A"
2. `&` operator: push S0 → "A" on stack (safe)
3. `"hello"` allocates string, S0 = header of "hello"
4. `op_concat`: must allocate result string. GC triggers. "hello" is in S0 but NOT on the
   stack and NOT in any variable. If the string heap is full enough to trigger compaction,
   "hello" could be relocated but S0 wouldn't be updated, or worse, collected.

Actually, wait: step 3 is `decode_string` which allocates the "hello" string. At this point
the earlier "A" is already pushed to the stack (step 2). Then `op_concat` runs — the right
operand "hello" is in S0, the left operand "A" is on the stack. `op_concat` calls
`string_alloc_for_copy` which might trigger GC. At that point, "hello" is referenced only by
S0.

### Solution: Mark S0's String During GC

Add S0 scanning to `for_all_referenced_strings`, after the stack scan section. S0 is a 2-byte
ZP location containing a string header pointer — exactly the format that
`load_src_ptr_handle_string` expects when name_ptr points to it:

```
@stack_done:
        plsta   stack_pos               ; Restore stack_pos

        ; Mark the pending string in S0 (if any)
        lda     expr_type
        beq     @no_pending             ; TYPE_NUMBER — no string to mark
        lda     #S0                     ; S0's ZP address
        sta     name_ptr
        lda     #0                      ; High byte is 0 (zero page)
        sta     name_ptr+1
        jsr     load_src_ptr_handle_string
@no_pending:
        rts
```

Cost: **~14 bytes**. This ensures that the string referenced by S0 is always marked as
referenced during GC, preventing it from being collected or relocated without updating S0.

Note: During GC phase 4 (`phase_4_update_string`), the string pointer stored at name_ptr is
updated in place. Since name_ptr points to S0, this means S0 itself will be updated to reflect
the string's new location after compaction. This is exactly what we want.

## Summary of Code Size Impact

| Change | Bytes |
|---|---|
| New ZP variable `expr_type` | +1 (ZP, not code) |
| `load_s0_from_s0` (string.s) | +4 |
| `push_pending` + `push_string_s0` | +18 |
| Primary handlers (set expr_type instead of push) | ~0 |
| `call_binary_operator` simplification | –7 |
| `call_binary_operator_push` elimination | –5 |
| Unary operator simplification | –8 |
| `set_value_0` / `set_value_1` (no push) | –4 |
| `compare_values` rewrite | ~0 |
| `pop_two_strings` rewrite | +1 |
| `op_concat` result setup | ~0 |
| `assign_variable` rewrite | ~0 |
| Caller changes (IF, FOR ×2, PRINT, ON) | –12 |
| `evaluate_argument_list` (add push_pending) | +3 |
| Function epilog replacements | +12 |
| INPUT/READ changes (4 sites) | +10 |
| GC S0 protection | +14 |
| `load_s0_from_s0` call site savings (×3-4 sites) | –12 |
| **Total estimate** | **+14 bytes** |

The optimization adds roughly 14 bytes of code, well within the ~196 bytes of headroom in the
apple2 binary (currently 7996 of 8192). The estimate has uncertainty of ±10 bytes depending on
implementation details and opportunities for code sharing.

## Summary of Performance Impact

| Pattern | Cycles Saved | Frequency |
|---|---|---|
| Each binary numeric operator | ~168 | Very high |
| Each unary operator | ~168 | Medium |
| Each comparison operator | ~168 | High |
| Simple assignment (`X=1`) | ~168 | Very high |
| IF statement | ~85 | High |
| FOR end/step values | ~170 | High (in loops) |
| PRINT expression | ~85 | Medium |
| ON...GOTO/GOSUB | ~85 | Low |

Estimated overall speedup: **15-25%** in typical BASIC programs. Programs heavy on arithmetic
and assignments (tight loops, calculations) will see the largest improvement.

## Implementation Order

1. Add `expr_type` to zero page.
2. Add `load_s0_from_s0` to string.s.
3. Add `push_pending` / `push_string_s0` / `set_expr_type_number` / `set_expr_type_string`.
4. Modify primary expression handlers to set FP0/S0 + `expr_type` instead of pushing.
5. Modify operator dispatch: push before operator, not in primary handler.
6. Simplify `call_binary_operator` (remove `pop_fp0`).
7. Eliminate `call_binary_operator_push`.
8. Simplify unary operators.
9. Change `push_value_0`/`push_value_1` to `set_value_0`/`set_value_1`.
10. Rewrite `compare_values` to use `expr_type`.
11. Rewrite `pop_two_strings` / string operations.
12. Update `assign_variable` to use FP0/S0 directly.
13. Update callers: `exec_if`, `exec_for`, `exec_print`, `exec_on_goto_gosub`.
14. Update `evaluate_argument_list` to call `push_pending`.
15. Update function epilog vectors.
16. Update INPUT and READ.
17. Add GC S0 protection to `for_all_referenced_strings`.
18. Run `make test && make expect_test` to verify.

Steps 1-9 form the core change and should be done together. Steps 10-17 are incremental
improvements that can be done one at a time with testing between each.
