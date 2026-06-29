/* stack_helper.c — Module 07 */
#include <stdio.h>
#include <stdint.h>

void print_u64(uint64_t v) { printf("  val : %llu (0x%llX)\n",(unsigned long long)v,(unsigned long long)v); }
void print_ptr(uint64_t v) { printf("  rsp : 0x%016llX\n",(unsigned long long)v); }
void print_label(const char *s){ printf("\n=== %s ===\n",s); }
