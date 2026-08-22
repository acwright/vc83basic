# Lazy Expression Evaluation

## Overview

The expression evaluator currently pushes every value onto the value stack immediately, including
simple values that are consumed by the very next operation. This causes unnecessary push/pop
round-trips that cost ~168 cycles each for numeric values (push: ~83 cycles for `store_fp0`,
pop: ~85 cycles for `load_fp0`).

This plan describes an optimization where primary expressions leave their result in FP0 (for
numbers) or S0 (for strings) and only push to the stack when the value must be preserved — i.e.,
when a binary operator requires holding the left operand while evaluating the right.

The main performance target is numeric values, since the FP0 pack/unpack conversions in
`store_fp0`/`load_fp0` are expensive. String pushes are cheap (just 2 bytes + type), so we push
strings whenever GC safety requires it.

## New Zero Page Variable

Add one byte:

```
; The type of the most recently evaluated expression value.
; TYPE_NUMBER (0) if the value is in FP0.
; TYPE_STRING (1) if the value is in S0 (header pointer).
expr_type: .res 1
```

### `expr_type` Lifecycle

1. Set to 0 (= TYPE_NUMBER) at the top of `@dispatch`, the primary expression dispatch point.
   This is the single entry point for all primary handlers. Since A holds the decoded token at
   this point and must not be clobbered, use Y:

   ```
   @dispatch:
           ldy     #TYPE_NUMBER            ; = 0
           sty     expr_type               ; Reset before every primary
           cmp     #TOK_LPAREN
           beq     evaluate_paren
           ...
   ```

   Y is free here (`decode_byte` sets it to the old `line_pos` but nothing uses that value
   afterward). Cost: **+4 bytes** (`ldy #0; sty expr_type`).

2. Number primaries do NOT set `expr_type` — it's already 0.

3. String primaries do `inc expr_type` (2 bytes, changes 0→1). This is cheaper than
   `lda #TYPE_STRING; sta expr_type` (4 bytes).

4. `push_pending` does NOT reset `expr_type`. The reset happens at `@dispatch` before the
   next primary.

5. Operator handlers set `expr_type` as needed:
   - `call_binary_operator` sets to TYPE_NUMBER (all arithmetic operators).
   - `compare_values` sets to TYPE_NUMBER (both numeric and string comparison results are
     numbers).
   - `op_concat` sets to TYPE_STRING.
   - `finish_logical_op` sets to TYPE_NUMBER.

## S0 as Pending String Header Pointer

S0 has a dual role depending on context:

1. **After expression evaluation** (pending value): S0 holds the string *header* pointer (the
   address of the length byte). This is the same 2-byte pointer format stored in string
   variables and on the value stack.

2. **After `load_s0`** (ready for use): S0 holds the string *data* pointer (header + 1), and
   the length has been returned in A.

The transition from state 1 to state 2 happens by calling `load_s0` with the header address.
Since `load_s0` reads the length from BC (set from its input AY before writing S0), it is
safe to call `load_s0` with S0's own value as input.

**Important**: `string_ptr` is NOT used as the pending string pointer. It retains its existing
meaning as the string heap boundary.

### `load_s0_from_s0` Helper

Add to string.s, placed immediately before `load_s0` so it falls through:

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

Cost: **+4 bytes** (two ZP loads).

Each call site that would otherwise do `lday S0; jsr load_s0` (7 bytes) can use
`jsr load_s0_from_s0` (3 bytes), saving 4 bytes per site. Break-even at 2 call sites.

### `push_string` → `push_string_s0` Unification

Restructure `push_string` so it copies `string_ptr` into S0 and falls through to a new
`push_string_s0`:

