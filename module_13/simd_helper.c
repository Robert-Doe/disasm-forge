/* simd_helper.c — Module 13 */
#include <stdio.h>
#include <stdint.h>

void print_f64(double v) {
    printf("  fval: %f\n", v);
}

void print_u64(uint64_t v) {
    printf("  val:  %-20llu  0x%llX\n",
           (unsigned long long)v, (unsigned long long)v);
}

void print_label(const char *s) {
    printf("\n=== %s ===\n", s);
}
