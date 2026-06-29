# DECISIONS.md — Module 01: Toolchain Setup & Hello World

---

## Decision 1: Use a C helper for printing instead of raw syscalls

**Decision:** `print_hello()` is implemented in C and called from assembly rather than using `sys_write` (Linux) or `WriteFile` (Windows) directly.

**Why:** Platform syscall numbers and calling conventions differ between Linux and Windows. Introducing that complexity in Module 01 would obscure the primary lesson — understanding the assemble → link → run pipeline. The student needs to see one clean concept at a time.

**Trade-off:** A production shellcode or bare-metal program would never link libc. Module 15 (System Calls) and Module 20 (Bare-Metal Runtime) resolve this by building raw syscall wrappers and eliminating the C runtime entirely.

---

## Decision 2: Entry point is `main`, not `_start`

**Decision:** The assembly file exports `main` rather than `_start`, relying on the C runtime for process setup.

**Why:** When GCC links the final binary it supplies `_start`, which initialises the C runtime (sets up `argc`/`argv`, calls constructors, installs `atexit` handlers) and then calls `main`. Skipping this in Module 01 keeps the focus on the assembly → linker pipeline rather than process startup mechanics.

**Trade-off:** Real low-level programs and shellcode start at `_start` with no C runtime. Module 20 shows exactly what `_start` must do before handing off to application code.

---

## Decision 3: Link via `gcc` rather than calling `ld` directly

**Decision:** The Makefile uses `gcc` as the linker driver instead of invoking `ld` with explicit flags.

**Why:** `ld` requires manually specifying the C runtime object files (`crt1.o`, `crti.o`, `crtn.o`) and library search paths, which differ between distributions and MSYS2 toolchain versions. `gcc` knows all of this automatically and produces a correct executable with a single command, which is the right default until Module 16 (Linker & Loader).

**Trade-off:** `gcc` hides what the linker actually does. Module 16 calls `ld` directly and uses `readelf -r` to expose every relocation entry the linker processes.

---

## Decision 4: Use `bits 64` directive explicitly

**Decision:** Every `.asm` file in this course begins with `bits 64`.

**Why:** NASM defaults to 16-bit mode for historical reasons (`.com` file compatibility). Without `bits 64`, NASM silently assembles 64-bit registers as 16-bit encodings, producing code that crashes at runtime with no helpful error. Declaring `bits 64` at the top prevents an entire class of silent bugs.

**Trade-off:** A production project would set the default in a `nasm.cfg` or via `-f elf64` inference, but explicit beats implicit when learning.