```
push_string:
        mvax    string_ptr, S0          ; Set S0 from string_ptr
; fall through
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

Cost: **+4 bytes** (`mvax string_ptr, S0` added to `push_string`; `push_string_s0` replaces
the original body which read from `string_ptr`, so it's the same size).

Benefits:
- `push_string` still works for all existing callers (INPUT, READ, function epilogs).
- `push_string` now sets S0 as a side effect, which means function epilogs that use it
  automatically leave S0 in the correct state.
- `push_string_s0` is available for `push_pending` and `op_concat` (see below).

## Changes Within `evaluate_expression`

### Primary Expression Handlers

Each primary handler leaves its result in FP0 or S0 and sets `expr_type` as needed. Number
primaries rely on the default `expr_type` = 0.

#### `evaluate_number` (line 88)

```
evaluate_number:
        jmp     decode_number           ; Returns number in FP0; expr_type already 0
```

Saves the `jmp push_fp0` (3 bytes). The `jsr decode_number; rts` can be simplified to
`jmp decode_number`. **Savings: 3 bytes.**

#### `evaluate_string` (line 92)

```
evaluate_string:
        jsr     decode_string           ; Allocates new string; sets string_ptr
        mvax    string_ptr, S0          ; S0 = string header pointer
        inc     expr_type               ; TYPE_STRING
        rts
```

Changes: `jmp push_string` (3 bytes) → `mvax` (4) + `inc` (2) + `rts` (1) = 7 bytes.
**Cost: +4 bytes.**

#### `evaluate_variable` (line 96)

```
evaluate_variable:
        jsr     decode_name
evaluate_decoded_variable:
        jsr     find_or_add_variable    ; name_ptr → variable data
        lda     decode_name_type
        beq     @number
        inc     expr_type               ; TYPE_STRING
        ldy     #0                      ; Read 2-byte header pointer from variable
        lda     (name_ptr),y
        sta     S0
        iny
        lda     (name_ptr),y
        sta     S0+1
        rts
@number:
        lday    name_ptr                ; Load directly into FP0
        jmp     load_fp0
```

The current version is 20 bytes (lines 96-115: `jsr decode_name`, `jsr find_or_add_variable`,
`jsr stack_alloc_value`, loop setup + 7-byte copy loop). The new version is ~22 bytes.
**Cost: +2 bytes.**

#### `evaluate_paren` (line 80)

Calls `evaluate_expression` recursively. The recursive call sets `expr_type` and returns with
the subexpression result in FP0/S0. No change needed — `evaluate_paren` just returns, passing
through `expr_type` and FP0/S0 to the outer evaluator.

#### Function dispatch (line 75-78)

```
        inc     line_pos                ; Skip '('
        jsr     dispatch_function       ; Epilog leaves result in FP0/S0 + sets expr_type
        inc     line_pos                ; Skip ')'
        rts
```

See "Function Epilog Changes" below.

### Operator Dispatch (the core change)

**Critical ordering**: `push_pending` goes AFTER `process_operators`, not before. The reason:
`process_operators` cascades results through FP0 — each operator takes the left operand from
the stack and the right from FP0, leaving the result in FP0 for the next operator. Only after
all higher-precedence operators have been processed do we push the result to the stack (to
preserve it while we evaluate the next primary for the new operator).

Current flow:
```
primary → push to stack → see operator → process_operators → push operator → next primary
```

New flow:
```
primary → FP0/S0 → see operator → process_operators (FP0 cascades) → push_pending → push operator → next primary
```

```
@operator:
        jsr     decode_byte
        and     #$0F
        pha
        lsr     A
        tax
        lda     operator_precedence_table,x
        jsr     process_operators       ; Higher-prec operators cascade through FP0
        jsr     push_pending            ; NOW push the result for the new operator ← NEW
        pla
        tay
        lsr     A
        tax
        tya
        ora     operator_precedence_table,x
        jmp     after_operator
```

For the "no operator" path (line 40-44): no change — `process_operators` leaves the final
result in FP0/S0, which is returned to the caller.

**Cost: +3 bytes** (`jsr push_pending`).

### `push_pending` Subroutine

```
push_pending:
        lda     expr_type
        bne     @string
        jmp     push_fp0
@string:
        jmp     push_string_s0
```

**Cost: +8 bytes.**

### `call_binary_operator` Simplification

FP0 already has the right operand. Remove `pop_fp0`:

```
call_binary_operator:
        phax                            ; Push handler address -1
        lda     #TYPE_NUMBER
        sta     expr_type               ; Result is always TYPE_NUMBER
        jsr     stack_free_value_with_type
        txa                             ; Address of left operand
        ldy     #>stack
        rts                             ; JMP to handler
