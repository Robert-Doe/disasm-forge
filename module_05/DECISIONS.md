# DECISIONS.md — Module 05: Bitwise Operations & Bit Manipulation

## Decision 1: Use binary literals (0b...) for bit-pattern demos

**Decision:** Values like `0b10110011` are used in examples that show individual bit manipulation.
**Why:** Binary literals make the before/after state of individual bits visually obvious without manual conversion. NASM supports `0b` prefix syntax. The alternative (hex) requires the student to mentally convert to binary for each demo.
**Trade-off:** Production assembly almost always uses hex rather than binary literals, because binary is verbose for wide values. Binary is a clarity tool for learning; hex is a practicality tool for production.

## Decision 2: Include SAR vs SHR comparison on the same negative value

**Decision:** Both `sar rax, 3` and `shr rax, 3` are applied to `-128` and both results printed.
**Why:** This is the single most important distinction between the two instructions. The difference (sign-preserving vs zero-filling) is invisible on positive numbers and only manifests on negatives. Seeing the two results side by side makes the distinction unforgettable.
**Trade-off:** A production compiler always uses `sar` for signed right shift and `shr` for unsigned. The student must learn to distinguish them in disassembly to correctly infer whether a variable is signed or unsigned — critical for reverse engineering.

## Decision 3: Show all four BT variants (bt/bts/btr/btc)

**Decision:** All four bit-test-and-modify instructions are demonstrated.
**Why:** These instructions appear frequently in OS and driver code (manipulating hardware register bits, CPU feature flags in CPUID, page table entries). A security researcher reading kernel exploit code must recognise all four. They are also used in lock-free bit arrays.
**Trade-off:** `bt`/`bts`/`btr`/`btc` have a memory-operand form that is non-atomic and surprisingly slow (it uses a bit offset that can reach beyond the byte addressed). Production code that needs atomic bit ops uses the `lock` prefix: `lock bts [mem], reg`. Module 17 (inline asm) covers the `lock` prefix.

## Decision 4: Include the power-of-two test (n & (n-1)) == 0

**Decision:** The idiom for testing if a number is a power of two is shown as a security pattern.
**Why:** This bit trick appears in allocator code (bucket size validation), in hash table implementations, and in exploit mitigations (ASLR entropy checks). Understanding it at the assembly level reveals why it works and where it breaks (n=0 passes the test — a common off-by-one). Module 18 (buffer overflows) references this when discussing heap alignment requirements.
**Trade-off:** A production implementation would add an explicit `n != 0` check before using this idiom, since `0 & (0-1) = 0` falsely identifies zero as a power of two.
