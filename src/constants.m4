dnl SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
dnl
dnl SPDX-License-Identifier: MIT

ifdef(`__C__',
    `define(`def', ``#define $1 $2'') define(`hex', `0x$1') define(`comment', `//')',
    `define(`def', ``$1 = $2'') define(`hex', `$$1') define(`comment', `;')')

comment Generated from __file__

def(CASE_INSENSITIVE,   hex(80)) comment ORed with terminal token tag in DFA state data

def(TOK_EOL,            hex(00))
def(TOK_NON_TERMINAL,   hex(01)) comment Identifies intermediate DFA states
def(TOK_NUM,            hex(02))
def(TOK_OPERATOR,       hex(03))
def(TOK_NAME,           hex(04))
def(TOK_STRING,         hex(05))
def(TOK_COMMA,          hex(06))
def(TOK_SEMI,           hex(07))
def(TOK_LPAREN,         hex(08))
def(TOK_RPAREN,         hex(09))
def(TOK_NOT,            hex(0A))
def(TOK_THEN,           hex(0B))
def(TOK_TO,             hex(0C))
def(TOK_STEP,           hex(0D))

def(TOK_ANY_OP_2X,      hex(20))
def(TOK_ADD,            hex(21))
def(TOK_SUB,            hex(22))
def(TOK_MUL,            hex(23))
def(TOK_DIV,            hex(24))
def(TOK_EXP,            hex(25))
def(TOK_CONCAT,         hex(26))
def(TOK_EQ,             hex(27))
def(TOK_LT,             hex(28))
def(TOK_GT,             hex(29))
def(TOK_NE,             hex(2A))
def(TOK_LE,             hex(2B))
def(TOK_GE,             hex(2C))
def(TOK_AND,            hex(2D))
def(TOK_OR,             hex(2E))
def(TOK_ANY_OP_3X,      hex(30))

def(TOK_ANY_FN_4X,      hex(40))
def(TOK_ANY_FN_5X,      hex(50))
def(TOK_ANY_FN_6X,      hex(60))
def(TOK_ANY_FN_7X,      hex(70))

def(TOK_ANY_ST_8X,      hex(80))
def(TOK_RUN,            hex(81))
def(TOK_PRINT,          hex(82))
def(TOK_ALT_PRINT,      hex(83))
def(TOK_LET,            hex(84))
def(TOK_IMPL_LET,       hex(85))
def(TOK_LIST,           hex(86))
def(TOK_GOTO,           hex(87))
def(TOK_IMPL_GOTO,      hex(88))
def(TOK_GOSUB,          hex(89))
def(TOK_RETURN,         hex(8A))
def(TOK_POP,            hex(8B))
def(TOK_ON,             hex(8C))
def(TOK_FOR,            hex(8D))
def(TOK_NEXT,           hex(8E))
def(TOK_STOP,           hex(8F))
def(TOK_ANY_ST_9X,      hex(90))
def(TOK_CONT,           hex(91))
def(TOK_NEW,            hex(92))
def(TOK_CLR,            hex(93))
def(TOK_DIM,            hex(94))
def(TOK_REM,            hex(95))
def(TOK_DATA,           hex(96))
def(TOK_READ,           hex(97))
def(TOK_RESTORE,        hex(98))
def(TOK_POKE,           hex(99))
def(TOK_DPOKE,          hex(9A))
def(TOK_END,            hex(9B))
def(TOK_INPUT,          hex(9C))
def(TOK_IF,             hex(9D))
def(TOK_ANY_ST_AX,      hex(A0))
def(TOK_ANY_ST_BX,      hex(B0))

comment Tokenized form constants

def(TOKEN_FUNCTION,     hex(01)) comment Function sentinel
def(TOKEN_UNARY_OP,     hex(04)) comment OR with OP_UNARY_*
def(TOKEN_CLAUSE,       hex(08)) comment OR with CLAUSE_*
def(TOKEN_OP,           hex(10)) comment OR with OP_*
def(TOKEN_EXTENSION,    hex(80)) comment OR with index of extension statement

comment Statement tokens

def(ST_LET,             0)
def(ST_IMPL_LET,        1)
def(ST_RUN,             2)
def(ST_PRINT,           3)
def(ST_ALT_PRINT,       4)
def(ST_LIST,            5)
def(ST_GOTO,            6)
def(ST_IMPL_GOTO,       7)
def(ST_GOSUB,           8)
def(ST_RETURN,          9)
def(ST_POP,            10)
def(ST_ON,             11)
def(ST_FOR,            12)
def(ST_NEXT,           13)
def(ST_STOP,           14)
def(ST_CONT,           15)
def(ST_NEW,            16)
def(ST_CLR,            17)
def(ST_DIM,            18)
def(ST_REM,            19)
def(ST_DATA,           20)
def(ST_READ,           21)
def(ST_RESTORE,        22)
def(ST_POKE,           23)
def(ST_DPOKE,          24)
def(ST_END,            25)
def(ST_INPUT,          26)
def(ST_IF_THEN,        27)


comment Binary operator tokens: combine with TOKEN_OP

def(OP_ADD,             0)
def(OP_SUB,             1)
def(OP_MUL,             2)
def(OP_DIV,             3)
def(OP_POW,             4)
def(OP_CONCAT,          5)
def(OP_EQ,              6)
def(OP_LT,              7)
def(OP_GT,              8)
def(OP_NE,              9)
def(OP_LE,             10)
def(OP_GE,             11)
def(OP_AND,            12)
def(OP_OR,             13)

comment Binary operator tokens: combine with TOKEN_UNARY_OP

def(UNARY_OP_MINUS,     0)
def(UNARY_OP_NOT,       1)

comment Non-statement extras

def(CLAUSE_THEN,        0)
def(CLAUSE_GOTO,        1)
def(CLAUSE_GOSUB,       2)
def(CLAUSE_TO,          3)
def(CLAUSE_STEP,        4)

comment Types

def(TYPE_NUMBER,        hex(00))
def(TYPE_STRING,        hex(01))
def(TYPE_CONTROL,       hex(FF)) comment Only used on stack

comment Expression precedence levels

def(PR_UNARY_OP,        hex(F0))
def(PR_POW,             hex(C0))
def(PR_MUL,             hex(A0))
def(PR_ADD,             hex(80))
def(PR_RELATIONAL,      hex(60))
def(PR_LOGICAL,         hex(40))
def(PR_CLOSE_PAREN,     hex(20))
def(PR_OPEN_PAREN,      hex(00))

comment Program states and error codes

def(PS_RUNNING,                     hex(00))
def(PS_READY,                       hex(01))

def(ERR_STOPPED,                    hex(80))
def(ERR_INTERNAL_ERROR,             hex(81))
def(ERR_OUT_OF_MEMORY,              hex(82))
def(ERR_TYPE_MISMATCH,              hex(83))
def(ERR_CONT_WITHOUT_STOP,          hex(84))
def(ERR_OUT_OF_DATA,                hex(85))
def(ERR_STACK,                      hex(86))
def(ERR_RETURN_WITHOUT_GOSUB,       hex(87))
def(ERR_NEXT_WITHOUT_FOR,           hex(88))
def(ERR_LINE_NOT_FOUND,             hex(89))
def(ERR_OUT_OF_RANGE,               hex(8A))
def(ERR_INVALID_VARIABLE,           hex(8B))
def(ERR_ALREADY_DIMENSIONED,        hex(8C))
def(ERR_LINE_TOO_LONG,              hex(8D))
def(ERR_EXPRESSION_TOO_COMPLEX,     hex(8E))
def(ERR_FORMAT_ERROR,               hex(8F))
def(ERR_ARITY_MISMATCH,             hex(90))
def(ERR_SYNTAX_ERROR,               hex(91))
def(ERR_DIVIDE_BY_ZERO,             hex(92))

comment Parse virtual machine (PVM) constants and instruction codes

def(PVM_MATCH,                      hex(00))
def(PVM_CALL,                       hex(C0))
def(PVM_JUMP,                       hex(D0))
def(PVM_BRANCH_IF,                  hex(E0))
def(PVM_RETURN,                     hex(F0))
def(PVM_FAIL,                       hex(F1))

dnl def(PVM_FAIL,                       hex(00))
dnl def(PVM_RETURN,                     hex(01))
dnl def(PVM_WS,                         hex(02))
dnl def(PVM_MATCH_RANGE,                hex(03))
dnl def(PVM_MATCH_ANY,                  hex(04))
dnl def(PVM_COMPOSE,                    hex(05))
dnl def(PVM_ARGSEP,                     hex(06))
dnl def(PVM_DISPATCH,                   hex(07))
dnl def(PVM_EMIT,                       hex(08))
dnl def(PVM_TOKENIZE,                   hex(10))
dnl def(PVM_MATCH,                      hex(20))
dnl def(PVM_CALL,                       hex(60))
dnl def(PVM_JUMP,                       hex(70))
dnl def(PVM_TRY,                        hex(80))
dnl def(PVM_ACCEPT,                     hex(C0))

comment Other constants

def(EOT, hex(80))
def(BUFFER_SIZE, 256)
def(PATTERN_OK, hex(80))
def(PATTERN_ERROR, hex(81))
def(PRIMARY_STACK_SIZE, 192)
def(OP_STACK_SIZE, 16)
def(STRING_EXTRA, 3)

comment Maximum line length we're willing to encode (leave 16 bytes at end for END statement in immediate mode
def(MAX_LINE_LENGTH, 240)

comment Function templates

def(EPILOG_PUSH_FP,     hex(10))
def(EPILOG_PUSH_INT,    hex(20))
def(EPILOG_PUSH_STRING, hex(30))
def(PROLOG_POP_FP,      hex(40))
def(PROLOG_POP_INT,     hex(80))
def(PROLOG_POP_STRING,  hex(C0))
