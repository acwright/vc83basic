#include "test.h"

static void handle_unused(void) {
}

static void handle_variable(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_VAR | 3);
}

static void handle_operator(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_OP | OP_DIV);
}

static void handle_no_value(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_NO_VALUE);
}

static void handle_integer_literal(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_INT);
    lp += 2;
}

static void handle_left_paren(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_LPAREN);
}

static void handle_right_paren(void) {
    __asm__ ("stx %v", reg_x);
    ASSERT_EQ(reg_x, TOKEN_RPAREN);
}

static void test_decode_dispatch_next(void) {

    Line line = {
        11,
        10,
        {
            TOKEN_VAR | 3,                  // variable 3
            TOKEN_OP | OP_DIV,              // divide
            TOKEN_NO_VALUE,
            TOKEN_INT, 0x10, 0x10,          // integer value 4,112
            TOKEN_LPAREN,
            TOKEN_RPAREN,
        }
    };

    void* vector_table[] = {
        handle_variable,
        handle_unused,
        handle_unused,
        handle_operator,
        handle_no_value,
        handle_integer_literal,
        handle_unused,
        handle_unused,
        handle_unused,
        handle_unused,
        handle_left_paren,
        handle_right_paren,
        handle_unused,
        handle_unused,
        handle_unused,
        handle_unused,
    };

    PRINT_TEST_NAME();

    line_ptr = &line;
    lp = 3;
    vector_table_ptr = vector_table;
    while (lp < line.next_line_offset) {
        DEBUG(lp);
        decode_dispatch_next();
    }
}

static void test_decode_byte(void) {
    char byte_value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    byte_value = decode_byte(line_data, 0);
    ASSERT_EQ(byte_value, 0);

    byte_value = decode_byte(line_data, 2);
    ASSERT_EQ(byte_value, 1);
}

static void test_decode_number(void) {
    int value;
    const char line_data[] = { 0, 0, 1, 3 };

    PRINT_TEST_NAME();

    value = decode_number(line_data, 0);
    ASSERT_EQ(value, 0);

    value = decode_number(line_data, 1);
    ASSERT_EQ(value, 256);

    value = decode_number(line_data, 2);
    ASSERT_EQ(value, 769);
}

int main(void) {
    initialize_target();
    test_decode_dispatch_next();
    test_decode_byte();
    test_decode_number();
    return 0;
}