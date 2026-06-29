# DECISIONS.md — Module 02: Registers

---

## Decision 1: Set both rdi and rcx before every C helper call

**Decision:** The SHOW/LABEL macros set both `rdi` (Linux first arg) and `rcx` (Windows first arg) before calling `print_u64` and `print_label`.

**Why:** This module must run on both platforms without two separate `.asm` files. Until the student reaches Module 09 (Calling Conventions), they should not be distracted by platform differences. Setting both registers is harmless — the callee simply ignores whichever one is not the argument register for that platform.

**Trade-off:** Real cross-platform asm code uses conditional assembly (`%ifdef WIN64`) rather than setting unused registers. Module 09 introduces this cleanly with platform-specific `%ifdef` blocks and explains the full ABI for each platform.

---

## Decision 2: Demonstrate sub-register aliasing with a recognisable bit pattern

**Decision:** All sub-register demos start with `0xAAAAAAAAAAAAAAAA` as the initial value of `rax`.

**Why:** `0xAA` repeated is visually distinctive in hex output. When `al` is written to `0x11`, the result `0xAAAAAAAAAAAAAA11` makes it immediately obvious which byte changed and which bytes were preserved. A pattern like `0xFFFFFFFFFFFFFFFF` obscures partial writes.

**Trade-off:** In production code you normally don't rely on partial register writes — compilers avoid them because they create false dependencies between instructions on modern out-of-order CPUs (a stall called a "partial register update penalty"). Module 04 addresses dependency chains when discussing `adc`/`sbb`.

---

## Decision 3: Include shadow space allocation even on Linux

**Decision:** `sub rsp, 32` (Windows shadow space) is emitted in `main` even when assembling for Linux.

**Why:** Linux ignores the extra stack reservation — it just wastes 32 bytes temporarily. Having a single asm file that assembles correctly on both platforms means the student can copy their work between environments. The trade-off of 32 wasted stack bytes is zero cost for a learning exercise.

**Trade-off:** Production cross-platform asm uses `%ifdef WIN64` to emit shadow space only on Windows. This is introduced in Module 09 where platform differences become central.

---

## Decision 4: Explain xor eax,eax before introducing rflags fully

**Decision:** The zero-extension rule is demonstrated before the full flags register explanation (which comes in Module 04).

**Why:** `xor eax, eax` sets ZF (zero flag) as a side effect. Mentioning this here would require a premature detour into `rflags`. The student needs to know the idiom and its encoding size advantage now; the flags side effect is noted in DECISIONS but not taught in the tutorial until Module 04.

**Trade-off:** The POSIX standard `_Exit` function and setjmp/longjmp both depend on flags state between calls, which is why production code must not assume flags are preserved across any function call. Module 06 covers this when teaching `cmp`/`test`.
