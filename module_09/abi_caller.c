/* abi_caller.c — Module 09: C side of ABI demonstration */
#include <stdio.h>
#include <stdint.h>

/* Declared in abi.asm — we call it back from C */
extern uint64_t asm_callback(uint64_t x);

/* 7-argument function: first 6 (Linux) or 4 (Windows) in regs, rest on stack */
uint64_t c_seven_args(uint64_t a1, uint64_t a2, uint64_t a3, uint64_t a4,
                      uint64_t a5, uint64_t a6, uint64_t a7)
{
    printf("  c_seven_args got: %llu %llu %llu %llu %llu %llu %llu\n",
           (unsigned long long)a1,(unsigned long long)a2,
           (unsigned long long)a3,(unsigned long long)a4,
           (unsigned long long)a5,(unsigned long long)a6,
           (unsigned long long)a7);

    /* Call back into asm to prove the round-trip works */
    uint64_t cb = asm_callback(a1);
    printf("  asm_callback(%llu) = %llu\n",(unsigned long long)a1,(unsigned long long)cb);

    return a1+a2+a3+a4+a5+a6+a7;
}

/* Float arguments via xmm0-xmm3 */
int c_float_args(double x0, double x1, double x2, double x3)
{
    printf("  c_float_args got: %.2f %.2f %.2f %.2f\n", x0, x1, x2, x3);
    printf("  sum = %.2f\n", x0+x1+x2+x3);
    return 1;
}

/* Return two values via rax and rdx */
/* In C, we return a struct — the ABI maps this to rax:rdx for small structs */
typedef struct { uint64_t lo; uint64_t hi; } Pair;
Pair c_return_pair(void)
{
    Pair p = { .lo = 0xDEAD, .hi = 0xBEEF };
    return p;
}

void print_label(const char *s){ printf("\n=== %s ===\n", s); }
void print_u64(uint64_t v){ printf("  %llu (0x%llX)\n",(unsigned long long)v,(unsigned long long)v); }
