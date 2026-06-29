# DECISIONS.md — Module 03: Data Representation & Memory

---

## Decision 1: Use .rodata for string labels, .data for numeric data

**Decision:** String labels used only for printing are placed in `.rodata`; mutable numeric values go in `.data`.

**Why:** `.rodata` is mapped read-only at runtime. If the program tries to write to it, the OS raises a segfault. Placing constants there is both correct and a useful demonstration that sections have enforcement-level memory permissions — not just conventions. It also mirrors what production compilers (GCC, Clang) do with string literals.

**Trade-off:** On Windows with PE binaries, `.rodata` is merged into `.rdata` by MSVC. NASM targeting `win64` still names it `.rodata` and the MinGW linker handles the merge. A truly cross-platform project would use `.rdata` explicitly on Windows. This matters only when mixing NASM with MSVC toolchains.

---

## Decision 2: Use the `$ - label` idiom for byte counts

**Decision:** `byte_count equ $ - byte_vals` computes the size of a data block at assembly time rather than hard-coding a number.

**Why:** If a student adds more entries to `byte_vals`, the count updates automatically. This is the standard NASM idiom — `$` is the current assembly position, so `$ - label` gives the number of bytes assembled since `label`. Hard-coding sizes creates a maintenance hazard and a common security bug (size not updated when data grows).

**Trade-off:** POSIX C uses `sizeof(array)` for the same purpose. In C, `sizeof` is computed at compile time. The NASM `$ - label` trick is the assembly equivalent. A production assembler project would put sizes in a separate `.h` file shared with any C code that needs them.

---

## Decision 3: Show IEEE 754 via dd 1.0 rather than the raw hex

**Decision:** `float_one dd 1.0` is used instead of `float_one dd 0x3F800000`.

**Why:** NASM accepts floating-point literals in `dd` and `dq` directives. Using `1.0` makes the intent clear and lets the student discover the bit pattern (0x3F800000) by running the hex dump — a more memorable experience than just being told the answer. The exercise asks the student to decode the exponent and mantissa fields.

**Trade-off:** Production code that embeds float constants in data sections usually uses the raw hex so the value is unambiguous across different assembler implementations. NASM's float-to-bits conversion follows IEEE 754 exactly, but this is worth verifying.

---

## Decision 4: Demonstrate .bss zero-initialisation rather than just explaining it

**Decision:** The program dumps the `.bss` buffer live so the student can observe the zero bytes.

**Why:** The OS guarantee that `.bss` is zeroed before the program starts is a critical invariant. C global variables depend on it (C standard §6.7.9). Security implications: if a secret key is accidentally placed in `.bss` instead of stack memory, it persists zeroed across runs — unlike stack memory which retains values from previous function calls. Seeing zero bytes in the dump makes this concrete. Module 18 (exploitation) relies on this distinction.

**Trade-off:** The zero-initialisation is performed by the OS loader, not by any code in the binary. The binary simply records the `.bss` section's size; the loader allocates and zeroes the pages. Module 16 (Linker & Loader) shows exactly how this handoff works via the ELF program header `p_filesz` vs `p_memsz` difference.
