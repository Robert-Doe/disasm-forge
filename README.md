# disasm-forge

**A 21-module x86-64 NASM course, security-professional focus, built toward one destination: forging your own working disassembler from raw instruction bytes.**

## Why this exists

Most assembly material teaches syntax and stops. That's not enough for security work, where the
job is routinely to read *someone else's* machine code with no source attached — a stripped
binary, a shellcode blob, a function an EDR just hooked. This course is built the other
direction: every module produces a real, running NASM program plus a `tutorial.html` and
`DECISIONS.md` explaining the mechanism, and the whole 21-module arc is deliberately sequenced
so that the capstone — Module 21, a mini x86-64 disassembler that decodes raw opcode bytes
(REX/ModRM/SIB, the `0F` two-byte escape, a working instruction subset) into Intel-syntax
mnemonics — is *forced* to use nearly everything taught before it. You can't decode `ModRM`
addressing correctly without Module 10's addressing-mode families; you can't decode a `call`/
`ret` correctly without Module 7's call-stack mechanics. The name is the thesis: the course
exists to forge that disassembler, and every earlier module is a component of it.

The security throughline isn't bolted on at the end — it's load-bearing from Module 2 onward.
Registers get security relevance (`fs`/`gs` as the TEB/TLS access point) years before Module 18
ever mentions an exploit. By the time Phase 5 arrives, the student is crafting a real stack
buffer overflow against a real vulnerable C program, toggling stack canaries / NX / ASLR on and
off one at a time in GDB to watch each mitigation actually change the assembly-level outcome,
and chaining ROP gadgets against a binary they've already disassembled by hand in the phase
before.

## What's built, and why

- **Zero-libc executables from Module 1 onward** — the toolchain (NASM + GCC/ld, Windows via
  MSYS2 or Linux native) and the assemble → link → execute pipeline are exercised on the very
  first program, so every later module is adding a concept, not re-deriving the build.
- **A live zero-extension demo** (Module 2) proving, not asserting, that writing to a 32-bit
  sub-register clears the upper 32 bits of its 64-bit parent.
- **A real overflow, not a described one** (Module 18): a genuinely vulnerable `vuln.c`, an
  asm-crafted redirect payload, and a GDB walkthrough that flips stack canaries, NX/DEP, and
  ASLR on and off individually to show each mitigation's actual effect on the exploit at the
  instruction level.
- **Reverse engineering against binaries with the source deliberately withheld** (Module 19) —
  the student reads `objdump -d -M intel` output cold and has to recognize `if`/`switch`/`for`/
  `while` shapes and inlined/tail calls without a source file to check against.
- **A hand-written bare-metal runtime** (Module 20): `_start`, raw syscall wrappers, a bump
  allocator, and integer-to-string conversion, linked with `-nostdlib -nostartfiles` — the exact
  skill set underpinning shellcode and minimal implants, taught as infrastructure rather than as
  an offensive technique in isolation.
- **The capstone disassembler** (Module 21): decodes a real instruction subset from raw bytes
  and prints Intel-syntax mnemonics, checked against a test suite of known byte sequences —
  `mov`, `add`, `sub`, `push`, `pop`, `call`, `ret`, `jmp`, and the conditional jumps.

## Module table of contents

