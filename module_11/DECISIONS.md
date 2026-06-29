# DECISIONS.md — Module 11: String & Array Operations

## Decision 1: Show both manual loop and rep-prefix versions of strlen

**Decision:** `asm_strlen` uses a manual `cmp byte [rdi+rax], 0` / `inc rax` loop, while `asm_strlen_rep` uses `repne scasb`.
**Why:** The manual loop makes the algorithm maximally legible and maps directly to what a compiler emits at `-O0`. The `repne scasb` version shows how a single prefixed instruction encodes the same logic. Security engineers encounter both in disassembly (the `rep` form appears in libc's hand-optimized strlen).
**Trade-off:** `repne scasb` is rarely faster than a well-pipelined manual loop on modern CPUs; libc strlen uses SSE2/AVX2 16/32-byte comparisons for real throughput. The purpose here is instruction-level understanding, not maximum throughput.

## Decision 2: Implement memset using rep stosb

**Decision:** `asm_memset` uses `rep stosb` (store AL into [rdi], count in rcx).
**Why:** `rep stosb` is the canonical single-byte fill instruction and is hardware-accelerated (on modern Intel it triggers the "fast string" microcode path when the destination is naturally aligned and rcx is large). Learning it teaches both the REP prefix mechanics and the direction flag (DF) convention.
**Trade-off:** Production memset uses `rep stosd` or `movdqu`/`vmovdqu` for aligned 4/16/32-byte fills. For correctness demos the byte form is sufficient.

## Decision 3: Demonstrate repe cmpsb for mismatch position detection

**Decision:** `repe cmpsb` is used to find the index of the first byte difference between two strings, then rdi/rsi arithmetic recovers the mismatch index.
**Why:** `repe cmpsb` is the instruction underlying `memcmp` in older libc implementations and appears frequently in hand-written security tools (e.g., constant-time comparison wrappers). Understanding what the CPU does on termination (rdi/rsi pointing one past the mismatch, rcx containing remaining count) is essential for reading disassembly of such routines.
**Trade-off:** Modern libc `memcmp` uses SIMD; `repe cmpsb` is scalar and slower but far more readable.

## Decision 4: ABI wrapper via %ifdef WIN64

**Decision:** All exported functions test `%ifdef WIN64` and move Windows ABI arguments (rcx, rdx, r8) into Linux ABI registers (rdi, rsi, rdx) at entry.
**Why:** The `rep` string instructions are hardwired to use rdi/rsi/rcx/al as their operand registers. These overlap partially with the Windows ABI argument registers (rcx, rdx, r8, r9), making the ABI fixup unavoidable — the string instructions will consume rcx as the count, so it must be set up correctly regardless of which ABI was used to call us.
