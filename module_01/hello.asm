; =============================================================================
; hello.asm  —  Module 01: Your First Assembly Program
; =============================================================================
; Calls a C helper (print_helper.c) to print a string, then returns cleanly.
; We use a C helper here so we don't have to deal with platform differences
; in argument registers yet — that comes in Module 09 (Calling Conventions).
; =============================================================================

bits 64                     ; tell NASM we are writing 64-bit code

; ── External symbols ─────────────────────────────────────────────────────────
extern print_hello          ; defined in print_helper.c

; ── Code section ─────────────────────────────────────────────────────────────
section .text
    global main             ; make 'main' visible to the linker

; -----------------------------------------------------------------------------
; main — program entry point (C runtime calls this after _start sets up)
; -----------------------------------------------------------------------------
main:
    push rbp                ; save the caller's base pointer (ABI requirement)
    mov  rbp, rsp           ; establish our own stack frame

    call print_hello        ; call the C helper — it prints "Hello, Assembly!"

    xor  eax, eax           ; set return value to 0  (writing eax zeros rax too)
    pop  rbp                ; restore caller's base pointer
    ret                     ; return to the C runtime, which calls exit(0)
