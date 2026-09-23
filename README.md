# disasm-forge

Most assembly material teaches you the syntax and then stops, and that's not enough if you actually do security work, where the job is routinely to read someone else's machine code with no source attached. A stripped binary. A shellcode blob. A function an EDR just hooked. I built this course in the opposite direction: every module produces a real, running NASM program plus a `tutorial.html` and `DECISIONS.md` explaining the mechanism, and the whole 21-module arc is deliberately sequenced so the capstone, Module 21, a mini x86-64 disassembler that decodes raw opcode bytes (REX, ModRM, SIB, the `0F` two-byte escape, a working instruction subset) into Intel-syntax mnemonics, is forced to use nearly everything I taught before it. You can't decode `ModRM` addressing correctly without Module 10's addressing-mode families. You can't decode a `call`/`ret` correctly without Module 7's call-stack mechanics. The name is the thesis. The course exists to forge that disassembler, and every earlier module is one of its parts.

The security angle isn't bolted on at the end, it's load-bearing from Module 2 onward. Registers get security relevance (`fs`/`gs` as the TEB/TLS access point) years before Module 18 ever mentions an exploit. By the time Phase 5 arrives, you're crafting a real stack buffer overflow against a real vulnerable C program, toggling stack canaries, NX, and ASLR on and off one at a time in GDB to watch each mitigation actually change the assembly-level outcome, then chaining ROP gadgets against a binary you've already disassembled by hand in the phase before.

## What I built, and why

Every executable from Module 1 onward runs with zero libc. The toolchain (NASM plus GCC/ld, MSYS2 on Windows or native on Linux) and the assemble, link, execute pipeline get exercised on the very first program, so every later module is adding a concept instead of re-deriving the build from scratch.

Module 2 has a live zero-extension demo that proves, rather than just asserts, that writing to a 32-bit sub-register clears the upper 32 bits of its 64-bit parent.

Module 18 is a real overflow, not a described one: a genuinely vulnerable `vuln.c`, an asm-crafted redirect payload, and a GDB walkthrough that flips stack canaries, NX/DEP, and ASLR on and off individually to show each mitigation's actual effect on the exploit at the instruction level.

Module 19 is reverse engineering against a binary with the source deliberately withheld. You read `objdump -d -M intel` output cold and have to recognize `if`, `switch`, `for`, and `while` shapes, plus inlined and tail calls, with nothing to check your answer against.

Module 20 is a hand-written bare-metal runtime: `_start`, raw syscall wrappers, a bump allocator, and integer-to-string conversion, linked with `-nostdlib -nostartfiles`. That's the exact skill set behind shellcode and minimal implants, taught here as infrastructure rather than as an offensive technique floating in isolation.

Module 21, the capstone, decodes a real instruction subset from raw bytes and prints Intel-syntax mnemonics, checked against a test suite of known byte sequences: `mov`, `add`, `sub`, `push`, `pop`, `call`, `ret`, `jmp`, and the conditional jumps.

## Module table of contents

| # | Module | Phase | Security relevance |
|---|--------|-------|---------------------|
| 01 | [Toolchain Setup & Your First Assembly Program](module_01/README.md) | Foundations | GDB from day one |
| 02 | [Registers: Every Single One](module_02/README.md) | Foundations | `fs`/`gs` to TEB/TLS; flags to exploit conditions |
| 03 | [Data Representation & Memory Fundamentals](module_03/README.md) | Foundations | Endianness in network protocols and file formats |
| 04 | [Arithmetic & the ALU](module_04/README.md) | Core Assembly | Integer overflow, signed/unsigned confusion bugs |
| 05 | [Bitwise Operations & Bit Manipulation](module_05/README.md) | Core Assembly | Masking, flag fields, crypto primitives |
| 06 | [Control Flow: Every Jump Instruction](module_06/README.md) | Core Assembly | Branch logic in exploits, CFG shape |
| 07 | [The Call Stack: Mechanics from First Principles](module_07/README.md) | Core Assembly | Foundation of all stack exploitation |
| 08 | [Procedures, Recursion & the Red Zone](module_08/README.md) | Core Assembly | Red zone abuse in shellcode |
| 09 | [Calling Conventions & the ABI in Full Detail](module_09/README.md) | Core Assembly | Argument registers are where secrets live |
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
| 21 | [Capstone: A Mini x86-64 Disassembler](module_21/README.md) | Expert Techniques | Instruction decoding as vulnerability research |

The full syllabus, per-module file lists, and phase dependency graph live in [`COURSE_OUTLINE.md`](COURSE_OUTLINE.md).

## Tech stack

NASM syntax, x86-64, for the assembly. C11 for interop and inspection, used only where a module needs a caller, a callback, or a format string that a raw `syscall`/`WriteFile` can't produce cheaply, things like `print_helper.c`, `elf_reader.c`, and `abi_caller.c`. GCC and `ld` via MSYS2/MinGW-w64 on Windows, native GCC/`ld`/`binutils` on Linux, and GDB from Module 1 onward. Both Windows (MSYS2/MinGW-w64) and Linux x86-64 are covered, and I taught both ABIs, System V and Microsoft x64, side by side instead of picking one and treating the other as a footnote. There's no build system beyond `make`, each module directory ships its own `Makefile`, and there's no cross-module build orchestration hiding what any given module actually compiles and links.

## Where this stands

Done. All 21 modules exist with their `.asm`/`.c` sources, `Makefile`, `tutorial.html` lesson, and `DECISIONS.md` design rationale. The dependency graph in `COURSE_OUTLINE.md` runs linearly through Phases 1 through 3 (Modules 01 through 13), forks into Phase 4's systems layer (14 through 17) and Phase 5's security focus (18 and 19), then reconverges at Phase 6 (20 and 21), where the capstone draws on the entire chain.

## How to explore or run this repo

Each `module_NN/README.md` tells you exactly what that module teaches and what command builds and runs it. Start there, not in the source file, if you're deciding where to jump in.

The default loop per module is `make && ./<binary>` inside that module's directory. Several later modules (16, 18, 19, 20, 21) have their own subdirectories (`link_demo/`, `exploit/`, `re_targets/`, `runtime/`, `capstone/`) with their own `Makefile`, check that module's README first.

Module 18's `exploit/` intentionally builds a vulnerable binary. Its Makefile gates the unsafe build behind `make EXPLOIT=1` specifically so it never gets built by accident.

If you're a security professional with no assembly background, which is exactly who I wrote this for, follow Phases 1 through 3 in strict order once. After that, `COURSE_OUTLINE.md`'s dependency graph tells you which phases can be read out of order and which can't.
