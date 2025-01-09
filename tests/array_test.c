#include "test.h"

void test_imul_16(void) {
    int result;
    
    PRINT_TEST_NAME();

    result = imul_16(0, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 0);
    result = imul_16(1, 0);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 0);
    result = imul_16(1, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 1);
    result = imul_16(1, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 2);
    result = imul_16(2, 1);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 2);
    result = imul_16(2, 2);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 4);
    result = imul_16(3, 45);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 135);
    result = imul_16(100, 90);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 9000);
    result = imul_16(1, 32767);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, 32767);
    result = imul_16(2, 32767);
    ASSERT_EQ(err, 0);
    ASSERT_EQ(result, -2); // Rolls over

    result = imul_16(1000, 1000);
    ASSERT_NE(err, 0);
    result = imul_16(3, 32767);
    ASSERT_NE(err, 0);



}


int main(void) {
    initialize_target();
    test_imul_16();
    return 0;
}
