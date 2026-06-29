; =============================================================================
; start.asm  —  Module 20: Bare-Metal Runtime
;
; The entry point the kernel jumps to after execve().
; No C runtime. No libc. Just the kernel ABI.
;
; At entry the stack layout is:
;   [rsp+0]     argc           (int64)
;   [rsp+8]     argv[0]        (pointer)
;   [rsp+16]    argv[1]        ...
;   [rsp+8+argc*8] NULL sentinel
;   then envp[] pointers
;   then auxiliary vector (AT_*)
;
; This _start:
;   1. Reads argc/argv/envp from the initial stack
;   2. Aligns rsp to 16 bytes (ABI requirement before any call)
;   3. Calls our_main(argc, argv, envp)
;   4. Calls sys_exit with our_main's return value
; =============================================================================
bits 64

extern our_main     ; defined in io.asm
extern heap_init    ; defined in alloc.asm

global _start

SYS_EXIT equ 60

section .text

_start:
    ; ── Read initial stack layout ────────────────────────────────────────────
    ; rsp points at argc on the initial kernel stack
    pop  rdi                ; rdi = argc
    mov  rsi, rsp           ; rsi = &argv[0]

    ; envp = argv + argc + 1  (skip argc pointers + null sentinel)
    lea  rdx, [rsi + rdi*8 + 8]   ; rdx = &envp[0]

    ; ── Align stack to 16 bytes ──────────────────────────────────────────────
    ; The kernel guarantees 8-byte alignment at _start, but we need 16 before
    ; any call instruction (which pushes an 8-byte return address, removing the
    ; alignment). The standard trick: AND rsp with -16, then subtract 8.
    and  rsp, ~0xF          ; round down to 16-byte boundary
    sub  rsp, 8             ; make it misaligned by 8 so that the 'call'
                            ; instruction's implicit push brings it back to 16

    ; ── Initialise our heap allocator ────────────────────────────────────────
    call heap_init

    ; ── Call our_main(argc, argv, envp) ──────────────────────────────────────
    call our_main
    ; rax = return value from our_main

    ; ── sys_exit(return_value) ───────────────────────────────────────────────
    mov  rdi, rax
    mov  rax, SYS_EXIT
    syscall
    ; Never reached
