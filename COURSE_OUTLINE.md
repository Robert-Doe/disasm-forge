# Deep x86-64 Assembly Language Mastery
## Course Outline — 21 Modules

---

### COURSE IDENTITY

| Field               | Value                                                                      |
|---------------------|----------------------------------------------------------------------------|
| Course slug         | `bob_assembly_language`                                                    |
| Topic               | x86-64 Assembly language, from zero to expert — security-professional focus|
| Primary language    | NASM (x86-64 Assembly) + C11 (as inspection/interop tool only)             |
| Target platform     | Windows (MSYS2/MinGW-w64) + Linux x86-64                                  |
| Total modules       | 21                                                                         |
| Student prerequisite| Security professional; understands processes/memory at a high level;       |
|                     | never written Assembly                                                     |

---

### PHASE MAP

```
PHASE 1 — FOUNDATIONS        (Modules 01–03)  Toolchain, architecture, data representation
PHASE 2 — CORE ASSEMBLY      (Modules 04–09)  ALU, bits, control flow, stack, procedures, ABI
PHASE 3 — ADVANCED ASSEMBLY  (Modules 10–13)  Addressing, strings, FPU, SIMD
PHASE 4 — SYSTEMS LAYER      (Modules 14–17)  Binary formats, OS interface, linker/loader
PHASE 5 — SECURITY FOCUS     (Modules 18–19)  Exploitation mechanics, reverse engineering
PHASE 6 — EXPERT TECHNIQUES  (Modules 20–21)  No-libc runtime, capstone disassembler
```

---

### MODULE OUTLINE

---

**Module 01 — Toolchain Setup & Your First Assembly Program**
- New files:  `hello.asm`, `Makefile`, `tutorial.html`, `DECISIONS.md`
- New concept: Installing NASM + GCC/ld (Windows via MSYS2, Linux native); the full assemble → link → execute pipeline; anatomy of a minimal `.asm` file (sections, entry point, `syscall`/`ExitProcess`); running under GDB for the first time
- Sample: `make && ./hello` → prints `Hello, Assembly!`; `echo $?` → `0`

---

**Module 02 — Registers: Every Single One**
- New files:  `registers.asm`, `print_helper.c`
- New concept: All 16 general-purpose registers (`rax`–`r15`) and every sub-register alias (`eax`/`ax`/`al`/`ah`); the instruction pointer `rip`; the flags register `rflags` (every named bit); segment registers (`cs`, `ds`, `ss`, `es`, `fs`, `gs`) and their modern role; zero-extension behaviour when writing to 32-bit sub-registers; what "caller-saved" vs "callee-saved" means at the register level
- Sample: `make && ./registers` → demonstrates the zero-extension rule live: writing to `eax` clears the upper 32 bits of `rax`

---

**Module 03 — Data Representation & Memory Fundamentals**
- New files:  `data.asm`, `data_demo.c`
- New concept: Binary and hexadecimal fluency; two's complement signed integers; IEEE 754 single and double precision (bit layout only, no FPU yet); `db`/`dw`/`dd`/`dq`/`dt` directives; the four memory sections `.text`/`.data`/`.bss`/`.rodata` and what lives in each; little-endian byte order and how it looks in a hex dump; `resb`/`resw`/`resd`/`resq` for uninitialized storage
- Sample: `make && ./data_demo` → prints hex dumps of values defined in `.data` and `.bss`, showing byte order on disk vs in registers

---

**Module 04 — Arithmetic & the ALU**
- New files:  `arith.asm`
- New concept: `add`, `sub`, `inc`, `dec`; `mul`/`imul` (unsigned vs signed, single and two-operand forms); `div`/`idiv` (quotient in `rax`, remainder in `rdx`; setting up `rdx` with `cqo`/`xor`); `adc` and `sbb` for multi-precision arithmetic; `neg`; why `xor rax, rax` is the canonical zero-register idiom; overflow vs carry — exactly which flag each instruction sets and when
- Sample: `make && ./arith` → performs 64-bit multiply of two large numbers and prints both halves of the 128-bit result (`rdx:rax`)

---