```

The `sta expr_type` (2 bytes) replaces `txa; pha; jsr pop_fp0; pla` (7 bytes).
**Savings: 5 bytes.**

### `call_binary_operator_push` Elimination

Currently:
```
call_binary_operator_push:
        jsr     call_binary_operator
        jmp     push_fp0
```

Eliminated. All callers (`op_mul`, `op_div`, `op_pow`, `op_sub`, `op_add`) branch to
`call_binary_operator` directly. Results stay in FP0.

**Savings: 5 bytes.**

### Unary Operator Simplification

**Unary minus**: Replace the `unary_op_minus` wrapper with `fneg` directly in the operator
vector tables:

```
operator_vectors_l:
        ...
        .byte   <(fneg-1)               ; Was unary_op_minus
        .byte   <(unary_op_not-1)
operator_vectors_h:
        ...
        .byte   >(fneg-1)               ; Was unary_op_minus
        .byte   >(unary_op_not-1)
```

The `unary_op_minus` routine (3 lines, ~9 bytes) is eliminated entirely.
**Savings: 9 bytes.**

**Unary NOT**: Remove `pop_fp0` and use `clear_fp0`/`load_one_fp0` directly (per point 3):

```
unary_op_not:
        lda     FP0e                    ; FP0 already loaded
        bne     @false
        jmp     load_one_fp0            ; 0 → 1
@false:
        jmp     clear_fp0               ; nonzero → 0
```

**Savings: 3 bytes** (`jsr pop_fp0` eliminated).

### `push_value_0` / `push_value_1` → Direct Calls

Eliminate `push_value_0` and `push_value_1`. Replace with thin wrappers:

```
set_value_0:
        jmp     clear_fp0
set_value_1:
        jmp     load_one_fp0
```

Each is 3 bytes, vs the current 6 bytes (JSR + JMP push_fp0). Comparison operators continue
using short branches to reach them:

```
op_eq:
        jsr     compare_values
        beq     set_value_1
        bne     set_value_0
```

**Savings: 6 bytes** (two `jmp push_fp0` eliminated).

### Comparison Operators and Type Checking

`compare_values` checks types. In the new scheme, the right operand's type is in `expr_type`
and the left is on the stack:

```
compare_values:
        lda     expr_type               ; Right operand type
        ldx     stack_pos
        cmp     stack+Value::type,x     ; Left operand type
        beq     @match
        jmp     raise_type_mismatch
@match:
        lda     #TYPE_NUMBER            ; Comparison result is always a number
        sta     expr_type
        lda     stack+Value::type,x     ; Reload the type
        cmp     #TYPE_STRING
        beq     compare_string_values
        lda     #>(fcmp-1)
        ldx     #<(fcmp-1)
        ; fall through to call_binary_operator
```

Actually, `call_binary_operator` already sets `expr_type` = TYPE_NUMBER (added above). So for
the numeric path, we don't need to set it here. Only for the string comparison path (which
doesn't go through `call_binary_operator`):

```
compare_values:
        lda     expr_type               ; Right operand type
        ldx     stack_pos
        cmp     stack+Value::type,x     ; Left operand type
        beq     @match
        jmp     raise_type_mismatch
@match:
        cmp     #TYPE_STRING
        beq     @string
        lda     #>(fcmp-1)
        ldx     #<(fcmp-1)
        ; fall through to call_binary_operator (sets expr_type = TYPE_NUMBER)
@string:
        stz     expr_type               ; Result type = TYPE_NUMBER
        jmp     compare_string_values
