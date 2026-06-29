# DECISIONS.md — Module 12: x87 FPU & SSE2 Scalar Floating Point

## Decision 1: Focus on SSE2 scalar (sd/ss) rather than packed SIMD

**Decision:** All primary examples use `movsd`, `addsd`, `mulsd`, `divsd`, `sqrtsd` (scalar double-precision). Packed SIMD (`addpd`, `mulpd`) is deferred to Module 13.
**Why:** Scalar SSE2 is what compilers emit for ordinary C `double` arithmetic. Understanding scalar operations first avoids conflating two concerns: the xmm register model and the SIMD parallelism. Module 13 (SIMD) builds on this foundation.
**Trade-off:** The `ss` (scalar single-precision) variants work identically but operate on `float` instead of `double`. The only difference is the second letter: `movss`, `addss`, etc. They are not shown separately because the pattern is identical.

## Decision 2: Include x87 FPU despite being legacy

**Decision:** The x87 `fld`/`fmulp`/`fsin`/`fstp` stack-based FPU is demonstrated.
**Why:** x87 is still present in every x86-64 CPU and still appears in disassembly of old binaries, kernel code, and code compiled with `-mfpmath=387`. Security engineers must be able to read x87 sequences. `fsin` is also the only way to compute trigonometric functions in pure assembly without an external library.
**Trade-off:** x87 has complex state (control word, status word, tag word, 80-bit extended precision). The module shows the essentials without exhaustively covering x87 exception handling.

## Decision 3: print_f64 takes double in xmm0 (SSE ABI)

**Decision:** The `print_f64` C helper receives its argument in `xmm0` (System V) or `xmm1` (Windows — but we route through xmm0 with an adapter). For the SHOWf macro, we do `movsd xmm0, <src>` then `call print_f64`.
**Why:** Floating-point arguments to C variadic functions (like `printf`) must go in xmm registers per both the System V and Microsoft x64 ABIs. Passing a float in an integer register would produce garbage output. This is the module where that ABI rule becomes tangible and testable.

## Decision 4: Use ucomisd (not comisd) for float comparison

**Decision:** `ucomisd` is used rather than `comisd`.
**Why:** `ucomisd` (unordered compare) sets the parity flag (PF) on NaN inputs, allowing NaN detection with `jp`. `comisd` (ordered compare) raises a floating-point exception on NaN. In defensive code you almost always want `ucomisd` so NaN values don't cause silent exception-flag corruption. Compilers consistently emit `ucomisd`.
