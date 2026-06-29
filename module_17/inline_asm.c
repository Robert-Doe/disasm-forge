/*
 * inline_asm.c — Module 17: Inline Assembly & Reading Compiler Output
 *
 * Demonstrates GCC extended inline assembly asm volatile(...) with:
 *   - Output constraints ("%0", "=r")
 *   - Input constraints ("%1", "%2", "r")
 *   - Memory/register clobbers
 *   - The cpuid instruction (requires inline asm — no intrinsic)
 *   - rdtsc (read time-stamp counter)
 *   - Compiler optimization patterns visible in -S output
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

/* ── Section 1: Basic extended inline assembly ──────────────────────────── */

/*
 * add_asm — adds two int64_t values using an inline add instruction.
 * Demonstrates: output constraint "=r" (any register), input constraint "r".
 *
 * Template:  "addq %2, %0"
 * Outputs:   "=r"(result)   → compiler picks a register for result
 * Inputs:    "0"(a)         → same register as output (combined)
 *            "r"(b)         → any register for b
 */
static int64_t add_asm(int64_t a, int64_t b) {
    int64_t result;
    asm volatile (
        "addq %2, %0"
        : "=r"(result)       /* output: result → any register */
        : "0"(a), "r"(b)     /* input:  0=same reg as output, r=any reg */
        :                    /* clobbers: none */
    );
    return result;
}

/*
 * mul_wide — multiplies two uint64_t values, returning the full 128-bit
 * result as two separate uint64_t values (hi:lo).
 * Uses the MUL instruction which writes rdx:rax implicitly.
 *
 * Clobber "rdx" tells the compiler that rdx is modified.
 */
static void mul_wide(uint64_t a, uint64_t b, uint64_t *hi, uint64_t *lo) {
    uint64_t h, l;
    asm volatile (
        "mulq %3"            /* rax *= %3; result in rdx:rax */
        : "=d"(h),           /* output: "d" = rdx register */
          "=a"(l)            /* output: "a" = rax register */
        : "a"(a),            /* input:  "a" = rax = a */
          "r"(b)             /* input:  "r" = any register for b */
        :                    /* no additional clobbers — d and a already listed */
    );
    *hi = h;
    *lo = l;
}

/*
 * bswap64 — byte-swap a 64-bit value using the BSWAP instruction.
 * bswap is used to convert between big-endian and little-endian.
 */
static uint64_t bswap64(uint64_t x) {
    uint64_t result;
    asm volatile (
        "bswap %0"
        : "=r"(result)
        : "0"(x)
    );
    return result;
}

/*
 * rotate_left_32 — rotate left by count bits using ROR/ROL.
 * "c" constraint maps to the cl register (only shift register allowed).
 */
static uint32_t rotate_left_32(uint32_t x, unsigned int count) {
    uint32_t result;
    asm volatile (
        "roll %b1, %0"       /* roll cl, r/m32  — %b1 = byte-sized %1 = cl */
        : "=r"(result)
        : "0"(x), "c"(count) /* "c" forces count into rcx/ecx/cx/cl */
    );
    return result;
}

/* ── Section 2: Hardware intrinsics only available via inline asm ─────── */

/*
 * read_cpuid — executes CPUID with leaf in eax.
 * Returns all four output registers: eax, ebx, ecx, edx.
 */
static void read_cpuid(uint32_t leaf,
                       uint32_t *out_eax, uint32_t *out_ebx,
                       uint32_t *out_ecx, uint32_t *out_edx) {
    uint32_t a, b, c, d;
    asm volatile (
        "cpuid"
        : "=a"(a), "=b"(b), "=c"(c), "=d"(d)
        : "a"(leaf), "c"(0)   /* leaf in eax, subleaf 0 in ecx */
        :                     /* cpuid doesn't clobber memory */
    );
    *out_eax = a;
    *out_ebx = b;
    *out_ecx = c;
    *out_edx = d;
}

/*
 * read_rdtsc — reads the CPU timestamp counter (TSC).
 * Returns a 64-bit cycle count. Used for micro-benchmarking.
 * rdtsc writes low 32 bits into eax, high 32 bits into edx.
 */
static uint64_t read_rdtsc(void) {
    uint32_t lo, hi;
    asm volatile (
        "rdtsc"
        : "=a"(lo), "=d"(hi)
        :
        : /* rdtsc does not clobber other registers */
    );
    return ((uint64_t)hi << 32) | lo;
}

/*
 * read_rflags — reads the current RFLAGS register.
 * Uses pushfq (push rflags) then pops into a register.
 * "memory" clobber tells compiler to flush/reload memory around this point.
 */
static uint64_t read_rflags(void) {
    uint64_t flags;
    asm volatile (
        "pushfq\n\t"
        "pop %0"
        : "=r"(flags)
        :
        : "memory"
    );
    return flags;
}

/* ── Section 3: Compiler optimization patterns ──────────────────────────── */

/*
 * The following functions are written in plain C.
 * Compile with:  gcc -S -O2 inline_asm.c -o inline_asm.s
 * Then examine inline_asm.s to see the optimized assembly output.
 *
 * Patterns to observe:
 *   - multiply_by_5: compiler emits lea rax,[rdi+rdi*4] (not imul)
 *   - sum_loop: compiler may unroll or vectorize
 *   - tail_recursive: compiler may emit a jmp loop (tail call elim)
 */

/* Compiler emits: lea rax, [rdi + rdi*4] at -O2 */
uint64_t multiply_by_5(uint64_t x) {
    return x * 5;
}