```

The `stz expr_type` before `compare_string_values` ensures comparisons of strings produce
`expr_type` = TYPE_NUMBER.

**Size change: ~+3 bytes** (add `stz expr_type` in string path; lose the old stack-based
type check, gain the new `expr_type`-based check).

### String Comparison

`pop_two_strings` currently pops both strings from the stack. In the new scheme, the right
operand is in S0 (header) and the left is on the stack. String comparisons do not allocate,
so no GC concern:

```
pop_two_strings:
        jsr     load_s0_from_s0         ; Convert S0 header → data, A = right string length
        sta     E                       ; Right string length in E
        mvax    S0, S1                  ; Right string data → S1
        jsr     pop_string_s0           ; Left string from stack → S0, A = length
        sta     D                       ; Left string length in D
        rts
```

This preserves the current convention: left in S0 (length in D), right in S1 (length in E).
**Size change: +1 byte.**

### String Concatenation and GC Safety

`op_concat` allocates a new string, which may trigger GC. The right operand is in S0 (not on
the stack). To ensure GC safety, push the right operand to the stack first, then proceed as
the current code does:

```
op_concat:
        jsr     push_string_s0          ; Push right operand for GC safety
        jsr     pop_two_strings_current ; Pop both (uses current stack-based pop_two_strings)
        clc
        adc     E
        bcs     @out_of_range
        jsr     string_alloc_for_copy
        ldax    S0
        ldy     D
        jsr     copy_y_from
        ldax    S1
        ldy     E
        jsr     copy_y_from
        mvax    string_ptr, S0          ; Result header → S0
        lda     #TYPE_STRING
        sta     expr_type
        rts
```

Wait — with this approach, we push S0 so both operands are on the stack, then pop both via the
OLD (current) `pop_two_strings`. But `pop_two_strings` is being changed for the comparison
path (where the right operand is in S0). We need two variants, or restructure.

Simpler approach: since `op_concat` needs GC safety, it pushes the right operand first, making
both operands on the stack. Then it uses the CURRENT `pop_two_strings` behavior. We can achieve
this by keeping a `pop_two_strings_from_stack` that pops both from the stack:

```
pop_two_strings_from_stack:
        jsr     pop_string              ; Right operand → AY
        jsr     load_s1                 ; → S1, length in A
        sta     E
        jsr     pop_string_s0           ; Left operand → S0, length in A
        sta     D
        rts
```

This is the same as the current `pop_two_strings`. For comparisons, use the new version that
reads the right operand from S0. For concat, push S0 first then use the stack-based version.

Alternatively, just keep one `pop_two_strings` (the S0-based version for comparisons) and have
`op_concat` do its own setup:

```
op_concat:
        jsr     push_string_s0          ; Push right operand for GC safety
        jsr     pop_string              ; Pop right operand back → AY
        jsr     load_s1                 ; → S1, length in A
        sta     E
        jsr     pop_string_s0           ; Pop left operand → S0, length in A
        sta     D
        ; Now proceed with allocation and copy
        lda     D
        clc
        adc     E
        bcs     @out_of_range
        jsr     string_alloc_for_copy
        ...
        mvax    string_ptr, S0          ; Result header → S0
        lda     #TYPE_STRING
        sta     expr_type
        rts
```

The `push_string_s0` + `pop_string` round-trip for the right operand is a small overhead
(~30 cycles for push, ~25 cycles for pop — both just move 2 bytes + type). This is far cheaper
than the FP push/pop round-trip (~168 cycles) that we're optimizing away.

**Size change: +6 bytes** (`jsr push_string_s0` + extra setup, minus the old `jmp push_string`
tail).

### Logical Operators

FP0 already has the right operand:

```
set_up_logical_op:
        jsr     truncate_fp_to_int      ; FP0 right operand → int in AX
        stax    DE
        jsr     pop_fp0                 ; Left operand → FP0
        jmp     truncate_fp_to_int      ; → int in AX

finish_logical_op:
        tax
        pla
        stz     expr_type               ; Result is TYPE_NUMBER
        jmp     int_to_fp               ; AX → FP0 (no push)
