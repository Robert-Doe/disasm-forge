/* data_demo.c — Module 03: C helpers for printing raw memory */
#include <stdio.h>
#include <stdint.h>

/* Print N bytes starting at ptr as a hex dump */
void print_hex_dump(const uint8_t *ptr, size_t n)
{
    printf("  bytes: ");
    for (size_t i = 0; i < n; i++)
        printf("%02X ", ptr[i]);
    printf("\n");
}

void print_u64(uint64_t v)
{
    printf("  u64  decimal: %20llu   hex: 0x%016llX\n",
           (unsigned long long)v, (unsigned long long)v);
}

void print_s64(int64_t v)
{
    printf("  s64  decimal: %20lld\n", (long long)v);
}

void print_label(const char *s)
{
    printf("\n=== %s ===\n", s);
}
