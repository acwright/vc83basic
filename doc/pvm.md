# Parser Virtual Machine (PVM) Analysis

## Overview & Architecture

The VC83 BASIC parser relies on a domain-specific **Parser Virtual Machine (PVM)** to parse ASCII input lines into tokenized executable BASIC bytecode.

## PVM Instructions

The 256-byte opcode space is partitioned by value ranges. The interpreter dispatches with a cascade of `cmp`/`bcc` checks from high to low.

| Hex Range | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 | Opcode | Total Size | Following Bytes |
|-----------|-------|-------|-------|-------|-------|-------|-------|-------|--------|------------|-----------------|
| `$00` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | FAIL | 1 | — |
| `$01` | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | RETURN | 1 | — |
| `$02` | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | WS | 1 | — |
| `$03` | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 1 | MATCH_RANGE | variable | `(count, start)* 0` |
| `$04` | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | MATCH_ANY | 1 | — |
| `$05` | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | COMPOSE | 2 | `value` |
| `$06` | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 0 | ARGSEP | 1 | — |
| `$07` | 0 | 0 | 0 | 0 | 0 | 1 | 1 | 1 | DISPATCH | 1 | — |
| `$08` | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | EMIT | 2 | `value` |
| `$09‑$0F` | 0 | 0 | 0 | 0 | — | — | — | — | *(unused)* | — | — |
| `$10‑$1F` | 0 | 0 | 0 | 1 | h | h | h | h | TOKENIZE | 3 | `llllllll` |
| `$20‑$5F` | 0 | c | c | c | c | c | c | c | MATCH | 1 | — |
| `$60‑$6F` | 0 | 1 | 1 | 0 | h | h | h | h | CALL | 3 | `llllllll` |
| `$70‑$7F` | 0 | 1 | 1 | 1 | h | h | h | h | JUMP | 3 | `llllllll` |
| `$80‑$BF` | 1 | 0 | o | o | o | o | o | o | TRY | 1 | — |
| `$C0‑$FF` | 1 | 1 | o | o | o | o | o | o | ACCEPT | 1 | — |

### Field Key

| Field | Meaning |
|-------|---------|
| `c` | ASCII character to match (the opcode byte *is* the character) |
| `h` | High bits of 12-bit signed offset (sign bit = bit 3) |
| `l` | Low byte of 12-bit signed offset |
| `o` | 6-bit signed offset (sign bit = bit 5) |

### Offset Ranges

| Encoding | Bits | Range | Used By |
|----------|------|-------|---------|
| 6-bit signed | `oooooo` | −32 to +31 | TRY, ACCEPT |
| 12-bit signed | `hhhh:llllllll` | −2048 to +2047 | CALL, JUMP, TOKENIZE |

### Notes

- **MATCH** ($20–$5F) is the most space-efficient: the opcode byte *is* the operand. Multi-character matches like `MATCH "THEN"` emit 4 consecutive single-byte MATCH opcodes (`$54 $48 $45 $4E`). This works because T, H, E, N are all in the $20–$5F ASCII range.
- **TRY/ACCEPT** use short 6-bit offsets because they typically branch nearby (within the same grammar rule). This keeps them at 1 byte each.
- **CALL/JUMP/TOKENIZE** need longer reach so they use 12-bit offsets split across 2 bytes, with the high 4 bits packed into the opcode byte.
- **Fixed opcodes** ($00–$0F) are dispatched through a vector table (`pvm_opcode_vectors`), costing 2 bytes per entry in the vector table but keeping the interpreter's dispatch cascade short.
- The vector dispatch uses `adc #pvm_opcode_vectors_offset; jmp invoke_indexed_vector`, so the opcode value directly selects the vector entry.

## New Tokens

It's useful in the parser to identify token classes, e.g., binary operators. We'll give each token class its own range.

| Range | Size | Description | Examples |
|-------|------|-------------|----------|
| `$00` | 1 | End of line | EOL |
| `$01-$1F` | 31 | Value/structural tokens | NUM, NAME, STRING, COMMA, LPAREN, RPAREN, SEMI, also NON_TERMINAL and NOT |
| `$20-$3F` | 32 | Binary operators | ADD, SUB, MUL, DIV, EXP, CONCAT, EQ, LT, GT, NE, LE, GE, AND, OR |
| `$40-$7F` | 64 | Function names | LEN, STR$, ASC, LEFT$, SIN, COS |
| `$80-$BF` | 64 | Statement keywords | LET, PRINT, GOTO, FOR, IF, DIM |
| `$C0-$FF` | 64 | Reserved (PVM instructions) | - |

## Simplified PVM Instructions

Tokens returned from the lexer will be in the range $00-1F and $80-$FF, plus a few character literal tokens in the range $20-$3F. We can use the range $40-$7F for non-match opcodes so we an use the other values to represent matches.

| Hex Range | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 | Opcode | Total Size | Following Bytes |
|-----------|-------|-------|-------|-------|-------|-------|-------|-------|--------|------------|-----------------|
| `$00-$BF`  | t | t | t | t | t | t | t | t | MATCH | 1 | - |
| `$C0-$CF`  | 1 | 1 | 0 | 0 | h | h | h | h | CALL | 2 | `llllllll` |
| `$D0-$DF`  | 1 | 1 | 0 | 1 | h | h | h | h | JUMP | 2 | `llllllll` |
| `$E0-$EF`  | 1 | 1 | 1 | 0 | h | h | h | h | BRANCH_IF | 3 | `llllllll`, `tttttttt` |
| `$F0` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | RETURN | 1 | - |
| `$F1` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | FAIL | 1 | - |

### Field Key

| Field | Meaning |
|-------|---------|
| `h` | High bits of 12-bit signed offset (sign bit = bit 3) |
| `l` | Low byte of 12-bit signed offset |
| `t` | Token to match |

### Offset Ranges

| Encoding | Bits | Range | Used By |
|----------|------|-------|---------|
| 12-bit signed | `hhhh:llllllll` | −2048 to +2047 | CALL, JUMP, BRANCH |