```

`set_up_logical_op`: `jsr pop_int_fp0` (3 bytes, which is `jsr pop_fp0; jmp truncate`) becomes
`jsr truncate_fp_to_int` (3 bytes — same size but skips the pop for the right operand).
The second `jmp pop_int_fp0` becomes `jsr pop_fp0; jmp truncate_fp_to_int` (same as the
current `pop_int_fp0` body).

`finish_logical_op`: `jmp push_int_fp0` (3 bytes) becomes `stz expr_type; jmp int_to_fp`
(5 bytes). **Cost: +2 bytes.**

## Function Epilog Changes

The dispatch system (dispatch.s) uses epilog vectors that currently push results onto the stack.
In the new scheme, function results must be left in FP0/S0 with `expr_type` set.

The current epilog vectors point to `push_fp0-1`, `push_int_fp0-1`, `push_string-1`. Replace
with new routines:

```
epilog_set_fp0:
        rts                             ; FP0 already has the result; expr_type already 0

epilog_set_int_fp0:
        jmp     int_to_fp               ; AX → FP0; expr_type already 0

epilog_set_string:
        mvax    string_ptr, S0          ; Result header → S0
        inc     expr_type               ; TYPE_STRING
        rts
```

`epilog_set_fp0` is 1 byte (just RTS — FP0 has the result, `expr_type` is already TYPE_NUMBER
from the initial `sta expr_type` at the top of `evaluate_expression`).

`epilog_set_int_fp0` is 3 bytes (JMP).

`epilog_set_string` is 7 bytes (mvax + inc + rts).

Update `dispatch_epilogs`:
```
dispatch_epilogs:
        .word   epilog_set_fp0-1
        .word   epilog_set_int_fp0-1
        .word   epilog_set_string-1
```

The original `push_fp0`, `push_int_fp0`, and `push_string` remain for other callers (INPUT,
READ, `push_pending`). **Cost: +11 bytes** for the new epilog routines.

Note: `epilog_set_string` sets S0 from `string_ptr`, which is correct because string-producing
functions always allocate a new string (setting `string_ptr`). For the `push_string` epilog
path — we restructured `push_string` to copy `string_ptr` → S0 and fall through to
`push_string_s0`. So even if some future path uses `push_string` as an epilog, S0 is set.

Wait — we could use `push_string` AS the epilog and then pop_string the result. No, that
defeats the purpose. The epilog routines are correct as written above.

## Changes to Callers of `evaluate_expression`

### Contract

`evaluate_expression` returns with the result in FP0 (if `expr_type` = TYPE_NUMBER) or in S0
as a string header pointer (if `expr_type` = TYPE_STRING). The value is NOT on the stack.

Update the function's documentation comment from "evaluates an expression and leaves the result
on the stack" to "evaluates an expression and leaves the result in FP0 (number) or S0 (string),
with the type in expr_type."

### `assign_variable` (dispatch.s)

Key insight: `assign_variable` already uses `decode_name_type` (the target variable's type),
NOT `expr_type`. This means we can rewrite it to read from FP0/S0 based on `decode_name_type`
without requiring callers (INPUT, READ) to set `expr_type`:

```
assign_variable:
        lda     decode_name_type
        bne     @string
        lday    name_ptr
        jmp     store_fp0               ; FP0 → variable
@string:
        ldy     #0
        lda     S0                      ; S0 header pointer → variable
        sta     (name_ptr),y
        iny
        lda     S0+1
        sta     (name_ptr),y
        rts
```

The type mismatch check (`stack_free_value_with_type`) is lost here. Add an explicit check in
`exec_impl_let` (the only path where a type mismatch is possible):

```
exec_impl_let:
        jsr     decode_name
        jsr     find_or_add_variable
        inc     line_pos
        ldphaa  name_ptr
        jsr     evaluate_expression
        plstaa  name_ptr
        lda     decode_name_type        ; Check types match
        cmp     expr_type
        bne     raise_type_mismatch     ; ← NEW check
; fall through to assign_variable
```

**Size change: ~neutral.** The copy loop (~12 bytes) is replaced by the branching store (~16
bytes), but `stack_free_value_with_type` call is removed (–3 bytes) and type check added in
exec_impl_let (+4 bytes).

### `exec_for` (control.s)

Skip `pop_fp0` for the end and step values:
```
        jsr     evaluate_expression     ; End value — now in FP0
        ; jsr     pop_fp0              ; REMOVED