| # | Module | Phase | Security relevance |
|---|--------|-------|---------------------|
| 01 | [Toolchain Setup & Your First Assembly Program](module_01/README.md) | Foundations | GDB from day one |
| 02 | [Registers: Every Single One](module_02/README.md) | Foundations | `fs`/`gs` → TEB/TLS; flags → exploit conditions |
| 03 | [Data Representation & Memory Fundamentals](module_03/README.md) | Foundations | Endianness in network protocols & file formats |
| 04 | [Arithmetic & the ALU](module_04/README.md) | Core Assembly | Integer overflow, signed/unsigned confusion bugs |
| 05 | [Bitwise Operations & Bit Manipulation](module_05/README.md) | Core Assembly | Masking, flag fields, crypto primitives |
| 06 | [Control Flow: Every Jump Instruction](module_06/README.md) | Core Assembly | Branch logic in exploits, CFG shape |
| 07 | [The Call Stack: Mechanics from First Principles](module_07/README.md) | Core Assembly | Foundation of all stack exploitation |
| 08 | [Procedures, Recursion & the Red Zone](module_08/README.md) | Core Assembly | Red zone abuse in shellcode |
| 09 | [Calling Conventions & the ABI in Full Detail](module_09/README.md) | Core Assembly | Argument registers = where secrets live |
| 10 | [Memory Addressing: Every Mode Explained](module_10/README.md) | Advanced Assembly | Pointer arithmetic, type confusion |
| 11 | [String & Array Operations](module_11/README.md) | Advanced Assembly | Buffer boundaries, off-by-one errors |
| 12 | [The x87 FPU & SSE2 Scalar Floating Point](module_12/README.md) | Advanced Assembly | FPU state across context switches |
| 13 | [SIMD: SSE, AVX & Packed Data](module_13/README.md) | Advanced Assembly | Crypto, AV evasion via SIMD |
| 14 | [The ELF & PE Binary Formats](module_14/README.md) | Systems Layer | Malware analysis, packing detection |
| 15 | [System Calls & Direct OS Interaction](module_15/README.md) | Systems Layer | Syscall-based evasion, API hooking |
| 16 | [The Linker & Loader: From Object File to Process](module_16/README.md) | Systems Layer | PLT/GOT hooking, `LD_PRELOAD` |
| 17 | [Inline Assembly & Reading Compiler Output](module_17/README.md) | Systems Layer | Auditing compiler output for bugs |
| 18 | [Stack Exploitation & Mitigations (Security Deep Dive)](module_18/README.md) | Security Focus | Buffer overflows, ROP, canaries, NX, ASLR |
| 19 | [Reading Disassembly & Reverse Engineering Patterns](module_19/README.md) | Security Focus | Binary triage, EDR hook detection |
| 20 | [Writing a Bare-Metal Runtime (No libc)](module_20/README.md) | Expert Techniques | Shellcode, implants, minimal agents |
| 21 | [Capstone: A Mini x86-64 Disassembler](module_21/README.md) | Expert Techniques | Instruction decoding = vulnerability research |

Full syllabus, per-module file lists, and the phase dependency graph live in
[`COURSE_OUTLINE.md`](COURSE_OUTLINE.md).

## Tech stack

- **Assembly:** NASM syntax, x86-64.
- **Interop/inspection:** C11, used only where a module needs a caller, a callback, or a format
  string a raw `syscall`/`WriteFile` can't produce cheaply (e.g. `print_helper.c`,
  `elf_reader.c`, `abi_caller.c`).
- **Toolchain:** GCC + `ld` via MSYS2/MinGW-w64 on Windows, native GCC/`ld`/`binutils` on Linux;
  GDB for every module from Module 1 onward.
- **Target platforms:** Windows (MSYS2/MinGW-w64) and Linux x86-64, with both ABIs (System V and
  Microsoft x64) taught side by side rather than picking one and treating the other as a footnote.
- **No build system beyond `make`** — each module directory ships its own `Makefile`; there is
  no cross-module build orchestration to obscure what each module actually compiles and links.

## Status

Complete: all 21 modules exist with their `.asm`/`.c` sources, `Makefile`, `tutorial.html`
lesson, and `DECISIONS.md` design rationale. The dependency graph in `COURSE_OUTLINE.md` runs
linearly through Phases 1–3 (Modules 01–13), forks into Phase 4's systems layer (14–17) and
Phase 5's security focus (18–19), and reconverges at Phase 6 (20–21), where the capstone draws
on the entire chain.

## How to explore/run this repo

1. Each `module_NN/README.md` states exactly what that module teaches and what command builds
   and runs it — start there, not in the source file, if you're choosing where to jump in.
2. The default per-module loop is `make && ./<binary>` inside that module's directory; several
   later modules (16, 18, 19, 20, 21) have their own subdirectories (`link_demo/`, `exploit/`,
   `re_targets/`, `runtime/`, `capstone/`) with their own `Makefile` — check that module's README
   first.
3. Module 18 (`exploit/`) intentionally builds a vulnerable binary; its Makefile gates the
   unsafe build behind `make EXPLOIT=1` specifically so it's never built by accident.
4. If you're a security professional with no assembly background — this course's stated
   audience — follow Phases 1–3 in strict order once; after that, `COURSE_OUTLINE.md`'s
   dependency graph tells you which phases can be read out of order and which can't.
