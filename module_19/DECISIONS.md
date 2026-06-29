# DECISIONS.md — Module 19: Reading Disassembly & Reverse Engineering Patterns

## Decision 1: Compile targets stripped at -O2, provide debug builds for comparison

**Decision:** The RE targets are compiled with `-O2 -s` (optimized + stripped). Debug builds with `-O0 -g` are also available but should only be consulted after attempting analysis.
**Why:** Stripped, optimized binaries are what real reverse engineering targets look like. The gap between C source and stripped `-O2` assembly is where RE skill lives. Debug symbols eliminate the challenge. The two-build approach lets students verify their analysis by comparing their reconstructed logic against the debug build's symbol names after solving.
**Trade-off:** Optimized code is harder to read than `-O0` output. The four targets are chosen so their optimized output is challenging but tractable for a student who has completed Modules 01–17.

## Decision 2: Four targets — cipher, recursive, state machine, crackme

**Decision:** Each target emphasizes a different RE pattern class:
- **cipher**: loop + modulo + XOR (very common in malware, packers, custom protocols)
- **recursive**: identifying recursion vs iteration in disassembly, TCO recognition
- **state machine**: switch/jump table dispatch, state variable tracking
- **crackme**: multi-condition validation, finding the inverse (what input satisfies all checks)

**Why:** These four patterns account for the majority of structure a reverse engineer encounters in non-trivial binaries. Recognizing each on sight — and knowing what questions to ask — is a transferable skill.

## Decision 3: Crackme has multiple valid keys (satisfying simultaneous constraints)

**Decision:** The crackme's validation is a set of constraints with multiple valid solutions rather than a single hardcoded string comparison.
**Why:** Single string comparisons (`strcmp(key, "secret123")`) are trivially identified in disassembly via the string literal in `.rodata`. Real license validators compute constraints. Understanding that the RE task is to enumerate the constraint set and solve it algebraically (or via scripted search) is the professional-level insight.

## Decision 4: Makefile targets for `disasm-*` and `run-all`

**Decision:** The Makefile provides dedicated `make disasm-cipher` etc. targets that run `objdump -d -M intel`.
**Why:** `-M intel` selects Intel syntax (destination on left, no `%` register prefix) which matches the NASM syntax taught throughout the course. GAS/AT&T syntax (the objdump default) would create unnecessary context-switching for students trained on NASM.
