/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void init_buffer(const char *s) {
    strcpy(buffer, s);
    buffer_pos = 0;
    line_pos = offsetof(Line, data);
}

void call_next_token(char expect_token, const char* expect_line_data, char expect_line_data_length) {

    // Set to unlikely values to avoid false positive if the last token was the expected one.
    token = 255;

    next_token();
    ASSERT_EQ(token, expect_token);
    ASSERT_MEMORY_EQ(line_buffer.data, expect_line_data, expect_line_data_length);
    ASSERT_EQ(line_pos, offsetof(Line, data) + expect_line_data_length);
}

void test_next_token(void) {

    const char line_data_1[] = { 0 };
    const char line_data_2[] = { '"', 'H', 'E', 'L', 'L', 'O', '"', 0 };

    PRINT_TEST_NAME();


    init_buffer("");
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("  ");
    call_next_token(TOK_EOL, line_data_1, sizeof line_data_1);

    init_buffer("\"HELLO\"");
    call_next_token('"', line_data_2, 7);
    call_next_token(TOK_EOL, line_data_2, sizeof line_data_2);
    // init_buffer("\"CALL ME \"\"ISHMAEL\"\"\"");
    // check_token('"', 0, 21);
    // init_buffer("\"ONE\" \"TWO\"");
    // check_token('"', 0, 5);
    // check_token('"', 6, 11);

    // init_buffer("=");
    // check_token(TOK_EQ, 0, 1);
}

int main(void) {
    initialize_target();
    test_next_token();
    return 0;
}