```
**Savings: 3 bytes × 2 = 6 bytes, ~170 cycles.**

### `exec_if` (control.s)

```
        jsr     evaluate_expression     ; Result in FP0
        inc     line_pos
        ; jsr     pop_fp0              ; REMOVED
        lda     FP0e                    ; Already in FP0
```
**Savings: 3 bytes, ~85 cycles.**

### `exec_on_goto_gosub` (control.s)

Replace `jsr pop_int_fp0` with `jsr truncate_fp_to_int` (skips the pop):
**Size: neutral, saves ~85 cycles.**

### `exec_print` (print.s)

```
exec_print_number:
        ; jsr     pop_fp0              ; REMOVED — FP0 already loaded
        jsr     print_number
exec_print:
        jsr     peek_byte
        ...
        jsr     evaluate_expression
        lda     expr_type               ; Check type (was stack-based)
        beq     exec_print_number       ; TYPE_NUMBER
        lday    S0                      ; String header pointer
        jsr     print_string            ; print_string calls load_s0 (safe/idempotent)
        jmp     exec_print
```

**Savings: 3 bytes** (remove `pop_fp0`), ~neutral for the type check change.

### `evaluate_argument_list` (expression.s)

Add `jsr push_pending` after each expression evaluation:

```
@loop:
        jsr     evaluate_expression
        jsr     push_pending            ; Push result for function prolog ← NEW
        tsx
        dec     $101,x
        ...
```

**Cost: +3 bytes.**

### INPUT and READ (input.s, read.s)

These parse values and currently call `push_fp0`/`push_string` before `assign_variable`. Since
the new `assign_variable` uses `decode_name_type` (not `expr_type`), and INPUT/READ always
parse the correct type for the target variable, we just need FP0/S0 set correctly:

**INPUT numbers** (input.s line 38): Replace `jsr push_fp0` with nothing — `string_to_fp`
already leaves the result in FP0, and `assign_variable` reads FP0 based on `decode_name_type`.
**Savings: 3 bytes.**

**INPUT strings** (input.s line 60): Replace `jsr push_string` with
`mvax string_ptr, S0` — sets S0 from the just-allocated string. `assign_variable` reads S0.
**Cost: +1 byte** (mvax=4 vs jsr=3).

**READ numbers** (read.s line 51): Replace `jsr push_fp0` with nothing. **Savings: 3 bytes.**

**READ strings** (read.s line 69): Replace `jsr push_string` with `mvax string_ptr, S0`.
**Cost: +1 byte.**

Net for INPUT/READ: **Savings: 4 bytes.**

### I/O Commands (io.s)

#### `exec_open`

Currently evaluates the filename expression (pushes to stack), then optionally evaluates a mode
expression (pushes to stack), then pops both. In the new scheme, the first expression result
must be explicitly pushed before evaluating the second:

```
exec_open:
        jsr     evaluate_expression     ; Filename → S0 + expr_type = TYPE_STRING
        jsr     push_pending            ; Push filename to stack ← NEW
        lda     #1                      ; Default mode = 1
        pha
        jsr     peek_byte
        beq     @no_mode
        inc     line_pos
        jsr     evaluate_expression     ; Mode → FP0
        jsr     truncate_fp_to_int      ; FP0 → int AX (was pop_int_fp0)
        tsx
        sta     $101,x
@no_mode:
        jsr     pop_string_s0           ; Pop filename from stack
        pla
        jsr     io_open
        bcs     raise_io_error
        rts
```

**Cost: +3 bytes** (`jsr push_pending`).

#### `exec_get`

Currently does `jsr int_to_fp; jsr push_fp0; jmp assign_variable`. Since the new
`assign_variable` reads directly from FP0 based on `decode_name_type`, the `push_fp0` is
eliminated:

```
exec_get:
        ...
        jsr     int_to_fp               ; Byte → FP0
        jmp     assign_variable         ; Reads FP0 directly (was push_fp0 + assign_variable)
