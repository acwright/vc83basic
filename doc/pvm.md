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
| `$40-$7F` | 64 | Function names | LEN, STR$, ASC, LEFT$, SIN, COS |
| `$80-$BF` | 64 | Statement keywords | LET, PRINT, GOTO, FOR, IF, DIM |
| `$C0-$FF` | 64 | Reserved (PVM instructions) | - |

## PVM Instructions

Tokens returned from the lexer will be in the range $00-1F and $80-$FF, plus a few character literal tokens in the range $20-$3F. We can use the range $40-$7F for non-match opcodes so we an use the other values to represent matches.

| Hex Range | Bit 7 | Bit 6 | Bit 5 | Bit 4 | Bit 3 | Bit 2 | Bit 1 | Bit 0 | Opcode | Total Size | Following Bytes |
|-----------|-------|-------|-------|-------|-------|-------|-------|-------|--------|------------|-----------------|
| `$00-$BF`  | t | t | t | t | t | t | t | t | MATCH | 1 | - |
| `$C0-$CF`  | 1 | 1 | 0 | 0 | h | h | h | h | CALL | 2 | `llllllll` |
| `$D0-$DF`  | 1 | 1 | 0 | 1 | h | h | h | h | JUMP | 2 | `llllllll` |
| `$E0-$EF`  | 1 | 1 | 1 | 0 | h | h | h | h | BRANCH_IF | 3 | `llllllll`, `tttttttt` |
| `$F0` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 0 | FAIL | 1 | - |
| `$F1` | 1 | 1 | 1 | 1 | 0 | 0 | 0 | 1 | RETURN | 1 | - |
| `$F2` | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 0 | GUARD | 2 | `tttttttt` |
| `$F3` | 1 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | SLURP | 1 | - |

### Field Key

| Field | Meaning |
|-------|---------|
| `h` | High bits of 12-bit signed offset (sign bit = bit 3) |
| `l` | Low byte of 12-bit signed offset |
| `t` | Token to match |

### Offset Ranges

| Encoding | Bits | Range | Used By |
|----------|------|-------|---------|
| 12-bit signed | `hhhh:llllllll` | −2048 to +2047 | CALL, JUMP, BRANCH_IF |