**Module 05 — Bitwise Operations & Bit Manipulation**
- New files:  `bits.asm`
- New concept: `and`, `or`, `xor`, `not`; `shl`/`shr` (logical shift), `sar` (arithmetic shift preserving sign); `rol`/`ror` (rotate); `rcl`/`rcr` (rotate through carry); `bt`/`bts`/`btr`/`btc` (bit test and set/reset/complement); `bsf`/`bsr` (bit scan forward/reverse); `popcnt` (population count); `tzcnt`/`lzcnt`; practical security patterns: masking, flag extraction, fast power-of-two division
- Sample: `make && ./bits` → demonstrates extracting the 4-bit nibbles from a byte, toggling specific flag bits, and computing a bitmask — all in asm

---

**Module 06 — Control Flow: Every Jump Instruction**
- New files:  `control.asm`
- New concept: `cmp` and `test` (what they actually do to flags vs what `sub`/`and` do); all 16 conditional jump mnemonics with their flag conditions; signed vs unsigned comparison jumps (`jl`/`jg` vs `ja`/`jb`); `jrcxz`; `loop`/`loope`/`loopne`; implementing `if/else if/else`, `while`, `do-while`, `for`, and `switch` (jump table) entirely in assembly; short vs near vs far jumps and encoding size
- Sample: `make && ./control` → implements a jump table dispatch of 5 cases; student can see the table in the disassembly

---

**Module 07 — The Call Stack: Mechanics from First Principles**
- New files:  `stack.asm`
- New concept: What the stack is physically (a region of memory, `rsp` pointing to top); `push`/`pop` byte-by-byte mechanics; `call` pushes `rip+instruction_length` then jumps; `ret` pops into `rip`; the canonical frame setup (`push rbp` / `mov rbp, rsp` / `sub rsp, N`) and teardown (`leave`/`ret`); where local variables live relative to `rbp`; `enter`/`leave` instructions; visualising the frame in GDB with `info frame` and `x/16gx $rsp`
- Sample: `make && ./stack` → three nested procedure calls; student runs in GDB and uses `x/32gx $rsp` to read the full stack frame chain live

---

**Module 08 — Procedures, Recursion & the Red Zone**
- New files:  `procs.asm`
- New concept: Writing clean reusable procedures; saving and restoring callee-saved registers (`rbx`, `rbp`, `r12`–`r15`); implementing recursion in asm (factorial, Fibonacci); the System V AMD64 "red zone" — the 128-byte scratch space below `rsp` that signal handlers won't clobber; tail-call optimisation by hand (`jmp` instead of `call`+`ret`); multiple return values via `rdx`
- Sample: `make && ./procs` → recursive asm Fibonacci for n=10; student can trace the stack depth in GDB

---

**Module 09 — Calling Conventions & the ABI in Full Detail**
- New files:  `abi.asm`, `abi_caller.c`
- New concept: System V AMD64 ABI (Linux/macOS) vs Microsoft x64 ABI (Windows) side by side; argument passing order (`rdi rsi rdx rcx r8 r9` vs `rcx rdx r8 r9`); the Windows "shadow space" / "home space" (32 bytes the callee may use); floating-point args in `xmm0`–`xmm7`; return values (`rax`, `rdx`, `xmm0`); how the ABI handles structs by value (pass in regs, or on stack, or via hidden pointer); variadic functions and `al` = number of xmm args
- Sample: `make && ./abi` → C code calls an asm function with 7 arguments (one lands on the stack); asm function calls a C callback — all register preservation verified with assertions

---

**Module 10 — Memory Addressing: Every Mode Explained**
- New files:  `addressing.asm`
- New concept: The five addressing mode families: immediate, register, direct (absolute), register-indirect `[reg]`, and scaled-index `[base + index*scale + displacement]` where scale ∈ {1,2,4,8}; `lea` for address arithmetic without a memory access (and why the compiler loves it for multiply-by-constant tricks); `BYTE PTR`/`WORD PTR`/`DWORD PTR`/`QWORD PTR` size overrides; RIP-relative addressing for position-independent code; common compiler idioms decoded
- Sample: `make && ./addressing` → accesses a 2D array of `int32_t` using scaled-index addressing; prints every element with coordinates

---

