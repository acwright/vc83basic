/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = {
        0x00, 0x01, 0x03
    };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x00);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x01);

    byte_value = decode_byte();
    ASSERT_EQ(byte_value, 0x03);
}



void test_decode_name(void) {
    const char line_data[] = {
        'X' | EOT,
        'T', 'H', 'I', 'N', 'G', '3' | EOT,
        'A', '$' | EOT,
        'X' | EOT, TOK_LPAREN,
        'A', '$' | EOT, TOK_LPAREN,
     };

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data);
    ASSERT_EQ(decode_name_length, 1);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 1);
    ASSERT_EQ(decode_name_length, 6);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 7);
    ASSERT_EQ(decode_name_length, 2);
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, 0);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 9);
    ASSERT_EQ(decode_name_length, 1);
    ASSERT_EQ(decode_name_type, TYPE_NUMBER);
    ASSERT_EQ(decode_name_arity, -1);

    decode_name();
    ASSERT_PTR_EQ(decode_name_ptr, line_buffer.data + 11);
    ASSERT_EQ(decode_name_length, 2);
    ASSERT_EQ(decode_name_type, TYPE_STRING);
    ASSERT_EQ(decode_name_arity, -1);
}

int main(void) {
    initialize_target();
    test_decode_byte();
    test_decode_name();
    return 0;
}