/* Compiler may unroll or auto-vectorize with SSE2 at -O2 */
uint64_t sum_array(const uint64_t *arr, size_t n) {
    uint64_t sum = 0;
    for (size_t i = 0; i < n; i++)
        sum += arr[i];
    return sum;
}

/* Compiler emits a conditional move (cmov) to avoid branch at -O2 */
int64_t absolute_value(int64_t x) {
    return x < 0 ? -x : x;
}

/* Compiler emits a direct jmp (tail call) at -O2 if it recognizes the pattern */
static uint64_t sum_tail(uint64_t n, uint64_t acc) {
    if (n == 0) return acc;
    return sum_tail(n - 1, acc + n);
}
uint64_t sum_to_n(uint64_t n) {
    return sum_tail(n, 0);
}

/* Compiler strength-reduces x/8 to sar rax,3 at -O2 */
int64_t divide_by_8(int64_t x) {
    return x / 8;
}

/* ── main ─────────────────────────────────────────────────────────────────── */

int main(void) {
    /* ── Inline asm: basic add ───────────────────────────────────────────── */
    printf("=== Inline asm: addq ===\n");
    int64_t sum = add_asm(100, 42);
    printf("  add_asm(100, 42) = %lld\n", (long long)sum);

    /* ── 128-bit multiply ────────────────────────────────────────────────── */
    printf("\n=== Inline asm: 128-bit multiply via mulq ===\n");
    uint64_t hi, lo;
    mul_wide(0xFFFFFFFFFFFFFFFFULL, 2ULL, &hi, &lo);
    printf("  0xFFFFFFFFFFFFFFFF * 2:\n");
    printf("    hi = 0x%llX\n", (unsigned long long)hi);
    printf("    lo = 0x%llX\n", (unsigned long long)lo);
    /* Expected: 0x1:0xFFFFFFFFFFFFFFFE */

    /* ── bswap ───────────────────────────────────────────────────────────── */
    printf("\n=== Inline asm: bswap (endian flip) ===\n");
    uint64_t val = 0x0102030405060708ULL;
    uint64_t swapped = bswap64(val);
    printf("  bswap(0x%016llX) = 0x%016llX\n",
           (unsigned long long)val, (unsigned long long)swapped);

    /* ── rotate left ─────────────────────────────────────────────────────── */
    printf("\n=== Inline asm: rotate left 32-bit ===\n");
    uint32_t rotated = rotate_left_32(0x80000001U, 1);
    printf("  rol(0x80000001, 1) = 0x%08X (expect 0x00000003)\n", rotated);

    /* ── cpuid ───────────────────────────────────────────────────────────── */
    printf("\n=== Inline asm: cpuid (leaf 0 = vendor string) ===\n");
    uint32_t eax, ebx, ecx, edx;
    read_cpuid(0, &eax, &ebx, &ecx, &edx);
    /* Vendor string is 12 bytes: ebx, edx, ecx in that order */
    char vendor[13] = {0};
    memcpy(vendor + 0, &ebx, 4);
    memcpy(vendor + 4, &edx, 4);
    memcpy(vendor + 8, &ecx, 4);
    printf("  Max leaf: %u\n", eax);
    printf("  Vendor:   %s\n", vendor);

    /* ── rdtsc ───────────────────────────────────────────────────────────── */
    printf("\n=== Inline asm: rdtsc (cycle counter) ===\n");
    uint64_t t1 = read_rdtsc();
    /* Do some work between measurements */
    volatile uint64_t dummy = 0;
    for (int i = 0; i < 1000; i++) dummy += i;
    uint64_t t2 = read_rdtsc();
    printf("  Start TSC:  0x%016llX\n", (unsigned long long)t1);
    printf("  End TSC:    0x%016llX\n", (unsigned long long)t2);
    printf("  Elapsed:    %llu cycles\n", (unsigned long long)(t2 - t1));

    /* ── rflags ──────────────────────────────────────────────────────────── */
    printf("\n=== Inline asm: rflags ===\n");
    uint64_t flags = read_rflags();
    printf("  RFLAGS = 0x%016llX\n", (unsigned long long)flags);
    printf("  CF=%llu  PF=%llu  ZF=%llu  SF=%llu  IF=%llu  DF=%llu  OF=%llu\n",
           (flags >> 0) & 1, (flags >> 2) & 1,
           (flags >> 6) & 1, (flags >> 7) & 1,
           (flags >> 9) & 1, (flags >> 10) & 1,
           (flags >> 11) & 1);

    /* ── Compiler optimization demos ─────────────────────────────────────── */
    printf("\n=== Compiler optimizations (compile -S -O2 to inspect) ===\n");
    printf("  multiply_by_5(7)       = %llu (look for lea in .s)\n",
           (unsigned long long)multiply_by_5(7));

    const uint64_t arr[] = {1, 2, 3, 4, 5, 6, 7, 8};
    printf("  sum_array([1..8])      = %llu (look for vectorized loop)\n",
           (unsigned long long)sum_array(arr, 8));

    printf("  absolute_value(-42)    = %lld (look for cmov)\n",
           (long long)absolute_value(-42));

    printf("  sum_to_n(100)          = %llu (look for tail-call jmp)\n",
           (unsigned long long)sum_to_n(100));

    printf("  divide_by_8(-16)       = %lld (look for sar + cdq trick)\n",
           (long long)divide_by_8(-16));

    return 0;
}