**Module 11 — String & Array Operations**
- New files:  `strings.asm`
- New concept: The `rep` prefix and how it interacts with `rcx` (count) and `rsi`/`rdi` (source/dest); `rep movsb`/`movsw`/`movsd`/`movsq` — memory copy; `rep stosb`/`stosd`/`stosq` — memory set; `repe scasb`/`repne scasb` — scanning for a byte (implementing `strlen`, `memchr`); `repe cmpsb` — memory comparison (`memcmp`); the direction flag `DF` and `cld`/`std`; writing `strlen`, `strcpy`, `memset`, `memcmp` entirely in asm
- Sample: `make && ./strings` → runs all four asm string functions on test data and compares results against libc equivalents for correctness

---

**Module 12 — The x87 FPU & SSE2 Scalar Floating Point**
- New files:  `floats.asm`
- New concept: x87 register stack (`st0`–`st7`), `fld`/`fstp`/`fadd`/`fmul`/`fcom`/`fcomi`/`fnstsw`; why x87 is deprecated in 64-bit code; SSE2 scalar instructions: `movsd`/`addsd`/`subsd`/`mulsd`/`divsd`/`sqrtsd`/`ucomisd`; `xmm` register layout (128 bits, lower 64 used for scalar double); converting between integer and float (`cvtsi2sd`, `cvttsd2si`); NaN and infinity behaviour at the instruction level
- Sample: `make && ./floats` → computes the hypotenuse of a right triangle (sqrt(a²+b²)) using SSE2 scalar double, prints result to 6 decimal places

---

**Module 13 — SIMD: SSE, AVX & Packed Data**
- New files:  `simd.asm`
- New concept: SIMD philosophy — one instruction, multiple data lanes; `xmm` (128-bit) vs `ymm` (256-bit) registers; packed integer ops: `paddb`/`paddw`/`paddd`/`paddq`, `pmulld`; packed float ops: `addps`/`mulps`/`addpd`/`mulpd`; shuffle and permute: `pshufd`/`vpermilps`; load/store alignment: `movdqa` vs `movdqu`; horizontal operations: `haddpd`; a practical use case: computing a dot product of two 4-float vectors in a single sequence of SSE instructions
- Sample: `make && ./simd` → dot product of two 8-element float arrays using SSE2 (4 floats at a time); prints result and compares with scalar loop

---

**Module 14 — The ELF & PE Binary Formats**
- New files:  `elf_reader.c`, `pe_reader.c`
- New concept: ELF64: magic bytes, `e_type`, `e_machine`, `e_entry`; section header table vs program header table; section types `SHT_PROGBITS`/`SHT_SYMTAB`/`SHT_STRTAB`/`SHT_RELA`; symbol table entries (`st_value`, `st_size`, `st_bind`, `st_type`); relocation entries and how the linker patches addresses at the byte level; PE/COFF: DOS stub, PE signature, COFF file header, optional header, data directories, import descriptor table, thunk arrays; how Windows resolves DLL imports at load time; why security tools (AV, EDR, sandboxes) parse and inspect these structures; spotting anomalies (mismatched section sizes, suspicious imports, packed sections)
- Sample: `make && ./elf_reader ./hello` → prints every section with its VMA, file offset, size, flags, and type; `./pe_reader ./hello.exe` on Windows does the same, including the full import table

---

**Module 15 — System Calls & Direct OS Interaction**
- New files:  `syscalls.asm`, `win_api.asm`
- New concept: Linux: `syscall` instruction, syscall number in `rax`, args in `rdi rsi rdx r10 r8 r9`, return value in `rax`, error as negative errno; the full Linux x86-64 syscall table (`read`=0, `write`=1, `open`=2, `mmap`=9, `mprotect`=10, `exit`=60); Windows: why user-mode code doesn't call the kernel directly (NTDLL as the ABI stability boundary, syscall stubs inside ntdll.dll); calling Win32 API (`WriteFile`, `ReadFile`, `VirtualAlloc`, `VirtualProtect`) from pure asm with the MS x64 ABI; `GetStdHandle`; `GetLastError` and the TEB (Thread Environment Block) at `gs:[0x30]`
- Sample: `make && ./syscalls` → on Linux: raw `sys_write` to stdout and `sys_read` from stdin, zero libc; on Windows: `WriteFile` via WinAPI direct call, no CRT

---

