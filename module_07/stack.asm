; =============================================================================
; stack.asm  —  Module 07: The Call Stack: Mechanics from First Principles
; =============================================================================
bits 64

extern print_label
extern print_u64
extern print_ptr             ; prints a 64-bit pointer value

section .rodata
    lbl_push_pop  db "push / pop mechanics", 0
    lbl_call_ret  db "call / ret: how the return address works", 0
    lbl_frame     db "stack frame: prologue and epilogue", 0
    lbl_nested    db "three nested calls — observe rsp in GDB", 0
    lbl_locals    db "local variables on the stack", 0

section .text
    global main

%macro LABEL 1
    lea  rdi, [rel %1]
    lea  rcx, [rel %1]
    call print_label
%endmacro
%macro SHOWu 1
    mov  rdi, %1
    mov  rcx, %1
    call print_u64
%endmacro
%macro SHOWp 1
    mov  rdi, %1
    mov  rcx, %1
    call print_ptr
%endmacro

; =============================================================================
; add_two — a simple procedure: returns rdi + rsi in rax
; Demonstrates minimal frame setup
; =============================================================================
add_two:
    push rbp
    mov  rbp, rsp
    ; no local variables needed — args already in rdi/rsi (Linux)
    ;                              or rcx/rdx (Windows) — we use rdi/rsi here
    mov  rax, rdi
    add  rax, rsi
    pop  rbp
    ret

; =============================================================================
; level_c — innermost of three nested calls
; =============================================================================
level_c:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16            ; allocate 16 bytes of local space

    ; store a value in a local variable at [rbp-8]
    mov  qword [rbp-8], 0xCCCCCCCCCCCCCCCC

    ; print current rsp so student can observe depth in GDB
    mov  rax, rsp
    SHOWp rax

    add  rsp, 16
    pop  rbp
    ret

; =============================================================================
; level_b — middle function, calls level_c
; =============================================================================
level_b:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16

    mov  qword [rbp-8], 0xBBBBBBBBBBBBBBBB

    mov  rax, rsp
    SHOWp rax

    call level_c

    add  rsp, 16
    pop  rbp
    ret

; =============================================================================
; level_a — outermost nested function, calls level_b
; =============================================================================
level_a:
    push rbp
    mov  rbp, rsp
    sub  rsp, 16

    mov  qword [rbp-8], 0xAAAAAAAAAAAAAAAA

    mov  rax, rsp
    SHOWp rax

    call level_b

    add  rsp, 16
    pop  rbp
    ret

; =============================================================================
; main
; =============================================================================
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 48            ; space for locals + shadow space

    ; ── push / pop ───────────────────────────────────────────────────────────
    LABEL lbl_push_pop

    ; push decrements rsp by 8 then writes value at [rsp]
    mov  rax, rsp
    SHOWp rax               ; rsp before push

    push 0x1122334455667788 ; rsp -= 8; [rsp] = 0x1122334455667788
    mov  rax, rsp
    SHOWp rax               ; rsp after push (8 lower)

    pop  rbx                ; rbx = [rsp]; rsp += 8
    mov  rax, rsp
    SHOWp rax               ; rsp restored

    SHOWu rbx               ; 0x1122334455667788

    ; ── call / ret mechanics ─────────────────────────────────────────────────
    LABEL lbl_call_ret
    ; call target:
    ;   1. push rip+instruction_length  (the "return address")
    ;   2. jmp target
    ; ret:
    ;   1. pop rip  (loads the saved return address)
    ;   2. execution continues after the original call

    ; Call add_two(10, 20) — Linux ABI: args in rdi, rsi
    mov  rdi, 10
    mov  rsi, 20
    ; Windows ABI: args in rcx, rdx (we set both for portability)
    mov  rcx, 10
    mov  rdx, 20
    call add_two
    SHOWu rax               ; 30

    ; ── stack frame ──────────────────────────────────────────────────────────
    LABEL lbl_frame
    ; The standard prologue/epilogue:
    ;   push rbp          — save caller's frame base
    ;   mov  rbp, rsp     — set our frame base
    ;   sub  rsp, N       — allocate N bytes of local space (must keep rsp 16-aligned)
    ;   ...
    ;   add  rsp, N       — release local space  (or use: leave)
    ;   pop  rbp          — restore caller's frame base
    ;   ret               — return to caller

    ; Show that rbp points to the saved rbp on the stack
    mov  rax, rbp
    SHOWp rax               ; address of our frame base (= saved rbp location)

    ; ── local variables ───────────────────────────────────────────────────────
    LABEL lbl_locals
    ; Local variables live at negative offsets from rbp
    ; [rbp-8]  = first local (8 bytes)
    ; [rbp-16] = second local (8 bytes)
    ; etc.
    mov  qword [rbp-8],  0xDEADBEEF00000001
    mov  qword [rbp-16], 0xCAFEBABE00000002

    mov  rax, [rbp-8]
    SHOWu rax
    mov  rax, [rbp-16]
    SHOWu rax

    ; ── nested calls ──────────────────────────────────────────────────────────
    LABEL lbl_nested
    ; Call level_a which calls level_b which calls level_c
    ; Each prints its rsp — you will see it decrease by ~32 bytes per level
    ; In GDB: break level_c, run, then: x/32gx $rsp  to see the full chain
    call level_a

    xor  eax, eax
    add  rsp, 48
    pop  rbp
    ret
