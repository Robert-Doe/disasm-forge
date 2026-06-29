; =============================================================================
; a.asm  —  Module 16: Linker & Loader Internals
;
; This is compilation unit A. It defines symbols that b.asm will reference,
; and references symbols that b.asm defines. The linker patches every
; cross-unit reference by writing the correct address into a relocation slot.
; =============================================================================
bits 64

; Declare symbols defined in b.asm that we need here
extern b_add            ; int64_t b_add(int64_t x, int64_t y)
extern b_counter        ; global variable defined in b.asm
extern print_label
extern print_u64

; Export our own symbols so b.asm and C code can use them
global main
global a_multiply       ; int64_t a_multiply(int64_t x, int64_t y)
global a_message        ; const char* a_message (exported data symbol)

section .rodata
    a_message   db "Hello from compilation unit A", 0

    lbl_link    db "=== Linker: cross-unit call a -> b_add ===", 0
    lbl_data    db "=== Shared data: b_counter read from A ===", 0
    lbl_self    db "=== Self: a_multiply(7, 6) ===", 0
    lbl_plt     db "=== PLT/GOT: calling libc printf indirectly ===", 0
    lbl_relo    db "=== Symbol addresses (relocation results) ===", 0

section .text

%macro LABEL 1
    lea  rdi, [rel %1]
    mov  rcx, rdi
    call print_label
%endmacro
%macro SHOWu 1
    mov  rdi, %1
    mov  rcx, rdi
    call print_u64
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; a_multiply(x, y) → rax = x * y
; Defined here in A, called from both A and B
; ─────────────────────────────────────────────────────────────────────────────
a_multiply:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    mov  rax, rdi
    imul rax, rsi
    ret

; ─────────────────────────────────────────────────────────────────────────────
; main — orchestrates cross-unit demonstrations
; ─────────────────────────────────────────────────────────────────────────────
main:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8

    ; ── 1. Cross-unit call: A calls B's function ─────────────────────────────
    LABEL lbl_link

    ; Call b_add(30, 12) — defined in b.asm
    ; The linker will patch this call's target address during link step
    mov  rdi, 30
    mov  rsi, 12
    mov  rcx, rdi
    mov  rdx, rsi
    call b_add           ; reference resolved by linker
    SHOWu rax            ; 42

    ; ── 2. Cross-unit data access: read b_counter ────────────────────────────
    LABEL lbl_data

    ; b_counter is defined in b.asm's .data section
    ; The linker patches [rel b_counter] with the correct address
    mov  rax, [rel b_counter]
    SHOWu rax            ; initial value from b.asm

    ; ── 3. Call our own function (same unit, no relocation needed) ───────────
    LABEL lbl_self

    mov  rdi, 7
    mov  rsi, 6
    mov  rcx, rdi
    mov  rdx, rsi
    call a_multiply      ; within same unit — direct call, linker still patches
    SHOWu rax            ; 42

    ; ── 4. Show symbol addresses (what the linker resolved them to) ──────────
    LABEL lbl_relo

    ; The address of a_multiply is resolved at link time for non-PIE,
    ; or at load time (via GOT) for PIE/shared libraries
    lea  rax, [rel a_multiply]
    SHOWu rax            ; address of a_multiply in virtual memory

    lea  rax, [rel b_add]
    SHOWu rax            ; address of b_add — came from b.asm

    lea  rax, [rel a_message]
    SHOWu rax            ; address of string in .rodata

    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    xor  eax, eax
    ret
