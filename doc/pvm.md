# Parser Virtual Machine (PVM) Analysis

## Overview & Architecture

The VC83 BASIC parser relies on a domain-specific **Parser Virtual Machine (PVM)** to parse ASCII input lines into tokenized executable BASIC bytecode.

## Tokens

It's useful in the parser to identify token classes, e.g., binary operators. We'll give each token class its own range.

| Range | Size | Description | Examples |
|-------|------|-------------|----------|
| `$00` | 1 | End of line | EOL |
| `$01-$1F` | 31 | Value/structural tokens | NUM, NAME, STRING, COMMA, LPAREN, RPAREN, SEMI, also NON_TERMINAL and NOT |
| `$20-$3F` | 32 | Binary operators | ADD, SUB, MUL, DIV, EXP, CONCAT, EQ, LT, GT, NE, LE, GE, AND, OR |
| `$40-$7F` | 64 | Statement keywords | LET, PRINT, GOTO, FOR, IF, DIM |
| `$80-$BF` | 64 | Function names | LEN, STR$, ASC, LEFT$, SIN, COS |
| `$C0-$FF` | 64 | Reserved (PVM instructions) | - |

## PVM Instructions

| Hex Range | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 | Opcode | Total Size | Following Bytes |
|-----------|-------|-------|-------|-------|-------|-------|-------|-------|--------|------------|-----------------|
| `$00-$BF`  | t | t | t | t | t | t | t | t | MATCH | 1 | - |
| `$C0-$CF` | 1 | 1 | 0 | 0 | c | c | c | c | MATCH_RANGE | 2 | `mmmmmmmm` |
| `$D0-$D3`  | 1 | 1 | 0 | 1 | 0 | 0 | h | h | CALL | 2 | `llllllll` |
| `$D4-$D7`  | 1 | 1 | 0 | 1 | 0 | 1 | h | h | JUMP | 2 | `llllllll` |
| `$D8-$DB`  | 1 | 1 | 0 | 1 | 1 | 0 | h | h | BRANCH_IF | 3 / 4 | `llllllll`, `tttttttt` / `MATCH_RANGE` |
| `$F0` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | RETURN | 1 | - |
| `$F1` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | GUARD | 2 / 3 | `tttttttt` / `MATCH_RANGE` |
| `$F2` | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 0 | SLURP | 1 | - |
| `$FF` | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 | FAIL | 1 | - |

### Field Key

| Field | Meaning |
|-------|---------|
| `h` | High bits of 10-bit signed offset (sign bit = bit 1) |
| `l` | Low byte of 10-bit signed offset |
| `t` | Token to match |
| `c` | Range count minus 1 (`0..15` for count 1..16) |
| `m` | `min_token` (start of token range) |

### Offset Ranges

| Encoding | Bits | Range | Used By |
|----------|------|-------|---------|
| 10-bit signed | `hh:llllllll` | −512 to +511 | CALL, JUMP, BRANCH_IF |
