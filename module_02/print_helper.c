/* print_helper.c — Module 02
 * C helpers that let registers.asm print values without knowing the ABI yet.
 * Module 09 teaches how to call these directly with the correct argument registers.
 */
#include <stdio.h>
#include <stdint.h>

/* Print a 64-bit unsigned value in decimal and hex */
void print_u64(uint64_t value)
{
    printf("decimal: %20llu   hex: 0x%016llX\n",
           (unsigned long long)value,
           (unsigned long long)value);
}

/* Print a label string */
void print_label(const char *label)
{
    printf("\n--- %s ---\n", label);
}
