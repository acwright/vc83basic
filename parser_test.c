#include "test.h"

static void test_char_to_digit(void) {
    int err;

    err = char_to_digit('0');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 0);
    err = char_to_digit('9');
    ASSERT_EQ(err, 0);
    ASSERT_EQ(reg_a, 9);
    err = char_to_digit(' ');
    ASSERT_EQ(err, 1);
    err = char_to_digit('A');
    ASSERT_EQ(err, 1);
}

static void test_parse_number(void) {
    int err;

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
}

int main(void) {
    initialize_arch();
    test_char_to_digit();
    test_parse_number();
    return 0;
}