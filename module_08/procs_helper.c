/* procs_helper.c — Module 08 */
#include <stdio.h>
#include <stdint.h>
void print_u64(uint64_t v){ printf("  %llu (0x%llX)\n",(unsigned long long)v,(unsigned long long)v); }
void print_s64(int64_t v) { printf("  %lld\n",(long long)v); }
void print_label(const char *s){ printf("\n=== %s ===\n",s); }
