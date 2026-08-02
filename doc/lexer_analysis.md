# Lexer Analysis

## Size Breakdown

### New Lexer ([lexer.s](file:///Users/wboyce/git/vc83basic/src/lexer.s))

| Component | Bytes | Notes |
|---|---|---|
| `next_token` code | ~115 | Lines 109–207, the DFA driver + operator/keyword replacement |
| `name` / `name_table_entry` macros | 0 | Macro definitions only |
| Operator name table | ~37 | 15 entries (EOL through OR) + end marker |
| Keyword name table | ~167 | 32 entries (AND through THEN) + end marker |
| **Subtotal lexer.s** | **~319** | |

### Lexer Data ([lexer_data.inc](file:///Users/wboyce/git/vc83basic/src/lexer_data.inc))

| Component | Bytes | Notes |
|---|---|---|
| 22 state tables | 203 | 2 header bytes + 3 bytes per transition × 53 total transitions |
| `state_table_low` | 22 | |
| `state_table_high` | 22 | |
| **Subtotal lexer_data.inc** | **247** | |

### Total new lexer: **~566 bytes**

Plus it calls `find_name` from [name.s](file:///Users/wboyce/git/vc83basic/src/name.s), which already exists and is shared with the rest of the system.

### Existing PVM Parser ([parser.s](file:///Users/wboyce/git/vc83basic/src/parser.s))

The entire `PARSER` segment is **2,385 bytes** ($0951). It breaks down roughly as:

| Component | Bytes | Notes |
|---|---|---|
| PVM interpreter (`run_pvm`, `op_*` handlers) | ~300 | The core VM loop and opcode dispatch |
| Address calculation helpers | ~60 | `calculate_address_6`, `_12`, `add_to_pvm_program_ptr` |
| `rebase_pvm_program_ptr`, `compose_with_last_byte`, `write_to_line_buffer` | ~40 | Shared utilities |
| Opcode vectors (VEC segment) | 18 | 9 × 2-byte pointers |
| `parse_line` top-level driver | ~65 | |
| PVM grammar rules (bytecode) | ~600 | All `pvm_*` productions |
| Name tables (statement, operator, clause, function, unary) | ~560 | Keyword strings with embedded PVM bytecode |
| Statement-specific inline PVM code | ~740 | FOR, IF, INPUT, ON, etc. embedded after name table entries |
| **Total** | **~2,385** | |

The current parser does *everything*: whitespace skipping, character matching, name recognition, number parsing, string parsing, expression parsing, statement dispatch — all through one unified VM.

---

## Question 1: Can the Lexer Be Made Smaller?

### Things you're already doing well

- The DFA encoding is compact: 3 bytes per transition (min\_char, count, dest\_state) is about as tight as it gets without going to a bit-packed encoding that would need a more expensive driver.
- Reusing bit 7 of `dest_state` for the case-folding flag is clever — zero extra bytes.
- The `find_name` call for operator/keyword replacement reuses existing infrastructure.

### Potential savings

1. **Merge duplicate states.** States 9 and 17 have identical transition sets (same 5 transitions to the same destinations). State 9 is the "first letter of a name" state and state 17 is "subsequent letters." They're separate because the NFA→DFA construction doesn't notice they're equivalent. If `generate_lexer_data.py` did DFA minimization, these would merge, saving 2 + 5×3 = **17 bytes** of state data plus 2 bytes of address table. That's the biggest single win visible here. There may be other mergeable states too (11/12/19 look similar but differ in their `TOK_NUM` terminal vs non-terminal status and transition targets, so they can't merge).

2. **Eliminate the address tables (44 bytes).** Instead of a split lo/hi pointer table, you could encode state offsets directly in each transition's `dest_state` byte (as an offset from the start of the state data block). This would let you drop `state_table_low` and `state_table_high` entirely. The DFA driver would become something like:
   ```
   lda  state_data_base_low
   adc  offset      ; offset from dest_state byte
   sta  vector_ptr
   lda  state_data_base_high
   adc  #0
   sta  vector_ptr+1
   ```
   This saves **44 bytes** of data at the cost of a few bytes of code (maybe +6 bytes net). The constraint is that state offsets must fit in 7 bits (since bit 7 is the case-fold flag), limiting total state data to 128 bytes — which you exceed at 203 bytes. So this would only work if combined with state merging or if you split the case-fold flag out (which costs a byte per transition and is worse). Alternatively, you could keep 8-bit offsets and encode the case-fold flag differently (e.g., by having two ranges for `a-z`: one normal and one case-folding, distinguished by which range matched). Probably not worth the complexity.

3. **Drop the keyword name table from the lexer entirely (~167 bytes).** The lexer currently writes names as literal characters, then searches the keyword table to replace them with single-byte tokens. But the *parser* could do this instead — it already has keyword tables. If the lexer just returned `TOK_NAME` with the literal characters and let the parser resolve keywords, you'd save the keyword table. The tradeoff: every name would be stored as full characters in `line_buffer` instead of one byte, using more of the 256-byte line buffer. Whether this is acceptable depends on how close you are to the `MAX_LINE_LENGTH` limit.

4. **Small code tightening (~5-10 bytes).**
   - `@try_replace` could save a byte or two by restructuring the carry-based branch. Currently you do `cmp #TOK_OPERATOR; clc; beq @try_replace; cmp #TOK_NAME; sec; beq @try_replace` — that's 8 bytes. You could also use a jump table or bit test if the token values cooperate.
   - The `bne @dfa_loop` at line 178 is an unconditional branch (since `inx` on a non-zero X won't set Z in practice, and buffer is 256 bytes so X won't wrap). That's fine as-is.

### Realistic savings summary

| Optimization | Savings | Complexity |
|---|---|---|
| DFA minimization (merge states 9/17) | ~19 bytes | Low — change the Python generator |
| Drop keyword table from lexer | ~167 bytes | Medium — parser must resolve keywords |
| Minor code tightening | ~5-10 bytes | Low |
| **Practical total** | **~24-196 bytes** | |

---

## Question 2: Lexer + Simpler VM vs. Current PVM — Is This the Right Track?

**Short answer: yes, probably, but it depends on execution.**

### Why the current PVM is large

The PVM is a *parsing* VM, not just a lexer. It handles:
- Backtracking (TRY/ACCEPT/FAIL with savepoint frames on the 6502 stack)
- Character-level matching (MATCH, MATCH_RANGE, MATCH_ANY)
- Whitespace consumption (WS)
- Subroutine calls (CALL/RETURN with PVM return addresses on the stack)
- Tokenization (TOKENIZE + name table lookup)
- Statement dispatch (DISPATCH, COMPOSE, EMIT)

The backtracking is the expensive part. Every alternative in the grammar requires a TRY/ACCEPT pair (2 bytes each), and every TRY pushes a 4-byte savepoint frame. The bytecode for the grammar rules alone is ~600 bytes, and the interleaved statement name tables with inline PVM code add another ~1,300 bytes.

### What the lexer buys you

A proper lexer eliminates the need for character-level backtracking in the parser. Currently, when the PVM tries to parse `PRINT`, it does:
1. TRY (push savepoint)
2. Match `P`, match `R`, match `I`, match `N`, match `T` — five separate MATCH opcodes
3. TOKENIZE against the statement name table
4. ACCEPT or FAIL (pop/restore savepoint)

With a lexer, the parser instead sees a pre-tokenized stream: it reads one byte and checks if it's `TOK_PRINT`. No backtracking needed for keyword recognition at all.

### What the new parser VM needs

A non-backtracking parser for BASIC is feasible because, once you have tokens, the grammar is nearly LL(1). The main ambiguity is:
- **Statement dispatch**: read a keyword token → dispatch. This is a simple table lookup.
- **Expressions**: `primary_expression` starts with `(`, a string, a number, a unary operator, a function call, or a variable — all distinguishable by the first token.
- **LET vs. implied LET**: If the first token is a name and it's not a keyword, it's implied LET. This is LL(1) with the lexer resolving keywords.

The new VM opcodes could be something like:
- `EXPECT token` — match and consume a specific token, or fail
- `PEEK token` — test the next token without consuming
- `SWITCH` — dispatch on the current token (replacing TRY/ACCEPT chains)
- `CALL` / `RETURN` / `JUMP` — same as now
- `EMIT` — same as now

This is simpler than the current PVM because:
- No savepoint stack manipulation (no TRY/ACCEPT/FAIL)
- No character-level matching (no MATCH/MATCH_RANGE)
- No whitespace handling (the lexer already did it)
- Fewer bytecode opcodes → smaller dispatch table

### Size estimate for the new system

| Component | Estimated Bytes |
|---|---|
| Lexer code (`next_token`) | ~115 |
| Lexer DFA data | ~230 (after minimization) |
| Lexer name tables (operators + keywords) | ~204 |
| New parser VM interpreter | ~150-200 (simpler than current ~400) |
| New parser grammar bytecode | ~300-400 (vs current ~600, fewer opcodes needed) |
| Parser name tables (statements, functions, clauses) | ~500 (similar to now — these are needed regardless) |
| Opcode vectors | ~12-16 |
| **Estimated total** | **~1,500-1,650** |

vs. the current **2,385 bytes**. That's a potential savings of **~700-900 bytes**.

### Risks

1. **Double name tables.** The lexer has its own operator and keyword tables. The parser has statement, function, and clause tables. Currently the parser's `operator_name_table` and `statement_name_table` serve double duty as both name-matching and dispatch targets (the PVM code follows immediately after each name). With a separate lexer, you need the lexer tables *and* the parser dispatch tables. The key question is whether the parser dispatch tables can be more compact (e.g., just jump addresses indexed by token value rather than name strings with embedded bytecode).

2. **Statement dispatch.** Currently each statement entry in the name table has PVM bytecode embedded right after it. With a lexer, you'd use the keyword token value directly as an index into a jump table. The jump table would be compact (2 bytes per entry), but you lose the current trick of inlining the parsing code directly after the name.

3. **Expression parsing.** The current PVM encodes the expression grammar as bytecode. A new LL(1) parser could use a simpler operator-precedence or Pratt parser for expressions, which would be smaller still since it replaces bytecoded grammar rules with a tight code loop.

### Bottom line

You're on the right track. The lexer is well-designed and the DFA approach is appropriate for a 6502. The main win from having a lexer isn't just the lexer itself — it's that it enables a dramatically simpler parser that doesn't need backtracking. The current PVM is paying a heavy price in both interpreter complexity and bytecode size to do character-level backtracking that a lexer makes unnecessary.

> [!TIP]
> The single biggest code size optimization to pursue right now is DFA state minimization in `generate_lexer_data.py` — it's free in terms of runtime cost and the generator change is straightforward. After that, focus on making the new parser VM as simple as possible, potentially even a hand-coded recursive-descent parser (no VM at all) if the grammar is simple enough post-lexing.
