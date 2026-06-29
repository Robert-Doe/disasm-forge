/* link_helper.c — Module 16
 *
 * Provides print helpers and demonstrates PLT/GOT indirection:
 * calling printf from C invokes the dynamic linker's PLT stub on first call.
 *
 * Also demonstrates extern declarations from assembly:
 *   a_multiply and a_message are defined in a.asm, used here.
 */
#include <stdio.h>
#include <stdint.h>

/* Symbols exported from a.asm */
extern int64_t a_multiply(int64_t x, int64_t y);
extern const char a_message[];

/* Symbols exported from b.asm */
extern int64_t b_add(int64_t x, int64_t y);
extern int64_t b_counter;
extern void    b_demo(void);

void print_u64(uint64_t v) {
    printf("  val: %-20llu  0x%llX\n",
           (unsigned long long)v, (unsigned long long)v);
}

void print_label(const char *s) {
    printf("\n=== %s ===\n", s);
}

/*
 * c_link_demo — shows C calling assembly and assembly symbols visible from C.
 * This is called from main in a.asm after all assembly demos.
 */
void c_link_demo(void) {
    printf("\n=== C calling assembly functions (PLT demo) ===\n");

    /* C calling a.asm's a_multiply via normal function call */
    int64_t r1 = a_multiply(11, 4);
    printf("  a_multiply(11,4) = %lld\n", (long long)r1);

    /* C reading a_message from a.asm's .rodata */
    printf("  a_message = \"%s\"\n", a_message);

    /* C reading b_counter (mutable global in b.asm) */
    printf("  b_counter = %lld\n", (long long)b_counter);

    /* C calling b_add */
    int64_t r2 = b_add(100, 23);
    printf("  b_add(100,23) = %lld\n", (long long)r2);

    /* b_demo calls back into a.asm — circular cross-unit references */
    b_demo();

    printf("\n=== Symbol addresses seen from C ===\n");
    printf("  &a_multiply = %p\n", (void *)a_multiply);
    printf("  &b_add      = %p\n", (void *)b_add);
    printf("  &a_message  = %p\n", (const void *)a_message);
    printf("  &b_counter  = %p\n", (void *)&b_counter);
}
