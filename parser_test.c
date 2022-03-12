#include "test.h"

static void test_char_to_digit(void) {
    int err;

    PRINT_TEST_NAME();

    err = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    err = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 9);
    err = char_to_digit('0'-1);
    ASSERT_NE(err, 0);
    err = char_to_digit('9'+1);
    ASSERT_NE(err, 0);
    err = char_to_digit(' ');
    ASSERT_NE(err, 0);
    err = char_to_digit('A');
    ASSERT_NE(err, 0);
    err = char_to_digit(0);
    ASSERT_NE(err, 0);
    err = char_to_digit(255);
    ASSERT_NE(err, 0);
}

static void test_parse_number(void) {
    int err;

    PRINT_TEST_NAME();

    strcpy(buffer, "10 PRINT X");
    buffer_length = 10;
    err = parse_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 10);

    // The function should honor the current read index.
    strcpy(buffer, "1020 PRINT X");
    buffer_length = 12;
    err = parse_number(2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 20);

    // The function should skip inital whitespace.
    strcpy(buffer, "  10000 PRINT X");
    buffer_length = 15;
    err = parse_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 10000);

    // The function should return carry set if an invalid number.
    strcpy(buffer, "invalid");
    buffer_length = 7;
    err = parse_number(0);
    ASSERT_NE(err, 0);

    // The function should not read past the end of the buffer.
    strcpy(buffer, "10000");
    buffer_length = 3;
    err = parse_number(0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_ax, 100);

    buffer_length = 0;
    err = parse_number(0);
    ASSERT_NE(err, 0);
}

int main(void) {
    initialize_target();
    test_char_to_digit();
    test_parse_number();
    return 0;
}