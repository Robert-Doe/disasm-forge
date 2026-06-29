/*
 * target_recursive.c — Module 19: RE Target 2
 *
 * A recursive function with an interesting base case and accumulator.
 * At -O2 the compiler may apply tail-call optimization converting
 * the recursion to a loop — the disassembly will show a jmp back
 * to the function's top rather than a call + ret.
 *
 * Exercise: From the disassembly, determine:
 *   1. What is the base case?
 *   2. What does each recursive call add to the result?
 *   3. What mathematical sequence does this compute?
 *   4. Did the compiler apply tail-call optimization?
 */
#include <stdio.h>
#include <stdint.h>

static uint64_t mystery(uint64_t n, uint64_t acc) {
    if (n == 0) return acc;
    return mystery(n - 1, acc + (n * n));   /* sum of squares: 1²+2²+…+n² */
}

static uint64_t fib(uint64_t n) {
    if (n <= 1) return n;
    return fib(n - 1) + fib(n - 2);   /* classic Fibonacci — NOT tail-call */
}

int main(void) {
    /* mystery: sum of squares */
    for (uint64_t n = 0; n <= 10; n++)
        printf("mystery(%llu) = %llu\n", (unsigned long long)n,
               (unsigned long long)mystery(n, 0));

    printf("\n");

    /* fib: exponential recursion — compiler cannot tail-call optimise */
    for (uint64_t n = 0; n <= 15; n++)
        printf("fib(%llu) = %llu\n", (unsigned long long)n,
               (unsigned long long)fib(n));

    return 0;
}
