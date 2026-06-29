; =============================================================================
; procs.asm  —  Module 08: Procedures, Recursion & the Red Zone
; =============================================================================
bits 64

extern print_u64
extern print_label
extern print_s64

section .rodata
    lbl_callee  db "callee-saved registers: rbx r12-r15", 0
    lbl_fib     db "recursive fibonacci(10)", 0
    lbl_fact    db "recursive factorial(12)", 0
    lbl_tail    db "tail-call optimisation: jmp not call", 0
    lbl_rz      db "red zone demo (leaf function, no sub rsp)", 0
    lbl_multi   db "multiple return values via rdx", 0

section .text
    global main

%macro LABEL 1
    lea  rdi,[rel %1] | mov rcx,rdi | call print_label
%endmacro
; NASM doesn't support | for instruction separation in macros
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

; =============================================================================
; fibonacci(n) — recursive, returns fib(n) in rax
; Uses callee-saved r12 to preserve n across the recursive call
; =============================================================================
fibonacci:
    push rbp
    mov  rbp, rsp
    push r12                ; callee-saved — we must preserve it
    push rbx                ; callee-saved

    mov  r12, rdi           ; save n (Linux: first arg in rdi)
    ; Windows first arg is in rcx — module 09 handles this properly

    ; base cases: fib(0)=0, fib(1)=1
    cmp  r12, 1
    jle  .fib_base          ; if n <= 1, return n

    ; recursive case: fib(n) = fib(n-1) + fib(n-2)
    lea  rdi, [r12-1]       ; arg = n-1
    mov  rcx, rdi
    call fibonacci
    mov  rbx, rax           ; save fib(n-1)

    lea  rdi, [r12-2]       ; arg = n-2
    mov  rcx, rdi
    call fibonacci
    add  rax, rbx           ; rax = fib(n-2) + fib(n-1)
    jmp  .fib_done

.fib_base:
    mov  rax, r12           ; return n (which is 0 or 1)

.fib_done:
    pop  rbx
    pop  r12
    pop  rbp
    ret

; =============================================================================
; factorial(n) — recursive, returns n! in rax
; =============================================================================
factorial:
    push rbp
    mov  rbp, rsp
    push r12

    mov  r12, rdi
    mov  rcx, rdi           ; Windows compat

    cmp  r12, 1
    jle  .fact_base

    lea  rdi, [r12-1]
    mov  rcx, rdi
    call factorial
    imul rax, r12           ; rax = factorial(n-1) * n
    jmp  .fact_done

.fact_base:
    mov  rax, 1

.fact_done:
    pop  r12
    pop  rbp
    ret

; =============================================================================
; sum_to_tail(n, acc) — tail-recursive sum, emitted as a loop
; Linux: n=rdi, acc=rsi    Windows: n=rcx, acc=rdx
; Returns rax = n + (n-1) + ... + 1 + acc
; Tail call optimised: the recursive call is replaced with jmp back to start
; =============================================================================
sum_to_tail:
    ; NO prologue — tail calls don't need a new frame
    ; rdi = n (Linux), rsi = acc

    ; Windows: move to Linux positions for uniform code
    ; (Module 09 does this properly — here we just use rdi/rsi)
    test rdi, rdi           ; if n == 0, return acc
    jz   .tail_done

    add  rsi, rdi           ; acc += n
    dec  rdi                ; n--
    jmp  sum_to_tail        ; TAIL CALL: jmp instead of call+ret
                            ; no new stack frame — O(1) stack space

.tail_done:
    mov  rax, rsi
    ret

; =============================================================================
; red_zone_leaf — a leaf function (calls nothing) that uses the red zone
; The red zone is the 128 bytes BELOW rsp that leaf functions may use
; without adjusting rsp — signal handlers are required not to touch it
; =============================================================================
red_zone_leaf:
    ; NO prologue, NO sub rsp — we use [rsp-8]..[rsp-128] directly
    mov  qword [rsp-8],  0xAAAA0001
    mov  qword [rsp-16], 0xAAAA0002
    mov  qword [rsp-24], 0xAAAA0003
    ; ... these are safe because we are a leaf function
    mov  rax, [rsp-8]
    add  rax, [rsp-16]
    add  rax, [rsp-24]     ; rax = 0xAAAA0001 + 0xAAAA0002 + 0xAAAA0003
    ret                    ; rsp never changed — red zone bytes may get
                           ; clobbered if a signal arrives, but leaf funcs
                           ; don't call signal-receiving functions

; =============================================================================
; divmod(a, b) — returns quotient in rax, remainder in rdx
; Multiple return values using rdx
; =============================================================================
divmod:
    ; Linux: a=rdi, b=rsi
    mov  rax, rdi
    xor  rdx, rdx
    div  rsi               ; rax=quotient, rdx=remainder
    ret

; =============================================================================
; main
; =============================================================================
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    ; ── callee-saved register demo ────────────────────────────────────────────
    LABEL lbl_callee
    ; Load values into callee-saved registers
    mov  rbx, 0xBBBBBBBB
    mov  r12, 0x12121212
    mov  r13, 0x13131313
    ; Call a function — it must not disturb rbx/r12/r13
    mov  rdi, 5
    mov  rcx, 5
    call fibonacci          ; this uses r12 and rbx internally but restores them
    ; After the call, rbx/r12/r13 must still hold our values
    SHOWu rbx               ; must still be 0xBBBBBBBB
    SHOWu r12               ; must still be 0x12121212

    ; ── fibonacci ────────────────────────────────────────────────────────────
    LABEL lbl_fib
    mov  rdi, 10
    mov  rcx, 10
    call fibonacci
    SHOWu rax               ; fib(10) = 55

    ; ── factorial ────────────────────────────────────────────────────────────
    LABEL lbl_fact
    mov  rdi, 12
    mov  rcx, 12
    call factorial
    SHOWu rax               ; 12! = 479001600

    ; ── tail-call ────────────────────────────────────────────────────────────
    LABEL lbl_tail
    mov  rdi, 100           ; sum 1..100
    mov  rsi, 0             ; initial accumulator = 0
    call sum_to_tail
    SHOWu rax               ; 5050

    ; ── red zone ─────────────────────────────────────────────────────────────
    LABEL lbl_rz
    call red_zone_leaf
    SHOWu rax               ; 0xAAAA0006

    ; ── multiple return values ────────────────────────────────────────────────
    LABEL lbl_multi
    mov  rdi, 100
    mov  rsi, 7
    call divmod
    SHOWu rax               ; quotient = 14
    SHOWu rdx               ; remainder = 2

    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
