#include "test.h"

static void test_initalize_program(void) {
    PRINT_TEST_NAME();

    initialize_program();
}

int main(void) {
    test_initalize_program();
    return 0;
}