/* arith_helper.c — Module 04 */
#include <stdio.h>
#include <stdint.h>

void print_u64(uint64_t v){
    printf("  u64: %20llu  (0x%016llX)\n",(unsigned long long)v,(unsigned long long)v);
}
void print_s64(int64_t v){
    printf("  s64: %20lld\n",(long long)v);
}
void print_label(const char *s){
    printf("\n=== %s ===\n",s);
}
void print_two_u64(uint64_t hi, uint64_t lo){
    printf("  128-bit: hi=0x%016llX  lo=0x%016llX\n",
           (unsigned long long)hi,(unsigned long long)lo);
}
