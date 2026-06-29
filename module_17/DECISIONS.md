# DECISIONS.md — Module 17: Inline Assembly & Reading Compiler Output

## Decision 1: Use GCC extended asm (asm volatile) throughout

**Decision:** All inline assembly uses the GCC extended form `asm volatile("template" : outputs : inputs : clobbers)` rather than basic `asm("template")`.
**Why:** The basic form has no operand interface — the programmer must manually pre-load registers and manually read results, and the compiler has no way to know what the snippet reads or writes. The extended form with constraints lets the compiler allocate registers, fold constants, and integrate the snippet into the register allocation pass. Using `volatile` prevents the compiler from eliminating or reordering the snippet even when the output is unused.
**Trade-off:** GCC constraint syntax (`"=r"`, `"a"`, `"c"`, `"0"`) is dense and easy to get wrong. A mismatched constraint is undefined behavior — the compiler may silently produce incorrect code. MSVC uses `__asm { }` blocks with different syntax and is not covered.

## Decision 2: Demonstrate CPUID and RDTSC as "inline-asm-only" examples

**Decision:** CPUID and RDTSC are shown as canonical inline assembly use cases.
**Why:** These are the clearest examples of instructions that C cannot express any other way (without compiler-specific intrinsics). CPUID is essential for detecting CPU features at runtime (SSE4.2, AVX2, AES-NI). RDTSC is used for micro-benchmarking and timing-based crypto side-channel research. Knowing how to invoke them from C without losing the surrounding optimizer context (as you would if you called a separate assembly function) is a practical skill.

## Decision 3: Include plain C functions that compile to interesting assembly

**Decision:** The `multiply_by_5`, `sum_array`, `absolute_value`, `divide_by_8`, and `sum_to_n` functions are plain C, not inline assembly. The lesson is to compile them with `-S -O2` and read the output.
**Why:** Reading compiler output is the most important skill for understanding assembly in real binaries. Disassembly of a compiled binary is the compiler's output, not hand-written code. Recognizing `lea rax,[rdi+rdi*4]` as multiplication by 5, or `sar rax,3` as division by 8, or `cmovns` as a branchless absolute value, is the difference between spending 5 minutes and 5 hours reverse-engineering a function.

## Decision 4: Provide `make compare` to show -O0 vs -O2 side by side

**Decision:** The Makefile includes a `compare` target that generates `-O0` and `-O2` assembly and greps for `multiply_by_5` in both.
**Why:** The pedagogical value is in the contrast. At `-O0`, every C statement compiles to obvious load-operate-store sequences with redundant moves. At `-O2`, the same function may be 2–3 instructions. Seeing this side by side trains the eye to recognize optimized patterns.
