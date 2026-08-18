/*
 * SPDX-FileCopyrightText: 2022-2026 Willis Blackburn
 *
 * SPDX-License-Identifier: MIT
 */

#include "test.h"

void call_list_statement(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statement(): expecting \"%s\"\n", __FILE__, line, expect_buffer);
    set_line(0, line_data, line_data_length);
    // These values are initialized in list_line, which we're not calling here.
    buffer_pos = 0;
    string_flag = 0;
    list_statement();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_statement(void) {

    // The test cases here should mirror the ones in parser_test.c.
    // The next statement offset bytes are 0 because list_statement doesn't use them (it always lists everything).

    const char simple_line_data_1[] = { 0, TOK_RUN, 0 };
    const char number_line_data_1[] = { 0, TOK_PRINT, TOK_NUM, '1' | EOT, 0 };
    const char number_line_data_2[] = { 0, TOK_PRINT, TOK_NUM, '2', '5' | EOT, 0 };
    const char number_line_data_3[] = { 0, TOK_PRINT, TOK_NUM, '3', '.', '1', '4', '1', '5', '9' | EOT, 0 };
    const char number_line_data_4[] = { 0, TOK_PRINT, TOK_NUM, '1', '0', '.' | EOT, 0 };
    const char number_line_data_5[] = { 0, TOK_PRINT, TOK_NUM, '.', '1', '2', '5' | EOT, 0 };
    const char string_line_data_1[] = { 0, TOK_PRINT, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, 0 };
    const char string_line_data_2[] = { 0, TOK_PRINT, TOK_STRING, 9, 'l', 'o', 'w', 'e', 'r', 'c', 'a', 's', 'e', '"' | EOT, 0 };
    const char variable_line_data_1[] = { 0, TOK_PRINT, TOK_NAME, 'I', 'D', 'X', '_', '2' | EOT, 0 };
    const char variable_line_data_2[] = { 0, TOK_PRINT, TOK_NAME, 'A', '$' | EOT, 0 };
    const char variable_line_data_3[] = { 0, TOK_PRINT, TOK_NAME, 'X' | EOT, TOK_LPAREN, TOK_NUM, '5' | EOT, TOK_RPAREN, 0 };
    const char variable_line_data_4[] = { 0, TOK_PRINT, TOK_NAME, 'X', 'Y', 'Z', 'Z', 'Y', '$' | EOT, TOK_LPAREN, TOK_NUM, '1' | EOT, TOK_COMMA, TOK_NUM, '1', '0' | EOT, TOK_RPAREN, 0 };
    const char function_line_data_1[] = { 0, TOK_PRINT, TOK_LEN, TOK_LPAREN, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, TOK_RPAREN, 0 };
    const char function_line_data_2[] = { 0, TOK_PRINT, TOK_MID_S, TOK_LPAREN, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, TOK_COMMA, TOK_NUM, '2' | EOT, TOK_COMMA, TOK_NUM, '3' | EOT, TOK_RPAREN, 0 };
    const char function_line_data_3[] = { 0, TOK_PRINT, TOK_VER_S, TOK_LPAREN, TOK_NUM, '0' | EOT, TOK_RPAREN, 0 };
    const char expression_line_data_1[] = { 0, TOK_PRINT, TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, 0 };
    const char expression_line_data_2[] = { 0, TOK_PRINT, TOK_NUM, '1' | EOT, TOK_ADD, TOK_LPAREN, TOK_NUM, '1' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, TOK_RPAREN, 0 };
    const char expression_line_data_3[] = { 0, TOK_PRINT, TOK_NUM, '3', '1', '4', '.', '1', '5' | EOT, TOK_DIV, TOK_NUM, '1', '0' | EOT, TOK_POW, TOK_NUM, '2' | EOT, TOK_MUL, TOK_NAME, 'X' | EOT, 0 };
    const char expression_line_data_4[] = { 0, TOK_PRINT, TOK_STRING, 5, 'H', 'E', 'L', 'L', 'O', '"' | EOT, TOK_CONCAT, TOK_STRING, 7, ',', ' ', 'W', 'O', 'R', 'L', 'D', '"' | EOT, 0 };
    const char print_line_data_1[] = { 0, TOK_PRINT, TOK_NAME, 'X' | EOT, TOK_COMMA, TOK_NAME, 'Y' | EOT, TOK_SEMI, TOK_NAME, 'Z' | EOT, 0 };
    const char print_line_data_2[] = { 0, TOK_ALT_PRINT, TOK_NAME, 'X' | EOT, TOK_COMMA, TOK_NAME, 'Y' | EOT, TOK_SEMI, TOK_NAME, 'Z' | EOT, 0 };
    const char for_line_data_1[] = { 0, TOK_FOR, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_TO, TOK_NUM, '5' | EOT, 0 };
    const char for_line_data_2[] = { 0, TOK_FOR, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_TO, TOK_NUM, '2', '0' | EOT, TOK_STEP, TOK_NUM, '2' | EOT, 0 };
    const char let_line_data_1[] = { 0, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, 0 };
    const char let_line_data_2[] = { 0, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, 0 };
    const char if_line_data_1[] = { 0, TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_GOTO, TOK_NUM, '1', '0' | EOT, 0 };
    const char if_line_data_2[] = { 0, TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_NUM, '1', '0' | EOT, 0 };
    const char if_line_data_3[] = { 0, TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NAME, 'X' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, 0 };
    const char if_line_data_4[] = { 0, TOK_IF, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1' | EOT, TOK_THEN, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NAME, 'X' | EOT, TOK_ADD, TOK_NUM, '1' | EOT, 0 };
    const char input_line_data_1[] = { 0, TOK_INPUT, TOK_NAME, 'A' | EOT, 0 };
    const char input_line_data_2[] = { 0, TOK_INPUT, TOK_NAME, 'A' | EOT, TOK_COMMA, TOK_NAME, 'B' | EOT, TOK_COMMA, TOK_NAME, 'C' | EOT, 0 };
    const char on_line_data_1[] = { 0, TOK_ON, TOK_NUM, '1' | EOT, TOK_GOTO, TOK_NUM, '1', '0' | EOT, 0 };
    const char on_line_data_2[] = { 0, TOK_ON, TOK_NUM, '1' | EOT, TOK_GOSUB, TOK_NUM, '1', '0' | EOT, 0 };
    const char on_line_data_3[] = { 0, TOK_ON, TOK_NAME, 'X' | EOT, TOK_GOSUB, TOK_NUM, '1', '0' | EOT, TOK_COMMA, TOK_NUM, '2', '0' | EOT, TOK_COMMA, TOK_NUM, '3', '0' | EOT, 0 };
    const char next_line_data_1[] = { 0, TOK_NEXT, TOK_NAME, 'X' | EOT, 0 };
    const char list_line_data_1[] = { 0, TOK_LIST, 0 };
    const char list_line_data_2[] = { 0, TOK_LIST, TOK_NUM, '1', '0', '0' | EOT, 0 };
    const char list_line_data_3[] = { 0, TOK_LIST, TOK_NUM, '1', '0', '0' | EOT, TOK_COMMA, TOK_NUM, '5', '0', '0' | EOT, 0 };
    const char data_line_data_1[] = { 0, TOK_DATA, 'H', 'E', 'L', 'L', 'O', ',', '\"', 'X', ',', 'Y', '\"', ',', '5', 0 };
    const char extension_line_data_1[] = { 0, TOK_BYE, 0 };

    PRINT_TEST_NAME();

    initialize_program();

    call_list_statement(simple_line_data_1, sizeof simple_line_data_1, "RUN", __LINE__);
    call_list_statement(number_line_data_1, sizeof number_line_data_1, "PRINT 1", __LINE__);
    call_list_statement(number_line_data_2, sizeof number_line_data_2, "PRINT 25", __LINE__);
    call_list_statement(number_line_data_3, sizeof number_line_data_3, "PRINT 3.14159", __LINE__);
    call_list_statement(number_line_data_4, sizeof number_line_data_4, "PRINT 10.", __LINE__);
    call_list_statement(number_line_data_5, sizeof number_line_data_5, "PRINT .125", __LINE__);
    call_list_statement(string_line_data_1, sizeof string_line_data_1, "PRINT \"HELLO\"", __LINE__);
    call_list_statement(string_line_data_2, sizeof string_line_data_2, "PRINT \"lowercase\"", __LINE__);
    call_list_statement(variable_line_data_1, sizeof variable_line_data_1, "PRINT IDX_2", __LINE__);
    call_list_statement(variable_line_data_2, sizeof variable_line_data_2, "PRINT A$", __LINE__);
    call_list_statement(variable_line_data_3, sizeof variable_line_data_3, "PRINT X(5)", __LINE__);
    call_list_statement(variable_line_data_4, sizeof variable_line_data_4, "PRINT XYZZY$(1,10)", __LINE__);
    call_list_statement(function_line_data_1, sizeof function_line_data_1, "PRINT LEN(\"HELLO\")", __LINE__);
    call_list_statement(function_line_data_2, sizeof function_line_data_2, "PRINT MID$(\"HELLO\",2,3)", __LINE__);
    call_list_statement(function_line_data_3, sizeof function_line_data_3, "PRINT VER$(0)", __LINE__);
    call_list_statement(expression_line_data_1, sizeof expression_line_data_1, "PRINT 1+1+1", __LINE__);
    call_list_statement(expression_line_data_2, sizeof expression_line_data_2, "PRINT 1+(1+1)", __LINE__);
    call_list_statement(expression_line_data_3, sizeof expression_line_data_3, "PRINT 314.15/10^2*X", __LINE__);
    call_list_statement(expression_line_data_4, sizeof expression_line_data_4, "PRINT \"HELLO\"&\", WORLD\"", __LINE__);
    call_list_statement(print_line_data_1, sizeof print_line_data_1, "PRINT X,Y;Z", __LINE__);
    call_list_statement(print_line_data_2, sizeof print_line_data_2, "?X,Y;Z", __LINE__);
    call_list_statement(for_line_data_1, sizeof for_line_data_1, "FOR X=1 TO 5", __LINE__);
    call_list_statement(for_line_data_2, sizeof for_line_data_2, "FOR X=1 TO 20 STEP 2", __LINE__);
    call_list_statement(let_line_data_1, sizeof let_line_data_1, "LET X=100", __LINE__);
    call_list_statement(let_line_data_2, sizeof let_line_data_2, "X=100", __LINE__);
    call_list_statement(if_line_data_1, sizeof if_line_data_1, "IF X=1 THEN GOTO 10", __LINE__);
    call_list_statement(if_line_data_2, sizeof if_line_data_2, "IF X=1 THEN 10", __LINE__);
    call_list_statement(if_line_data_3, sizeof if_line_data_3, "IF X=1 THEN LET X=X+1", __LINE__);
    call_list_statement(if_line_data_4, sizeof if_line_data_4, "IF X=1 THEN X=X+1", __LINE__);
    call_list_statement(input_line_data_1, sizeof input_line_data_1, "INPUT A", __LINE__);
    call_list_statement(input_line_data_2, sizeof input_line_data_2, "INPUT A,B,C", __LINE__);
    call_list_statement(on_line_data_1, sizeof on_line_data_1, "ON 1 GOTO 10", __LINE__);
    call_list_statement(on_line_data_2, sizeof on_line_data_2, "ON 1 GOSUB 10", __LINE__);
    call_list_statement(on_line_data_3, sizeof on_line_data_3, "ON X GOSUB 10,20,30", __LINE__);
    call_list_statement(next_line_data_1, sizeof next_line_data_1, "NEXT X", __LINE__);
    call_list_statement(list_line_data_1, sizeof list_line_data_1, "LIST", __LINE__);
    call_list_statement(list_line_data_2, sizeof list_line_data_2, "LIST 100", __LINE__);
    call_list_statement(list_line_data_3, sizeof list_line_data_3, "LIST 100,500", __LINE__);
    call_list_statement(data_line_data_1, sizeof data_line_data_1, "DATA HELLO,\"X,Y\",5", __LINE__);
    call_list_statement(extension_line_data_1, sizeof extension_line_data_1, "BYE", __LINE__);
}

void call_list_line(const Line* test_line, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_line(): expecting \"%s\"\n", __FILE__, line, expect_buffer);
    memcpy(&line_buffer, test_line, test_line->next_line_offset);
    line_ptr = &line_buffer;
    list_line();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_line(void) {

    const Line print_line_1 = { 14, 10, { 14, TOK_PRINT, TOK_NAME, 'X' | EOT, TOK_COMMA, TOK_NAME, 'Y' | EOT, TOK_SEMI, TOK_NAME, 'Z' | EOT, 0 } };
    const Line print_line_2 = { 14, 10, { 14, TOK_ALT_PRINT, TOK_NAME, 'X' | EOT, TOK_COMMA, TOK_NAME, 'Y' | EOT, TOK_SEMI, TOK_NAME, 'Z' | EOT, 0 } };
    const Line multi_line_1 = { 13, 10, { 13, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, 0 } };
    const Line multi_line_2 = { 18, 1000, { 13, TOK_LET, TOK_NAME, 'X' | EOT, TOK_EQ, TOK_NUM, '1', '0', '0' | EOT, 0, 18, TOK_PRINT, TOK_NAME, 'X' | EOT, 0 } };
    const Line multi_line_3 = { 11, 32767, { 8, TOK_PRINT, TOK_NUM, '1' | EOT, 0, 11, TOK_END, 0 } };

    PRINT_TEST_NAME();

    initialize_program();

    call_list_line(&print_line_1, "10 PRINT X,Y;Z", __LINE__);
    call_list_line(&print_line_2, "10 ?X,Y;Z", __LINE__);
    call_list_line(&multi_line_1, "10 LET X=100", __LINE__);
    call_list_line(&multi_line_2, "1000 LET X=100:PRINT X", __LINE__);
    call_list_line(&multi_line_3, "32767 PRINT 1:END", __LINE__);
}

int main(void) {

    initialize_target();
    test_list_statement();
    test_list_line();

    return 0;
}
