/* bits_helper.c — Module 05 */
#include <stdio.h>
#include <stdint.h>

void print_u64(uint64_t v){
    /* print decimal, hex, and binary */
    printf("  0x%016llX  (%llu)\n",(unsigned long long)v,(unsigned long long)v);
}
void print_label(const char *s){
    printf("\n=== %s ===\n",s);
}
