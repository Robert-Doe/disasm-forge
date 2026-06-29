# DECISIONS.md — Module 04: Arithmetic & the ALU

## Decision 1: Use rbx as the multiplier operand

**Decision:** `mul rbx` is used rather than a memory operand.
**Why:** `mul` requires the source to be a register or memory, not an immediate. Using `rbx` keeps the encoding simple and mirrors what compilers emit for unknown values. Production code occasionally uses memory operands directly.
**Trade-off:** A memory operand (`mul [rel val]`) saves a register move. Compilers often do this; Module 10 covers memory operands fully.

## Decision 2: Show both two-operand and three-operand imul

**Decision:** Both `imul rax, rbx` and `imul rax, rbx, 6` are demonstrated.
**Why:** The three-operand form (`dst = src * imm`) is by far the most common form in compiler output — it avoids clobbering the source. Showing both forms prevents confusion when reading disassembly.
**Trade-off:** There is also a one-operand `imul src` form (rdx:rax = rax * src) analogous to `mul`. It is rarely emitted by compilers but appears in handwritten crypto code.

## Decision 3: Use cqo before idiv (not xor rdx,rdx)

**Decision:** `cqo` is used to set up `rdx:rax` for signed division.
**Why:** `cqo` sign-extends `rax` into `rdx` — if `rax` is negative, `rdx` becomes `0xFFFFFFFFFFFFFFFF`. Using `xor rdx, rdx` would zero `rdx`, making the dividend positive and producing wrong results for negative inputs. This is a very common bug.
**Trade-off:** For unsigned division, `xor rdx, rdx` is correct and preferred. The module shows both contexts to make the rule unambiguous.

## Decision 4: Demonstrate CF vs OF with maximal values

**Decision:** Both flag demos use boundary values (0xFFFF...FFFF for CF, 0x7FFF...FFFF for OF).
**Why:** Using exactly the boundary value makes the flag transition unambiguous — any smaller value would not set the flag. This connects directly to Module 06 where `jo`/`jno` and `jc`/`jnc` are used in conditional branches based on these flags.
**Trade-off:** In production, you rarely need to manually check CF and OF after arithmetic; you use conditional jump instructions immediately after. Module 06 shows the canonical usage pattern.
