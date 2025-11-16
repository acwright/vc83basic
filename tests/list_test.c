#include "test.h"

void add_variable_with_name(const char* name) {
    parse_and_decode_name(name);
    find_name(variable_name_table_ptr);
    ASSERT_NE(err, 0);
    add_variable();
    ASSERT_EQ(err, 0);
}

void create_variables(void) {

    // Create varibles which will get variable name table positions starting at 0.

    add_variable_with_name("X");
    add_variable_with_name("Y");
}

void call_list_statement(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statement()\n", __FILE__, line);
    set_line(0, line_data, line_data_length);
    buffer_pos = 0;
    list_statement();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_statment(void) {

    const char line_data_1[] = { ST_RUN };
    const char line_data_2[] = { ST_LET, 'X' | EOT, 0, '3', '2', '7', '6', '7', 0 };
    // obsolete 3 and 4
    const char line_data_5[] = { ST_LIST, 0 };
    const char line_data_6[] = { ST_INPUT, 'X' | EOT, ',', 'Y' | EOT, 0 };
    const char line_data_7[] = { ST_PRINT, '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_MUL, 'Y' | EOT, 0 };
    const char line_data_8[] = { ST_PRINT, TOKEN_UNARY_OP | UNARY_OP_MINUS, 'X' | EOT, 0 };
    const char line_data_9[] = { ST_PRINT, '2', '2' | EOT, TOKEN_OP | OP_DIV, '7', 0 };
    const char line_data_10[] = { ST_PRINT, '2', '2' | EOT, TOKEN_OP | OP_DIV, '7', ',',
        TOKEN_UNARY_OP | UNARY_OP_MINUS, 'X' | EOT, 0 };
    const char line_data_11[] = { ST_ON_GOTO, 'X' | EOT, 0, '1', '0', ',', '2', '0', 0 };
    const char line_data_12[] = { ST_PRINT, 'X' | EOT, TOKEN_OP | OP_LE, '7', TOKEN_OP | OP_OR,
        'Y' | EOT, TOKEN_OP | OP_EQ, '4', '1', '1', '2', 0 };
    const char line_data_13[] = { ST_PRINT, '(', 'X' | EOT, TOKEN_OP | OP_ADD, '3', ')',
        TOKEN_OP | OP_AND, 'Y' | EOT, 0 };
    const char line_data_14[] = { ST_PRINT, TOKEN_UNARY_OP | UNARY_OP_NOT, '(', 'X' | EOT, TOKEN_OP | OP_EQ,
        '3', TOKEN_OP | OP_OR, TOKEN_UNARY_OP | UNARY_OP_NOT, TOKEN_UNARY_OP | UNARY_OP_MINUS, 
        'Y' | EOT, ')', 0 };
    const char line_data_15[] = { ST_IF_THEN, 'X' | EOT, TOKEN_OP | OP_LT, '1', '0', 0, ST_PRINT, 'X' | EOT, 0, 0 };
    const char line_data_16[] = { ST_PRINT, '"', 'H', 'E', 'L', 'L', 'O', '"', 0 };
    const char line_data_17[] = { ST_PRINT, '"', 'B', 'U', 'G', ' ', 'O', 'R', ' ', '"', '"',
        'F', 'E', 'A', 'T', 'U', 'R', 'E', '?', '"', '"', '"', 0 };
    const char line_data_18[] = { ST_PRINT, 'X' | EOT, '(', '2', ',', '5', ')', 0 };
    const char line_data_19[] = { ST_PRINT, 'A', '$' | EOT, '(', '1', ')', 0 };
    const char line_data_20[] = { ST_PRINT, 0 | TOKEN_FUNCTION, '"', 'H', 'E', 'L', 'L', 'O', '"', ')', 0 };
    const char line_data_21[] = { ST_PRINT, 1 | TOKEN_FUNCTION, '2', '5', ')', 0 };
    
    const char list_1[] = "RUN";
    const char list_2[] = "LET X=32767";
    const char list_5[] = "LIST";
    const char list_6[] = "INPUT X,Y";
    const char list_7[] = "PRINT (X+3)*Y";
    const char list_8[] = "PRINT -X";
    const char list_9[] = "PRINT 22/7";
    const char list_10[] = "PRINT 22/7,-X";
    const char list_11[] = "ON X GOTO 10,20";
    const char list_12[] = "PRINT X<=7 OR Y=4112";
    const char list_13[] = "PRINT (X+3) AND Y";
    const char list_14[] = "PRINT NOT (X=3 OR NOT -Y)";
    const char list_15[] = "IF X<10 THEN PRINT X";
    const char list_16[] = "PRINT \"HELLO\"";
    const char list_17[] = "PRINT \"BUG OR \"\"FEATURE?\"\"\"";
    const char list_18[] = "PRINT X(2,5)";
    const char list_19[] = "PRINT A$(1)";
    const char list_20[] = "PRINT LEN(\"HELLO\")";
    const char list_21[] = "PRINT STR$(25)";

    PRINT_TEST_NAME();

    initialize_program();
    create_variables();

    call_list_statement(line_data_1, sizeof line_data_1, list_1, __LINE__);
    call_list_statement(line_data_2, sizeof line_data_2, list_2, __LINE__);
    call_list_statement(line_data_5, sizeof line_data_5, list_5, __LINE__);
    call_list_statement(line_data_6, sizeof line_data_6, list_6, __LINE__);
    call_list_statement(line_data_7, sizeof line_data_7, list_7, __LINE__);
    call_list_statement(line_data_8, sizeof line_data_8, list_8, __LINE__);
    call_list_statement(line_data_9, sizeof line_data_9, list_9, __LINE__);
    call_list_statement(line_data_10, sizeof line_data_10, list_10, __LINE__);
    call_list_statement(line_data_11, sizeof line_data_11, list_11, __LINE__);
    call_list_statement(line_data_12, sizeof line_data_12, list_12, __LINE__);
    call_list_statement(line_data_13, sizeof line_data_13, list_13, __LINE__);
    call_list_statement(line_data_14, sizeof line_data_14, list_14, __LINE__);
    call_list_statement(line_data_15, sizeof line_data_15, list_15, __LINE__);
    call_list_statement(line_data_16, sizeof line_data_16, list_16, __LINE__);
    call_list_statement(line_data_17, sizeof line_data_17, list_17, __LINE__);
    call_list_statement(line_data_18, sizeof line_data_18, list_18, __LINE__);
    call_list_statement(line_data_19, sizeof line_data_19, list_19, __LINE__);
    call_list_statement(line_data_20, sizeof line_data_20, list_20, __LINE__);
    call_list_statement(line_data_21, sizeof line_data_21, list_21, __LINE__);
}

void call_list_statements(const char* line_data, size_t line_data_length, const char* expect_buffer, int line) {
    fprintf(stderr, "  %s:%d: list_statements(): expecting \"%s\"\n", __FILE__, line, expect_buffer);
    set_line(0, line_data, line_data_length);
    buffer_pos = 0;
    list_statements();
    ASSERT_MEMORY_EQ(buffer, expect_buffer, strlen(expect_buffer));
    ASSERT_EQ(buffer_pos, strlen(expect_buffer));
}

void test_list_statements(void) {

    // The test cases here should mirror the ones in parser_test.c.

    const char simple_line_data_1[] = { ST_NEW_RUN, 0 };
    const char number_line_data_1[] = { ST_NEW_PRINT, '1', 0 };
    const char number_line_data_2[] = { ST_NEW_PRINT, '2', '5', 0 };
    const char number_line_data_3[] = { ST_NEW_PRINT, '3', '.', '1', '4', '1', '5', '9', 0 };
    const char number_line_data_4[] = { ST_NEW_PRINT, '1', '0', '.', 0 };
    const char number_line_data_5[] = { ST_NEW_PRINT, '.', '1', '2', '5', 0 };
    const char string_line_data_1[] = { ST_NEW_PRINT, '"', 'H', 'E', 'L', 'L', 'O', '"', 0 };
    const char string_line_data_2[] = { ST_NEW_PRINT, '"', 'B', 'U', 'G', ' ', 'O', 'R', ' ', '"', '"', 
        'F', 'E', 'A', 'T', 'U', 'R', 'E', '?', '"', '"', '"', 0 };
    const char variable_line_data_1[] = { ST_NEW_PRINT, 'I', 'D', 'X', '_', '2' | EOT, 0 };
    const char variable_line_data_2[] = { ST_NEW_PRINT, 'A', '$' | EOT, 0 };
    const char variable_line_data_3[] = { ST_NEW_PRINT, 'X' | EOT, '(', '5', ')', 0 };
    const char variable_line_data_4[] = { ST_NEW_PRINT, 'X', 'Y', 'Z', 'Z', 'Y', '$' | EOT, '(', '1', ',', '1', '0', ')', 0 };
    const char function_line_data_1[] = { ST_NEW_PRINT, TOKEN_FUNCTION | 0, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ')', 0 };
    const char function_line_data_2[] = { ST_NEW_PRINT, TOKEN_FUNCTION | 6, '(', '"', 'H', 'E', 'L', 'L', 'O', '"', ',', '2', ',', '3', ')', 0 };
    const char expression_line_data_1[] = { ST_NEW_PRINT, '1', TOKEN_OP | OP_ADD, '1', TOKEN_OP | OP_ADD, '1', 0 };
    const char expression_line_data_2[] = { ST_NEW_PRINT, '1', TOKEN_OP | OP_ADD, '(', '1', TOKEN_OP | OP_ADD, '1', ')', 0 };
    const char expression_line_data_3[] = { ST_NEW_PRINT, '"', 'H', 'E', 'L', 'L', 'O', '"', TOKEN_OP | OP_CONCAT, '"', ',', ' ', 'W', 'O', 'R', 'L', 'D', '"', 0 };
    const char for_line_data_1[] = { ST_NEW_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '5', 0 };
    const char for_line_data_2[] = { ST_NEW_FOR, 'X' | EOT, '=', '1', TOKEN_CLAUSE | CLAUSE_TO, '2', '0', TOKEN_CLAUSE | CLAUSE_STEP, '2', 0 };
    const char let_line_data_1[] = { ST_NEW_LET, 'X' | EOT, '=', '1', '0', '0', 0 };
    const char if_line_data_1[] = { ST_NEW_IF_THEN, 'X' | EOT, TOKEN_OP | OP_EQ, '1', TOKEN_CLAUSE | CLAUSE_THEN, ST_GOTO, '1', '0', 0 };
    const char input_line_data_1[] = { ST_NEW_INPUT, 'A' | EOT, 0 };
    const char input_line_data_2[] = { ST_NEW_INPUT, 'A' | EOT, ',', 'B' | EOT, ',', 'C' | EOT, 0 };
    const char on_line_data_1[] = { ST_NEW_ON, '1', TOKEN_CLAUSE | CLAUSE_GOTO, '1', '0', 0 };
    const char on_line_data_2[] = { ST_NEW_ON, '1', TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0', 0 };
    const char on_line_data_3[] = { ST_NEW_ON, 'X' | EOT, TOKEN_CLAUSE | CLAUSE_GOSUB, '1', '0', ',', '2', '0', ',', '3', '0', 0 };
    const char next_line_data_1[] = { ST_NEW_NEXT, 'X' | EOT, 0 };
    const char list_line_data_1[] = { ST_NEW_LIST, 0 };
    const char list_line_data_2[] = { ST_NEW_LIST, '1', '0', '0', 0 };
    const char list_line_data_3[] = { ST_NEW_LIST, '1', '0', '0', ',', '5', '0', '0', 0 };
    const char multi_line_data_1[] = { ST_NEW_LET, 'X' | EOT, '=', '1', '0', '0', ':', ST_NEW_PRINT, 'X' | EOT, 0 };

    PRINT_TEST_NAME();

    initialize_program();

    call_list_statements(simple_line_data_1, sizeof simple_line_data_1, "RUN", __LINE__);
    call_list_statements(number_line_data_1, sizeof number_line_data_1, "PRINT 1", __LINE__);
    call_list_statements(number_line_data_2, sizeof number_line_data_2, "PRINT 25", __LINE__);
    call_list_statements(number_line_data_3, sizeof number_line_data_3, "PRINT 3.14159", __LINE__);
    call_list_statements(number_line_data_4, sizeof number_line_data_4, "PRINT 10.", __LINE__);
    call_list_statements(number_line_data_5, sizeof number_line_data_5, "PRINT .125", __LINE__);
    call_list_statements(string_line_data_1, sizeof string_line_data_1, "PRINT \"HELLO\"", __LINE__);
    call_list_statements(string_line_data_2, sizeof string_line_data_2, "PRINT \"BUG OR \"\"FEATURE?\"\"\"", __LINE__);
    call_list_statements(variable_line_data_1, sizeof variable_line_data_1, "PRINT IDX_2", __LINE__);
    call_list_statements(variable_line_data_2, sizeof variable_line_data_2, "PRINT A$", __LINE__);
    call_list_statements(variable_line_data_3, sizeof variable_line_data_3, "PRINT X(5)", __LINE__);
    call_list_statements(variable_line_data_4, sizeof variable_line_data_4, "PRINT XYZZY$(1,10)", __LINE__);
    call_list_statements(function_line_data_1, sizeof function_line_data_1, "PRINT LEN(\"HELLO\")", __LINE__);
    call_list_statements(function_line_data_2, sizeof function_line_data_2, "PRINT MID$(\"HELLO\",2,3)", __LINE__);
    call_list_statements(expression_line_data_1, sizeof expression_line_data_1, "PRINT 1+1+1", __LINE__);
    call_list_statements(expression_line_data_2, sizeof expression_line_data_2, "PRINT 1+(1+1)", __LINE__);
    call_list_statements(expression_line_data_3, sizeof expression_line_data_3, "PRINT \"HELLO\"&\", WORLD\"", __LINE__);
    call_list_statements(for_line_data_1, sizeof for_line_data_1, "FOR X=1 TO 5", __LINE__);
    call_list_statements(for_line_data_2, sizeof for_line_data_2, "FOR X=1 TO 20 STEP 2", __LINE__);
    call_list_statements(let_line_data_1, sizeof let_line_data_1, "LET X=100", __LINE__);
    call_list_statements(if_line_data_1, sizeof if_line_data_1, "IF X=1 THEN GOTO 10", __LINE__);
    call_list_statements(input_line_data_1, sizeof input_line_data_1, "INPUT A", __LINE__);
    call_list_statements(input_line_data_2, sizeof input_line_data_2, "INPUT A,B,C", __LINE__);
    call_list_statements(on_line_data_1, sizeof on_line_data_1, "ON 1 GOTO 10", __LINE__);
    call_list_statements(on_line_data_2, sizeof on_line_data_2, "ON 1 GOSUB 10", __LINE__);
    call_list_statements(on_line_data_3, sizeof on_line_data_3, "ON X GOSUB 10,20,30", __LINE__);
    call_list_statements(next_line_data_1, sizeof next_line_data_1, "NEXT X", __LINE__);
    call_list_statements(list_line_data_1, sizeof list_line_data_1, "LIST", __LINE__);
    call_list_statements(list_line_data_2, sizeof list_line_data_2, "LIST 100", __LINE__);
    call_list_statements(list_line_data_3, sizeof list_line_data_3, "LIST 100,500", __LINE__);
    call_list_statements(multi_line_data_1, sizeof multi_line_data_1, "LET X=100:PRINT X", __LINE__);
}

int main(void) {

    initialize_target();
    // test_list_statment();
    test_list_statements();

    return 0;
}