**Module 16 — The Linker & Loader: From Object File to Process**
- New files:  `link_demo/a.asm`, `link_demo/b.asm`, `link_demo/Makefile`
- New concept: What the assembler produces (an object file with unresolved symbols); `extern` and `global` declarations in NASM; the linker's jobs: symbol resolution, section merging, relocation patching; the loader's jobs: mapping PT_LOAD segments into virtual memory, applying load-time relocations, populating the GOT, setting up the initial stack (`argc`/`argv`/`envp`/`auxv`); `_start` vs `main`; static vs dynamic linking trade-offs; PLT stub → GOT → dynamic linker lazy resolution, instruction by instruction; `LD_PRELOAD` function interposition explained at the `call [GOT]` level
- Sample: `make` → links two separate `.asm` files that call each other's global symbols; `readelf -r` output decoded in the tutorial to show every relocation entry

---

**Module 17 — Inline Assembly & Reading Compiler Output**
- New files:  `inline_asm.c`, `compiler_output/`
- New concept: `gcc -S -O0` vs `-O2` — reading what the compiler actually emits; identifying prologue/epilogue patterns; GCC extended inline asm syntax `asm("..." : outputs : inputs : clobbers)`; constraint letters (`"r"`, `"m"`, `"a"`, `"=r"`, `"+r"`); memory and register clobbers; `volatile` in inline asm; when to use inline asm vs a separate `.asm` file; practical uses: `rdtsc` for cycle counting, `cpuid` for feature detection, `xchg` for atomic spin locks
- Sample: `make && ./inline_asm` → uses inline asm to call `cpuid` and print the vendor string (`GenuineIntel` / `AuthenticAMD`); uses `rdtsc` to time a loop with nanosecond precision

---

**Module 18 — Stack Exploitation & Mitigations (Security Deep Dive)**
- New files:  `exploit/vuln.c`, `exploit/exploit.asm`, `exploit/Makefile`
- New concept: Exact stack frame anatomy under GDB (`info frame`, `x/32gx $rsp`, `disas`); how a stack-based buffer overflow overwrites the saved return address byte by byte; crafting a redirect payload in asm; stack canaries — where the canary value lives in the frame and exactly how `__stack_chk_fail` branches at the asm level; NX/DEP — `mprotect`/`VirtualProtect` changing page permissions, why shellcode on a non-executable stack triggers a fault; ASLR — entropy sources, `cat /proc/sys/kernel/randomize_va_space`, partial overwrites; Return-Oriented Programming (ROP) — gadgets as `<instructions> ; ret` sequences, chaining them via the stack, `ropper` / `ROPgadget` output decoded; CFI as the modern hardware-enforced mitigation
- Sample: `make EXPLOIT=1 && gdb -x exploit.gdb ./vuln` → tutorial walks through a live overflow in GDB, toggling each mitigation on/off and observing the assembly-level effect

---

**Module 19 — Reading Disassembly & Reverse Engineering Patterns**
- New files:  `re_targets/target1.c`, `re_targets/target2.c`, `re_targets/Makefile`
- New concept: `objdump -d -M intel` anatomy; reading compiler-generated prologues, epilogues, function calls in stripped binaries; recognising patterns: `if/else` (branch-over), `switch` (jump table vs chained branches), `for` (counter in register, `dec`+`jnz` at bottom), `while` (guard jump at top), inlined functions, tail calls; `strings`, `nm`, `readelf`, `strace`, `ltrace` as triage tools; introduction to GDB scripting (`define`, `hook-stop`, Python `gdb` module); what an EDR sees when it hot-patches API calls — the `jmp rel32` stub in the prologue at the byte level
- Sample: `make` → two compiled binaries with source hidden; student reverse-engineers both using only `objdump` output following the tutorial walkthrough

---

**Module 20 — Writing a Bare-Metal Runtime (No libc)**
- New files:  `runtime/start.asm`, `runtime/syscall_wrappers.asm`, `runtime/alloc.asm`, `runtime/io.asm`, `runtime/main.c`
- New concept: `_start` entry point and the exact initial stack layout (argc at `[rsp]`, argv pointers at `[rsp+8]`, null terminator, envp); implementing `write`/`read`/`exit`/`mmap`/`munmap` as thin asm syscall wrappers; a bump allocator (arena from `mmap`); integer-to-string conversion (`itoa`) without `printf`; linking with `-nostdlib -nostartfiles`; why this knowledge underpins shellcode, position-independent implants, and minimal security agents
- Sample: `make && ./runtime_demo` → reads a line from stdin, reverses it, prints it — zero libc, only the asm runtime written in this module

