# DECISIONS.md — Module 15: System Calls & Direct OS Interaction

## Decision 1: Use _start (no C runtime) for Linux syscalls

**Decision:** `syscalls.asm` defines `_start` and links with `ld` (no gcc, no libc). The Makefile uses `ld -o syscalls syscalls.o` directly.
**Why:** This is the only way to demonstrate truly zero-libc code. With `main` + gcc, the C runtime startup (`_start` in crt1.o) calls `__libc_start_main` before `main`, which sets up the heap, locale, environment, and signal handlers. Linking with `ld` directly means the kernel hands control straight to our `_start` label, and every OS interaction requires an explicit syscall. This is the exact structure of shellcode and minimal executables.
**Trade-off:** Without libc, there is no `printf`, `malloc`, or any standard function. All I/O must go through `SYS_WRITE`. The `print_hex` function in the file demonstrates how to do formatted output in pure assembly.

## Decision 2: Demonstrate mmap + mprotect as the shellcode loader pattern

**Decision:** The sequence mmap(RW) → write bytes → mprotect(RX) is explicitly shown and named the "shellcode loader pattern."
**Why:** This is the exact sequence used by: (a) JIT compilers to emit code, (b) exploit payloads that receive shellcode over the network and execute it, (c) packers that decompress code at runtime. Understanding this at the syscall level — knowing the exact arguments to each call — demystifies how runtime code generation works and why W^X (write XOR execute) is a meaningful mitigation. mprotect(PROT_READ|PROT_EXEC) without PROT_WRITE is the kernel enforcement of W^X.

## Decision 3: Note 4th argument registers r10 vs rcx for syscalls

**Decision:** Comments in the code explicitly note that the Linux syscall ABI uses r10 for the 4th argument, not rcx, because SYSCALL destroys rcx (it saves rip into rcx).
**Why:** This is a common source of bugs when converting a C function call to a raw syscall. The C calling convention uses rcx for the 4th argument. The syscall ABI uses r10 because the SYSCALL instruction saves the return address in rcx, overwriting whatever was there. Shellcode that puts the 4th argument in rcx will silently fail.

## Decision 4: Windows build uses Win32 API via normal imports, not raw NT syscalls

**Decision:** `win_api.asm` imports `VirtualAlloc`, `WriteConsoleA`, etc. from kernel32.dll rather than calling `NtAllocateVirtualMemory` via direct syscall stubs.
**Why:** Windows NT syscall numbers are not documented and change between Windows versions (unlike Linux, where they are stable ABI). Production shellcode uses manual syscall stubs with hardcoded numbers for a specific Windows build, but that is a security operations topic beyond the course scope. The Win32 API is the correct stable interface and illustrates the same concepts (allocation, protection, writing, releasing) at the same level.
