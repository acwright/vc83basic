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

void test_decode_number(void) {
    const char line_data[] = { '1', '0', '0', ',', '4', '1', '1', '2', ',', '3', '.', '1', '4', '1', '5', '9', ',' };
    Float result_1 = { 0x48000000, 134 };
    Float result_2 = { 0x00800000, 140 };
    Float result_3 = { 0x490FCF81, 129 };
    Float result;

    PRINT_TEST_NAME();

    set_line(0, line_data, sizeof line_data);

    decode_number();
    decode_byte();
    store_fp0(&result);
    ASSERT_FLOAT_EQ(result, result_1);

    decode_number();
    decode_byte();
    store_fp0(&result);
    ASSERT_FLOAT_EQ(result, result_2);

    decode_number();
    decode_byte();
    store_fp0(&result);
    ASSERT_FLOAT_EQ(result, result_3);
}

void test_decode_string(void) {
    const char line_data[] = {
        '"', 'H', 'E', 'L', 'L', 'O', '"'
    };

    PRINT_TEST_NAME();

    initialize_program();

    set_line(0, line_data, sizeof line_data);

    HEXDUMP(&line_buffer, 32);
    HEXDUMP(line_ptr, 32);

    decode_string();
    HEXDUMP(string_ptr, 32);
    ASSERT_EQ(string_ptr->length, 5);
    ASSERT_EQ(memcmp(string_ptr->data, "HELLO", 5), 0);
    ASSERT_EQ(line_pos, 10);
}

void test_decode_name(void) {
    const char line_data[] = {
        'X' | EOT,
        'T', 'H', 'I', 'N', 'G', '3' | EOT,
        'A', '$' | EOT,
        'X' | EOT, '(',
        'A', '$' | EOT, '(',
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
    test_decode_number();
    test_decode_string();
    test_decode_name();
    return 0;
}