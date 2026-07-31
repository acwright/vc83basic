/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void test_next_token(void) {

    PRINT_TEST_NAME();

    // Set to unlikely values because the first test should set them to 0.
    token = 255;
    token_pos = 255;

    strcpy(buffer, "");
    buffer_pos = 0;
    next_token();
    ASSERT_EQ(token, 0);
    ASSERT_EQ(token_pos, 0);
}

int main(void) {
    initialize_target();
    test_next_token();
    return 0;
}