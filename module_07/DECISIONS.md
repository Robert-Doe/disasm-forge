# DECISIONS.md — Module 07: The Call Stack

## Decision 1: Print rsp at each nesting level rather than just describing it

**Decision:** Each of `level_a`, `level_b`, `level_c` prints its own `rsp` value live.
**Why:** Seeing the numeric address decrease by ~32 bytes at each call level makes the stack growth direction concrete and measurable. The student can verify the frame size matches the `sub rsp, N` instruction in each function. Abstract descriptions of "the stack grows down" become undeniable facts when you see addresses like `0x7fff_ffff_fef0`, `0x7fff_ffff_fec0`, `0x7fff_ffff_feb0`.
**Trade-off:** The exact addresses vary per run (ASLR) and per OS. A production debugging session uses GDB's `info frame` and `backtrace` rather than print statements. Module 18 uses GDB exclusively for stack inspection.

## Decision 2: Use sub rsp,16 for local space in nested functions (not just 8)

**Decision:** Each nested function allocates 16 bytes even though only 8 are used.
**Why:** The System V AMD64 ABI requires `rsp` to be 16-byte aligned before any `call` instruction. If `level_b` allocated only 8 bytes (`sub rsp, 8`) then before the `call level_c`, `rsp` would be misaligned (off by 8 from 16-byte alignment), which can cause SIMD instructions inside `level_c` (or functions it calls) to crash with #GP. Allocating 16 ensures alignment is maintained.
**Trade-off:** The Windows x64 ABI has the same alignment requirement plus the 32-byte shadow space. Module 09 covers both ABIs and their alignment rules in exhaustive detail.

## Decision 3: Use add_two with Linux ABI (rdi/rsi) but also set rcx/rdx for Windows

**Decision:** `add_two` reads `rdi` and `rsi` (Linux ABI), but `main` sets both `rdi`/`rsi` and `rcx`/`rdx` before the call.
**Why:** This module focuses on stack mechanics, not ABI. Setting both register sets means the binary works on Linux without modification and produces a correct result on Windows (which uses `rcx`/`rdx`). The mismatch means `add_two` reads stale values on Windows — it gets `rcx` via `rdi` which holds garbage. This intentional imperfection is a preview of Module 09.
**Trade-off:** Module 09 fixes this properly with platform-conditional assembly (`%ifdef WIN64`) and explains the complete calling convention for both platforms.

## Decision 4: Use leave equivalent (add rsp + pop rbp) explicitly rather than the leave instruction

**Decision:** The epilogue spells out `add rsp, N` + `pop rbp` rather than using `leave`.
**Why:** `leave` is equivalent to `mov rsp, rbp; pop rbp` — it restores `rsp` from `rbp` and pops the saved `rbp`. However, using explicit `add rsp, N` makes the frame size immediately visible and ties back to the `sub rsp, N` in the prologue. `leave` hides the frame size. Students should see the pairing explicitly before being shown the shorthand.
**Trade-off:** GCC with `-O0` emits `leave` for simplicity. GCC with `-O2` often avoids the frame pointer entirely (using `-fomit-frame-pointer`) and adjusts `rsp` directly. Module 18 shows both in disassembly.
