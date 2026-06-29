# DECISIONS.md — Module 20: Bare-Metal Runtime

## Decision 1: Split into four files (start, syscalls, alloc, io)

**Decision:** The runtime is split across four files by responsibility rather than written as one monolithic file.
**Why:** This mirrors how real minimal runtimes are structured (musl libc's `crt/crt1.c`, OS kernel `head.S`, etc.). The split also makes the dependency graph explicit: `io.asm` depends on `syscall_wrappers.asm` and `alloc.asm`; `start.asm` depends on `io.asm` and `alloc.asm`; `syscall_wrappers.asm` depends on nothing. Students can read each file independently.
**Trade-off:** More files to build and link. The Makefile handles this transparently with a single `make`.

## Decision 2: Use bump allocator (brk-based), not mmap

**Decision:** `alloc.asm` implements a monotonic bump allocator using `sys_brk` rather than `sys_mmap`.
**Why:** `sys_brk` is the historical heap mechanism. Understanding it explains why `malloc` in glibc uses `brk` for small allocations and `mmap` for large ones. The bump allocator has no `free()` — which is appropriate for a short-lived process and demonstrates that allocation strategies are a design choice, not a universal law.
**Trade-off:** A production runtime needs a real allocator (free lists, bins, etc.). The bump allocator suffices for demonstration. Students who complete Exercise 3 implement a simple free list.

## Decision 3: _start reads argc/argv/envp from the initial stack directly

**Decision:** `start.asm` uses `pop rdi` to read argc and `mov rsi, rsp` to get argv, then computes envp.
**Why:** This is exactly what `glibc`'s `_start` does, and it is the cleanest demonstration of the kernel's initial stack layout. Students who have read Module 14 (ELF entry point) and Module 15 (syscalls) now see the complete picture: `execve` sets up this stack, the kernel jumps to `e_entry`, and `_start` is that entry.
**Trade-off:** The stack alignment dance (`and rsp, ~0xF; sub rsp, 8`) is subtle. The comment explains why: `call` pushes 8 bytes, so to have rsp 16-byte aligned at the point the called function starts (which is what the ABI requires), we need rsp to be 8 mod 16 before the `call`.

## Decision 4: io.asm contains our_main (application logic mixed with I/O)

**Decision:** `our_main` lives in `io.asm` rather than a separate application file.
**Why:** For a minimal demo with one binary, this is simpler and keeps the file count manageable. A student building a real project would separate application code from library code. The module's goal is to demonstrate the runtime infrastructure, not to exemplify project structure.
