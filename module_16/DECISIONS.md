# DECISIONS.md — Module 16: Linker & Loader Internals

## Decision 1: Split across two .asm files with bidirectional dependencies

**Decision:** a.asm calls `b_add` (from b.asm) and b.asm calls `a_multiply` (from a.asm), creating a bidirectional dependency graph.
**Why:** A one-way dependency would suggest the linker works sequentially. Bidirectional cross-unit references demonstrate the two-pass nature of linking: the linker first collects all symbol definitions from all object files, then goes back and patches all reference sites. This is why traditional linkers require all symbols to be resolvable at link time (unlike dynamic linkers which can resolve lazily at runtime).
**Trade-off:** Circular dependencies between modules are legal for linking but can create initialization-order problems for C++ global constructors. Assembly has no constructors, so the demo is unambiguous.

## Decision 2: Export b_counter as a mutable global

**Decision:** `b_counter dq 100` in b.asm's `.data` section is declared `global b_counter` so both a.asm and link_helper.c can read and write it.
**Why:** Global variables shared across compilation units require the linker to place them at a single address that all units can find. This demonstrates that the linker's job is not just about function calls — it resolves data symbol references too. The C code reading `b_counter` directly shows that the same mechanism works across language boundaries (C + assembly).

## Decision 3: Show objdump -r output (make relocs target)

**Decision:** The Makefile includes a `make relocs` target that runs `objdump -r` on each object file before linking.
**Why:** Seeing the raw relocation entries in object files is the key insight of this module. A relocation entry says "at this file offset, write the address of this symbol (possibly with an addend)." Until the linker runs, these offsets contain zeros or placeholder values. The `objdump -r` output makes this explicit and tangible.

## Decision 4: Add c_link_demo() called from link_helper.c rather than a.asm

**Decision:** The C function `c_link_demo()` calls assembly symbols, rather than adding more assembly code to a.asm.
**Why:** The point of this module is that the linker works uniformly across object files regardless of source language. Showing C code calling assembly symbols (and the symbols appearing with the same addresses in both `nm` output and the C `printf`) demonstrates that there is no "C-to-assembly bridge" — they share the same symbol table and the same relocation mechanism.