```

**Savings: 3 bytes.**

#### `exec_xio`

Three sequential `evaluate_expression` → `pop_int_fp0` patterns, each consuming the result
into a variable before the next evaluation. Replace `pop_int_fp0` with `truncate_fp_to_int`:

```
exec_xio:
        jsr     evaluate_expression     ; Command → FP0
        jsr     truncate_fp_to_int      ; (was pop_int_fp0)
        sta     B
        ...
        jsr     evaluate_expression     ; Arg1 → FP0
        jsr     truncate_fp_to_int      ; (was pop_int_fp0)
        stax    BC
        ...
        jsr     evaluate_expression     ; Arg2 → FP0
        jsr     truncate_fp_to_int      ; (was pop_int_fp0)
        stax    DE
```

**Size: neutral.**

#### `exec_close`

No arguments evaluated. **No change.**

### Target Extension Callers

#### apple2_extension_lc.s

Two patterns:

1. `jsr evaluate_expression; jsr pop_int_fp0` — in `exec_color` and
   `get_hlin_vlin_arguments`. Replace `pop_int_fp0` with `truncate_fp_to_int`.
   **Size: neutral.**

2. `jsr evaluate_argument_list; jsr pop_int_fp0` — in `exec_plot`, `get_hlin_vlin_arguments`
   (additional args), `fun_scrn`. These values are on the stack (pushed by `push_pending`
   inside `evaluate_argument_list`), so `pop_int_fp0` is still correct. **No change.**

#### ac6502_extension.s

All `pop_int_fp0` calls are inside statement/function handlers that receive args via prolog or
pop additional args pushed by `evaluate_argument_list`. **No change.**

## String GC Safety

The GC does NOT scan S0. Instead, we ensure temporary strings are on the stack before any
operation that might trigger string allocation (and thus GC). This is acceptable because string
push/pop is cheap (~30 cycles round-trip, just copying 2 bytes + type byte), unlike FP push/pop
(~168 cycles with pack/unpack conversions).

### When Can GC Trigger?

Only during `string_alloc_memory` → `compact`. This happens when:
- `decode_string` allocates (evaluating a string literal)
- `string_alloc_for_copy` (string concatenation, LEFT$/RIGHT$/MID$, CHR$, STR$)
- `read_string` (INPUT, READ)

### Analysis of Each Case

**Primary handlers that allocate** (`evaluate_string`): The allocation happens inside
`decode_string`, before S0 is set. There is no pending string value in S0 during the
allocation. Safe.

**Binary operators**: When a binary operator follows a primary, `push_pending` pushes the value
to the stack BEFORE evaluating the next primary (which might allocate). Safe.

**String concatenation** (`op_concat`): The right operand is in S0 (not on stack). Allocation
happens inside `string_alloc_for_copy`. Solution: push S0 to the stack at the start of
`op_concat` before doing anything that allocates. See the `op_concat` section above.

**Function calls**: `evaluate_argument_list` calls `push_pending` for each argument, so all args
are on the stack when the function handler runs. Function handlers that allocate strings
internally are safe because their args are on the stack. Safe.

**Assignment, PRINT, IF, FOR**: These consume the value without allocating strings. Safe.

**INPUT/READ strings**: `read_string` allocates internally. There is no pending string in S0
during the allocation (S0 is set AFTER `read_string` returns). Safe.

## Summary of Code Size Impact

| Change | Bytes |
|---|---|
| New ZP variable `expr_type` | +1 (ZP, not code) |
| `@dispatch`: `ldy #0; sty expr_type` | +4 |
| `load_s0_from_s0` (string.s, falls through) | +4 |
| `push_string` restructure (add `mvax` to S0) | +4 |
| `push_pending` | +8 |
| `evaluate_number` (jmp decode_number) | –3 |
| `evaluate_string` (set S0 + inc expr_type) | +4 |
| `evaluate_variable` (direct load FP0/S0) | +2 |
| `@operator` path: `jsr push_pending` | +3 |
| `call_binary_operator` simplification | –5 |
| `call_binary_operator_push` elimination | –5 |
| Unary minus: `fneg` in vector table | –9 |
| Unary NOT: remove `pop_fp0` | –3 |
| `push_value_0/1` → `set_value_0/1` | –6 |
| `compare_values` rewrite | +3 |
| `pop_two_strings` rewrite | +1 |
| `op_concat` (push + GC safety + expr_type) | +6 |
| Logical operators (`set_up`, `finish`) | +2 |
| Function epilog routines | +11 |
| `exec_impl_let` type check | +4 |
| `assign_variable` rewrite | ~0 |
| Caller changes (IF, FOR ×2, PRINT) | –9 |
| `evaluate_argument_list` | +3 |
| INPUT/READ changes | –4 |
| `exec_open` (`jsr push_pending`) | +3 |
| `exec_get` (remove `jsr push_fp0`) | –3 |
| `exec_xio` (`pop_int_fp0` → `truncate_fp_to_int`) | 0 |
| Target extensions (`pop_int_fp0` → `truncate_fp_to_int`) | 0 |
| `load_s0_from_s0` call site savings (×3 sites) | –9 |
| **Total estimate** | **+6 bytes** |

