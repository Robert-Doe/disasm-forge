# DECISIONS.md — Module 10: Memory Addressing Modes

## Decision 1: Use [rel label] for all data accesses

**Decision:** Every `.data`/`.rodata` access uses `[rel label]` (RIP-relative) rather than an absolute 64-bit address.
**Why:** 64-bit Linux binaries compiled with `-no-pie` can use absolute addresses, but Position-Independent Executables (PIE) — the default on modern Linux — require RIP-relative addressing. Using `[rel ...]` everywhere makes the code correct under both modes and teaches the right habit. It also reflects what compilers always emit.
**Trade-off:** NASM requires the `rel` keyword explicitly (unlike GAS which can be configured to default to RIP-relative). NASM's `default rel` directive can be placed at the top of a file to make all `[]` accesses RIP-relative by default, avoiding the per-access `rel` keyword.

## Decision 2: Use `equ` constants (COLS, ELEM) for array stride

**Decision:** `COLS equ 4` and `ELEM equ 4` are defined at assembly time rather than hardcoding `16` as the row stride.
**Why:** Compile-time constants make the relationship between dimensions and element size explicit and maintainable. If the element type changed from `int32_t` to `int64_t`, only `ELEM` needs updating. This mirrors `sizeof` in C and prevents the "magic number" anti-pattern.
**Trade-off:** Production assembly for generic functions receives strides as runtime arguments (in registers), not compile-time constants. The `imul` instruction computes runtime strides, as shown in the 2D loop.

## Decision 3: Demonstrate LEA as a multiply trick (multiply by 5)

**Decision:** `lea rax, [rdi + rdi*4]` is shown as a way to multiply by 5 without `imul`.
**Why:** This is a real compiler optimisation. GCC `-O2` frequently emits `lea` for multiplying by constants that can be expressed as `a + a*b` where b ∈ {1,2,4,8}. Recognising it in disassembly is essential for reverse engineers — what looks like an address computation is actually a multiply.
**Trade-off:** Modern CPUs (since Haswell) have fast `imul` with 3-cycle latency. The `lea` trick saves an instruction but `imul` is often equally fast. The compiler still prefers `lea` for small constants because it avoids the latency of reading a memory operand.

## Decision 4: Show movzx for sub-register loads

**Decision:** `movzx rax, byte [rbx]` is used instead of `mov al, [rbx]` for loading a byte.
**Why:** `mov al, [rbx]` only writes the low 8 bits of `rax` and does NOT zero-extend (Module 02). If `rax` held garbage in bits 8–63, those bits survive after `mov al, ...`. Using `movzx` explicitly loads and zero-extends in one instruction, giving a clean 64-bit result. Compilers always emit `movzx` for unsigned byte/word loads.
**Trade-off:** `movsx` (Move with Sign-Extension) is the signed equivalent. A `signed char` field loaded with `movzx` would produce a wrong value for negative bytes. Module 11 (C Pointers & Structs) shows where the compiler chooses `movsx` vs `movzx` based on the C type declaration.
