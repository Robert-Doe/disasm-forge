# DECISIONS.md — Module 06: Control Flow

## Decision 1: Use local labels (.label) for control flow within main

**Decision:** Labels inside `main` use the NASM local label convention (`.name`) rather than unique global names.
**Why:** Local labels are scoped to the most recent global label. This avoids polluting the global symbol table and mirrors what assemblers produce for compiler-generated code — disassembly of GCC output shows local jump targets as address offsets, not named labels.
**Trade-off:** Local labels make it impossible to set a GDB breakpoint by name (you need to use the address). A production project with many functions would use global labels or a naming convention like `funcname_looptop`.

## Decision 2: Implement switch as a data jump table in .data, not in .text

**Decision:** `jump_table` is placed in `.data` (read-write) rather than `.text` (read-only executable).
**Why:** On Linux with `-no-pie`, absolute 64-bit addresses in a jump table that lives in `.data` are resolved at link time. If placed in `.text`, some toolchains refuse to relocate read-only executable pages. For clarity, keeping data in `.data` and code in `.text` is the pedagogically correct separation.
**Trade-off:** A production compiler (GCC with `-O2 -fpic`) emits position-independent jump tables using RIP-relative addressing and places them in `.rodata`. This requires computing the offset from the table base to each case, not storing absolute addresses. Module 10 (Addressing Modes) introduces RIP-relative addressing fully.

## Decision 3: Use dec+jnz rather than the loop instruction

**Decision:** The for-loop uses `dec rcx` + `jnz .for_loop` instead of the `loop` instruction.
**Why:** The `loop` instruction (decrement `rcx`, jump if non-zero) exists but is slower than `dec`+`jnz` on all modern microarchitectures because it cannot be macro-fused with the preceding instruction. No production compiler emits `loop`. Students must recognise both forms in legacy disassembly but should write `dec`+`jnz`.
**Trade-off:** `loop` saves one byte of encoding. In the late 1980s, size mattered more than speed. Modern assembly favours `dec`+`jnz` without exception.

## Decision 4: Demonstrate classify loop over multiple values rather than a single if-chain

**Decision:** The if/else demo iterates r12 from -5 to +1 so the student sees all three branches execute.
**Why:** A single static value would make the untaken branches invisible. Running the classifier over multiple values proves that all three branches are reachable and that the condition logic is correct. This also demonstrates that assembly loops and conditional branches compose naturally.
**Trade-off:** A real if-chain for classification would use a lookup table (one memory access) rather than three branches. Module 20 (Capstone) shows this optimisation in the disassembler's opcode dispatch.
