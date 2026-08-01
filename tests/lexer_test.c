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

int main(void) {
    initialize_target();
    test_lexer_strings();
    test_lexer_operators();
    return 0;
}