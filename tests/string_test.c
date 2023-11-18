#include "test.h"

void call_read_string(const char* input, char expect_si, const char* expect_output, char expect_length, int line) {
    char length;
    char output_buffer[40];
    fprintf(stderr, "  %s:%d: read_string(input=\"%s\")\n", __FILE__, line, input);
    strcpy(buffer, input);
    src_ptr = buffer;
    si = 0;
    memset(output_buffer, 0, sizeof output_buffer);
    dst_ptr = output_buffer;
    di = 2;
    length = read_string();
    HEXDUMP(output_buffer, length);
    ASSERT_EQ(length, expect_length);
    ASSERT_EQ(memcmp(output_buffer + 2 /* di started at 2 */, expect_output, length), 0);
    ASSERT_EQ(si, expect_si);
    ASSERT_EQ(di, expect_length + 1 /* length byte */ + 2 /* di started at 2 */);
    ASSERT_EQ(length, expect_length);
}

void test_read_string(void) {
    PRINT_TEST_NAME();

    call_read_string("HELLO", 5, "\x05HELLO", 5, __LINE__);
    call_read_string("HELLO,WORLD", 5, "\x05HELLO", 5, __LINE__);
    call_read_string("\"HELLO\"", 7, "\x05HELLO", 5, __LINE__);
    call_read_string("HELLO\"", 6, "\x06HELLO\"", 6, __LINE__);
    call_read_string("\"\"", 2, "\x00", 0, __LINE__);
    call_read_string("\"\",IGNORE", 2, "\x00", 0, __LINE__);
    call_read_string(",IGNORE", 0, "\x00", 0, __LINE__);
    call_read_string("REPEATED\"\"CHARS", 15, "\x0FREPEATED\"\"CHARS", 15, __LINE__);
    call_read_string("\"REPEATED\"\"CHARS\"", 17, "\x0EREPEATED\"CHARS", 14, __LINE__);
}

int main(void) {
    initialize_target();
    test_read_string();
    return 0;
}