Estimate uncertainty: ±10 bytes.

## Summary of Performance Impact

| Pattern | Cycles Saved | Frequency |
|---|---|---|
| Each binary numeric operator | ~168 | Very high |
| Each numeric comparison | ~168 | High |
| Unary minus | ~168 | Medium |
| Unary NOT | ~85 | Medium |
| Simple assignment (`X=1`) | ~168 | Very high |
| IF statement | ~85 | High |
| FOR end/step values | ~85 each | High (in loops) |
| PRINT expression | ~85 | Medium |
| ON...GOTO/GOSUB | ~85 | Low |
| INPUT/READ numbers | ~85 | Low |
| String operations | ~0 | N/A (push for GC) |

Estimated overall speedup: **15-25%** in typical BASIC programs. Programs heavy on arithmetic
and assignments (tight numeric loops, calculations) will see the largest improvement.

## Implementation Order

**Phase 1: Core infrastructure** (do together)

1. Add `expr_type` to zeropage.s. Add assert `PR_OPEN_PAREN = TYPE_NUMBER`.
2. Add `load_s0_from_s0` to string.s (before `load_s0`).
3. Restructure `push_string` → `push_string_s0` (add `mvax` + fall-through).
4. Add `push_pending` subroutine.
5. Add `set_value_0`/`set_value_1` (jmp clear_fp0 / jmp load_one_fp0).
6. Add `ldy #0; sty expr_type` at top of `@dispatch`.
7. Modify primary handlers (evaluate_number, evaluate_string, evaluate_variable).
8. Add `jsr push_pending` in `@operator` path (AFTER process_operators).
9. Simplify `call_binary_operator` (remove `pop_fp0`, add `sta expr_type`).
10. Eliminate `call_binary_operator_push`; update `op_add`..`op_pow` callers.
11. Replace `unary_op_minus` vector with `fneg`.
12. Simplify `unary_op_not`.
13. Replace `push_value_0`/`push_value_1` with `set_value_0`/`set_value_1`.
14. Update `evaluate_expression` docstring.
15. Run `make test && make expect_test`.

**Phase 2: Operator type handling**

16. Rewrite `compare_values` to use `expr_type`.
17. Rewrite `pop_two_strings` for comparison path.
18. Rewrite `op_concat` with GC push.
19. Update `finish_logical_op` / `set_up_logical_op`.
20. Run `make test && make expect_test`.

**Phase 3: Callers**

21. Rewrite `assign_variable`; add type check in `exec_impl_let`.
22. Update function epilog vectors (dispatch_epilogs).
23. Update `evaluate_argument_list`.
24. Update callers: `exec_if`, `exec_for`, `exec_print`, `exec_on_goto_gosub`.
25. Update INPUT and READ.
26. Update I/O commands: `exec_open`, `exec_get`, `exec_xio` (io.s).
27. Update target extensions: `apple2_extension_lc.s` (`exec_color`, `get_hlin_vlin_arguments`).
28. Run `make test && make expect_test`.
