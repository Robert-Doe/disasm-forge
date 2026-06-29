# DECISIONS.md — Module 08: Procedures, Recursion & the Red Zone

## Decision 1: Use push/pop for callee-saved registers rather than storing to [rbp-N]

**Decision:** Callee-saved registers are preserved with `push r12` / `pop r12` pairs rather than `mov [rbp-8], r12` / `mov r12, [rbp-8]`.
**Why:** Push/pop is the canonical way to save callee-saved registers. It is what GCC emits. Using `push` means the stack automatically accounts for the space (rsp moves), so you don't need to calculate offsets manually. It also makes the intent clear in disassembly — a sequence of pushes at the function start and corresponding pops before `ret` is immediately recognisable as register preservation.
**Trade-off:** Storing to `[rbp-N]` gives named offsets which can be clearer when mixing with other locals. Production code optimised for speed sometimes uses neither — it keeps values in registers across calls by reorganising code to avoid needing preservation.

## Decision 2: Implement tail-call as jmp rather than call+ret

**Decision:** `sum_to_tail` uses `jmp sum_to_tail` for the recursive case instead of `call sum_to_tail; ret`.
**Why:** A tail call is a recursive call where the return value of the recursive call is immediately returned without modification. The current frame is no longer needed once the recursive call is made. Replacing `call+ret` with `jmp` reuses the current frame — stack depth stays O(1) instead of O(n). GCC `-O2` performs this transformation automatically; students must recognise it in disassembly (a function that jumps to itself or to another function with no `ret` between the `call` and the following `ret`).
**Trade-off:** Tail call optimisation makes debugging harder — the caller's frame is gone by the time you break inside. GDB's `backtrace` will be truncated. LLVM's `-fno-tail-calls` flag disables this for debugging. Module 18 mentions this when discussing crash dump analysis.

## Decision 3: Demonstrate the red zone with a leaf function (no sub rsp)

**Decision:** `red_zone_leaf` uses `[rsp-8]` through `[rsp-24]` directly without adjusting `rsp`.
**Why:** The red zone is specifically the 128 bytes below `rsp` that the System V ABI guarantees will not be touched by signal handlers for leaf functions (functions that make no further calls). Using it saves the `sub rsp, N` / `add rsp, N` overhead in very hot leaf functions. The CPU cannot distinguish "real" stack from red zone — it is purely an ABI contract.
**Trade-off:** The red zone does NOT exist in the Windows x64 ABI. Code using the red zone will break if compiled for Windows or if used in kernel mode (where interrupt handlers can fire and clobber it). Module 09 flags this distinction explicitly.

## Decision 4: Return two values via rax and rdx in divmod

**Decision:** `divmod` returns quotient in `rax` and remainder in `rdx`, which is a natural fit since `div` already produces results in those registers.
**Why:** The System V ABI allows up to two return values: the first in `rax`, the second in `rdx`. This is how GCC returns a 128-bit integer (high in `rdx`, low in `rax`) and how some functions return a pair of pointers. Using `div`'s natural output (`rax` quotient, `rdx` remainder) requires zero extra instructions — it is the most efficient possible two-value return.
**Trade-off:** The Microsoft x64 ABI also supports `rax`/`rdx` for two-value returns, but the calling convention for larger structs differs (passed by hidden pointer). Module 09 covers struct return in full.
