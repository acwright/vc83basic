/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void init_buffer(const char *s, int line) {
    fprintf(stderr, "  %s:%d: init_buffer(\"%s\")\n", __FILE__, line, s);
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
}

void call_next_token(char expect_token, const char* expect_line_data, char expect_line_data_length) {
    char token;

    token = next_token();
    ASSERT_EQ(token, expect_token);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_lexer_strings(void) {

    const char line_data_1[] = { 0 };
    const char line_data_2[] = { '"', 'H', 'E', 'L', 'L', 'O', '"', 0 };
    const char line_data_3[] = { '"', 'C', 'A', 'L', 'L', ' ', 'M', 'E', ' ', '"', '"', 
        'I', 'S', 'H', 'M', 'A', 'E', 'L', '"', '"', '"', 0 };
    const char line_data_4[] = { '"', 'O', 'N', 'E', '"', '"', 'T', 'W', 'O', '"', 0 };

    PRINT_TEST_NAME();

    init_buffer("", __LINE__);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);
    init_buffer("  ", __LINE__);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("\"HELLO\"", __LINE__);
    call_next_token('"', line_data_2, sizeof line_data_2 - 1);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);
    init_buffer("\"CALL ME \"\"ISHMAEL\"\"\"", __LINE__);
    call_next_token('"', line_data_3, sizeof line_data_3 - 1);
    call_next_token(TOK_EOL, line_data_3, sizeof line_data_3);
    init_buffer("\"ONE\" \"TWO\"", __LINE__);
    call_next_token('"', line_data_4, 5);
    call_next_token('"', line_data_4, 10);
    call_next_token(TOK_EOL, line_data_4, sizeof line_data_4);
}

void test_lexer_numbers(void) {
    const char line_data_1[] = { '0', 0 };
    const char line_data_2[] = { '1', '2', '3', 0 };
    const char line_data_5[] = { '0', '.', '5', 0 };
    const char line_data_6[] = { '.', '2', '5', 0 };
    const char line_data_8[] = { '1', '2', '3', '.', '4', '5', '6', 0 };
    const char line_data_9[] = { '1', '0', '0', '.', 0 };
    const char line_data_e1[] = { '1', 'E', '1', '0', 0 };
    const char line_data_e2[] = { '1', '.', '5', 'E', '-', '5', 0 };
    const char line_data_e4[] = { '.', '5', 'E', '3', 0 };

    PRINT_TEST_NAME();

    init_buffer("0", __LINE__);
    call_next_token(TOK_NUM, line_data_1, 1);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("123", __LINE__);
    call_next_token(TOK_NUM, line_data_2, 3);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);

    init_buffer("0.5", __LINE__);
    call_next_token(TOK_NUM, line_data_5, 3);
    call_next_token(TOK_EOL, line_data_5, sizeof line_data_5);

    init_buffer(".25", __LINE__);
    call_next_token(TOK_NUM, line_data_6, 3);
    call_next_token(TOK_EOL, line_data_6, sizeof line_data_6);

    init_buffer("123.456", __LINE__);
    call_next_token(TOK_NUM, line_data_8, 7);
    call_next_token(TOK_EOL, line_data_8, sizeof line_data_8);

    init_buffer("100.", __LINE__);
    call_next_token(TOK_NUM, line_data_9, 4);
    call_next_token(TOK_EOL, line_data_9, sizeof line_data_9);

    init_buffer("1E10", __LINE__);
    call_next_token(TOK_NUM, line_data_e1, 4);
    call_next_token(TOK_EOL, line_data_e1, sizeof line_data_e1);

    init_buffer("1.5E-5", __LINE__);
    call_next_token(TOK_NUM, line_data_e2, 6);
    call_next_token(TOK_EOL, line_data_e2, sizeof line_data_e2);

    init_buffer(".5e3", __LINE__);
    call_next_token(TOK_NUM, line_data_e4, 4);
    call_next_token(TOK_EOL, line_data_e4, sizeof line_data_e4);
}

void test_lexer_operators(void) {

    const char line_data_1[] = { TOK_ADD, 0 };
    const char line_data_2[] = { TOK_ADD, TOK_DIV, 0 };

    init_buffer("+", __LINE__);
    call_next_token(TOK_ADD, line_data_1, 1);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);
    init_buffer("  +", __LINE__);
    call_next_token(TOK_ADD, line_data_1, 1);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("+/", __LINE__);
    call_next_token(TOK_ADD, line_data_2, 1);
    call_next_token(TOK_DIV, line_data_2, 2);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);
}

void test_lexer_names(void) {
    const char line_data_1[] = { TOK_PRINT, 0 };
    const char line_data_2[] = { TOK_GOTO, 0 };
    const char line_data_3[] = { TOK_FOR, 0 };
    const char line_data_4[] = { TOK_NEXT, 0 };
    const char line_data_5[] = { TOK_IF, 0 };
    const char line_data_6[] = { TOK_THEN, 0 };

    const char line_data_foo[] = { 'F', 'O', 'O' | 0x80, 0 };
    const char line_data_var123[] = { 'V', 'A', 'R', '1', '2', '3' | 0x80, 0 };
    const char line_data_myvar[] = { 'M', 'Y', '_', 'V', 'A', 'R' | 0x80, 0 };

    PRINT_TEST_NAME();

    init_buffer("PRINT", __LINE__);
    call_next_token(TOK_PRINT, line_data_1, 1);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("GOTO", __LINE__);
    call_next_token(TOK_GOTO, line_data_2, 1);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);

    init_buffer("FOR", __LINE__);
    call_next_token(TOK_FOR, line_data_3, 1);
    call_next_token(TOK_EOL, line_data_3, sizeof line_data_3);

    init_buffer("NEXT", __LINE__);
    call_next_token(TOK_NEXT, line_data_4, 1);
    call_next_token(TOK_EOL, line_data_4, sizeof line_data_4);

    init_buffer("IF", __LINE__);
    call_next_token(TOK_IF, line_data_5, 1);
    call_next_token(TOK_EOL, line_data_5, sizeof line_data_5);

    init_buffer("THEN", __LINE__);
    call_next_token(TOK_THEN, line_data_6, 1);
    call_next_token(TOK_EOL, line_data_6, sizeof line_data_6);

    // Lowercase keywords (should be case-insensitive and match TOK_PRINT etc.)
    init_buffer("print", __LINE__);
    call_next_token(TOK_PRINT, line_data_1, 1);
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("goto", __LINE__);
    call_next_token(TOK_GOTO, line_data_2, 1);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);

    // Lowercase variable names (should convert to uppercase in line_buffer with EOT set)
    init_buffer("foo", __LINE__);
    call_next_token(TOK_NAME, line_data_foo, 3);
    call_next_token(TOK_EOL, line_data_foo, sizeof line_data_foo);

    // Variable names (not in keyword table) should return TOK_NAME with EOT set on the last character
    init_buffer("FOO", __LINE__);
    call_next_token(TOK_NAME, line_data_foo, 3);
    call_next_token(TOK_EOL, line_data_foo, sizeof line_data_foo);

    init_buffer("VAR123", __LINE__);
    call_next_token(TOK_NAME, line_data_var123, 6);
    call_next_token(TOK_EOL, line_data_var123, sizeof line_data_var123);

    init_buffer("MY_VAR", __LINE__);
    call_next_token(TOK_NAME, line_data_myvar, 6);
    call_next_token(TOK_EOL, line_data_myvar, sizeof line_data_myvar);
}

int main(void) {
    initialize_target();
    test_lexer_strings();
    test_lexer_numbers();
    test_lexer_operators();
    test_lexer_names();
    return 0;
}