---

**Module 21 — Capstone: A Mini x86-64 Disassembler**
- New files:  `capstone/disasm.asm`, `capstone/disasm.h`, `capstone/main.c`, `tests/`
- New concept: x86-64 instruction encoding: opcode byte, REX prefix (`REX.W`/`REX.R`/`REX.X`/`REX.B`), ModRM byte (`mod`/`reg`/`r/m` fields), SIB byte, displacement, immediate; two-byte opcode escape `0F`; decoding a subset of common instructions (`mov`, `add`, `sub`, `push`, `pop`, `call`, `ret`, `jmp`, `jcc`) and printing Intel-syntax mnemonics; a test suite that feeds known byte sequences and checks output strings; this module uses every concept from every prior module
- Sample: `make && printf '\x48\x89\xe5\x48\x83\xec\x10\xc3' | ./disasm` → prints `mov rbp, rsp` / `sub rsp, 0x10` / `ret` — decoded from raw bytes by the student's own disassembler

---

### DEPENDENCY MAP

```
PHASE 1              PHASE 2                              PHASE 3
01 ──► 02 ──► 03 ──► 04 ──► 05 ──► 06 ──► 07 ──► 08 ──► 09 ──► 10 ──► 11 ──► 12 ──► 13
                                                                                         │
                                               ┌─────────────────────────────────────────┘
                                               ▼
PHASE 4                                     14 ──► 15 ──► 16 ──► 17
                                                                   │
                                          ┌────────────────────────┘
                                          ▼
PHASE 5                                18 ──► 19
                                               │
                                    ┌──────────┘
                                    ▼
PHASE 6                          20 ──► 21
```

---

### QUICK REFERENCE TABLE

| # | Title | Phase | Security Relevance |
|---|-------|-------|--------------------|
| 01 | Toolchain Setup & Hello World | Foundations | GDB from day one |
| 02 | Registers: Every Single One | Foundations | fs/gs → TEB/TLS; flags → exploit conditions |
| 03 | Data Representation & Memory | Foundations | Endianness in network protocols & file formats |
| 04 | Arithmetic & the ALU | Core Asm | Integer overflow, signed/unsigned confusion bugs |
| 05 | Bitwise Operations & Bit Manipulation | Core Asm | Masking, flag fields, crypto primitives |
| 06 | Control Flow: Every Jump | Core Asm | Branch logic in exploits, CFG shape |
| 07 | The Call Stack | Core Asm | Foundation of all stack exploitation |
| 08 | Procedures, Recursion & Red Zone | Core Asm | Red zone abuse in shellcode |
| 09 | Calling Conventions & ABI | Core Asm | Arg registers = where secrets live |
| 10 | Memory Addressing Modes | Advanced Asm | Pointer arithmetic, type confusion |
| 11 | String & Array Operations | Advanced Asm | Buffer boundaries, off-by-one |
| 12 | x87 FPU & SSE2 Scalar Float | Advanced Asm | FPU state in context switches |
| 13 | SIMD: SSE, AVX & Packed Data | Advanced Asm | Crypto, AV evasion via SIMD |
| 14 | ELF & PE Binary Formats | Systems Layer | Malware analysis, packing detection |
| 15 | System Calls & OS Interaction | Systems Layer | Syscall-based evasion, API hooking |
| 16 | Linker & Loader Internals | Systems Layer | PLT/GOT hooking, LD_PRELOAD |
| 17 | Inline Assembly & Compiler Output | Systems Layer | Auditing compiler output for bugs |
| 18 | Stack Exploitation & Mitigations | Security Focus | BOF, ROP, canaries, NX, ASLR |
| 19 | Reverse Engineering Patterns | Security Focus | Binary triage, EDR hook detection |
| 20 | Bare-Metal Runtime (No libc) | Expert | Shellcode, implants, minimal agents |
| 21 | Capstone: Mini Disassembler | Expert | Instruction decoding = vuln research |

---

*Approve this outline and say "generate module 01" — all files produced in full, no truncation.*
