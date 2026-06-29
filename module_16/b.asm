; =============================================================================
; b.asm  —  Module 16: Linker & Loader Internals — Compilation Unit B
;
; Defines symbols referenced by a.asm.
; Also references a_multiply from a.asm — demonstrating bidirectional linking.
; =============================================================================
bits 64

extern a_multiply       ; defined in a.asm
extern print_label
extern print_u64

global b_add            ; exported: a.asm calls this
global b_counter        ; exported data: a.asm reads this
global b_demo           ; called from main in a.asm to show B's perspective

section .data
    ; b_counter is a mutable global — both A and B can read/write it
    ; The linker places this in the final binary's .data section
    b_counter   dq 100      ; initial value

section .rodata
    lbl_b       db "=== Unit B: b_add(x,y) called from A ===", 0
    lbl_back    db "=== Unit B calling back into A: a_multiply ===", 0

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
; b_add(x, y) → rax = x + y
; Exported so a.asm can call it. The linker fills in the call target in a.asm.
; ─────────────────────────────────────────────────────────────────────────────
b_add:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    lea  rax, [rdi + rsi]  ; x + y, using LEA as arithmetic
    ret

; ─────────────────────────────────────────────────────────────────────────────
; b_demo — called from a.asm to show B calling back into A
; ─────────────────────────────────────────────────────────────────────────────
b_demo:
    push rbp
    mov  rbp, rsp
    push rbx
    sub  rsp, 8

    LABEL lbl_b

    ; Increment b_counter (shared mutable state)
    mov  rax, [rel b_counter]
    inc  rax
    mov  [rel b_counter], rax
    SHOWu rax               ; 101

    LABEL lbl_back

    ; Call back into a.asm — the linker resolves this cross-unit reference too
    mov  rdi, 6
    mov  rsi, 9
    mov  rcx, rdi
    mov  rdx, rsi
    call a_multiply          ; 6 * 9 = 54
    SHOWu rax

    add  rsp, 8
    pop  rbx
    pop  rbp
    ret
