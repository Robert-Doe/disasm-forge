# DECISIONS.md — Module 13: SIMD — SSE, AVX & Packed Data

## Decision 1: Cover SSE2 packed, SSE4.1 blend, and AVX 256-bit

**Decision:** The module demonstrates SSE2 (`addpd`/`mulpd`/`addps`/`paddw`), SSE4.1 (`blendpd`), and AVX (`vaddpd`/`vmulpd`/`vextractf128`).
**Why:** SSE2 is the baseline present on every x86-64 CPU since 2003. SSE4.1 adds important lane-selection operations used heavily in crypto and SIMD parsers. AVX doubles the register width to 256 bits and is present on all CPUs since Sandy Bridge (2011). Together they cover the SIMD spectrum a security engineer encounters in real binaries.
**Trade-off:** AVX-512 (512-bit registers) is excluded — it requires Skylake-X or newer server hardware and the added complexity would obscure the fundamentals.

## Decision 2: Require vzeroupper after AVX

**Decision:** Every code path that uses `ymm` registers ends with `vzeroupper` before calling C helper functions.
**Why:** On Intel CPUs prior to Skylake, mixing AVX (ymm) and SSE2 (xmm) code without `vzeroupper` causes severe performance penalties (up to 100 stall cycles per transition) because the CPU must save and restore the upper 128 bits of every ymm register. `vzeroupper` zeroes all upper bits and avoids the penalty. Forgetting it is a real-world performance regression seen in production code.

## Decision 3: Use aligned loads (movapd/vmovapd/movaps)

**Decision:** All 128-bit and 256-bit loads use the aligned variants (`movapd`, `vmovapd`, `movaps`) because data is declared with `align 16`/`align 32`.
**Why:** Aligned loads are faster than unaligned (`movupd`/`vmovupd`) on older CPUs. More importantly, using aligned loads on unaligned data causes a general-protection fault (#GP) — this makes misalignment bugs immediately visible rather than silently slow. The `align` directive in NASM guarantees the required alignment in `.rodata`.

## Decision 4: Use haddpd for horizontal reduction

**Decision:** The dot-product reduction uses `vextractf128` to get the upper 128 bits, then `addpd` to add upper and lower halves, then `haddpd` to sum the two remaining lanes.
**Why:** This is the canonical three-step horizontal reduction for a 4-wide double dot product. `haddpd` (horizontal add packed double) adds adjacent pairs within the register. It is slow (2 micro-ops on modern Intel) but clear in purpose. Production code would use a different permutation sequence to avoid `haddpd` on latency-sensitive paths.
