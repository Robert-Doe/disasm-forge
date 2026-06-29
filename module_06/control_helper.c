/* control_helper.c — Module 06 */
#include <stdio.h>
#include <stdint.h>

void print_cstr(const char *s) { fputs(s, stdout); }
void print_u64(uint64_t v)     { printf("  %llu\n", (unsigned long long)v); }
void print_label(const char *s){ printf("\n=== %s ===\n", s); }
