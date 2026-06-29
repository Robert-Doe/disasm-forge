; =============================================================================
; abi.asm  —  Module 09: Calling Conventions & the ABI in Full Detail
; =============================================================================
; Demonstrates the System V AMD64 ABI (Linux) and Microsoft x64 ABI (Windows)
; using conditional assembly (%ifdef WIN64) to handle both platforms correctly.
; =============================================================================
bits 64

; External C functions defined in abi_caller.c
extern c_seven_args         ; takes 7 integer args, prints them all
extern c_float_args         ; takes 4 float args via xmm registers
extern c_return_pair        ; returns two values in rax:rdx

section .rodata
    lbl_int_args   db "Passing 7 integer arguments (one lands on stack)", 0
    lbl_float_args db "Passing float arguments via xmm0-xmm3", 0
    lbl_variadic   db "Variadic: al = count of xmm args used", 0
    lbl_ret_pair   db "Two return values: rax and rdx", 0

section .text
    global main

%macro LABEL 1
    lea  rdi, [rel %1]
    lea  rcx, [rel %1]
    call print_label
%endmacro

extern print_label
extern print_u64

%macro SHOWu 1
    mov  rdi, %1
    mov  rcx, %1
    call print_u64
%endmacro

; =============================================================================
; asm_callback — called FROM C (c_seven_args calls this back)
; Demonstrates that callee-saved registers are intact on entry from C
; =============================================================================
global asm_callback
asm_callback:
    push rbp
    mov  rbp, rsp
    ; When called from C, rdi (Linux) or rcx (Windows) holds the first arg
    ; The ABI guarantees callee-saved registers are intact
%ifdef WIN64
    mov  rax, rcx       ; first arg on Windows is in rcx
%else
    mov  rax, rdi       ; first arg on Linux is in rdi
%endif
    ; double the arg and return it
    add  rax, rax
    pop  rbp
    ret

; =============================================================================
; main
; =============================================================================
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64        ; locals + shadow space + alignment

    ; ── 7 integer arguments ──────────────────────────────────────────────────
    LABEL lbl_int_args

%ifdef WIN64
    ; Windows x64 ABI:
    ; Args 1-4: rcx, rdx, r8, r9
    ; Args 5+:  pushed on stack (right to left) ABOVE the shadow space
    ; Shadow space: 32 bytes below the args on the stack (caller provides)
    ;
    ; Stack layout before call (from high to low address):
    ;   [rsp+48] arg7
    ;   [rsp+40] arg6
    ;   [rsp+32] arg5
    ;   [rsp+24] shadow for r9  (4th arg home)
    ;   [rsp+16] shadow for r8  (3rd arg home)
    ;   [rsp+8]  shadow for rdx (2nd arg home)
    ;   [rsp+0]  shadow for rcx (1st arg home)  ← rsp at point of call
    ;
    ; We already did sub rsp,64, so we have room for shadow+3 stack args
    mov  qword [rsp+32], 5      ; arg5 on stack
    mov  qword [rsp+40], 6      ; arg6 on stack
    mov  qword [rsp+48], 7      ; arg7 on stack
    mov  rcx,  1                ; arg1
    mov  rdx,  2                ; arg2
    mov  r8,   3                ; arg3
    mov  r9,   4                ; arg4
%else
    ; Linux System V AMD64 ABI:
    ; Args 1-6: rdi, rsi, rdx, rcx, r8, r9
    ; Args 7+:  pushed on stack (right to left)
    ;
    ; Stack layout before call:
    ;   [rsp+8]  arg7
    ;   [rsp+0]  ← rsp at point of call (after push of arg7)
    ;
    ; With our sub rsp,64 we push arg7 explicitly:
    mov  qword [rsp], 7         ; arg7 on stack
    mov  rdi, 1                 ; arg1
    mov  rsi, 2                 ; arg2
    mov  rdx, 3                 ; arg3
    mov  rcx, 4                 ; arg4
    mov  r8,  5                 ; arg5
    mov  r9,  6                 ; arg6
%endif
    call c_seven_args
    ; rax = return value from c_seven_args (sum of all 7 args = 28)
    SHOWu rax

    ; ── float arguments via xmm registers ────────────────────────────────────
    LABEL lbl_float_args
    ; Both ABIs pass first 4 (Linux: 8) float/double args in xmm0-xmm3
    ; For variadic functions: al = number of xmm registers used
    movsd  xmm0, [rel .f1]      ; 1.0
    movsd  xmm1, [rel .f2]      ; 2.5
    movsd  xmm2, [rel .f3]      ; 3.75
    movsd  xmm3, [rel .f4]      ; 4.0
    mov    al, 4                 ; 4 xmm args used (required for variadic callee)
    call   c_float_args
    ; rax = 1 (success)

    ; ── two return values ─────────────────────────────────────────────────────
    LABEL lbl_ret_pair
    call c_return_pair
    SHOWu rax                   ; first return value
    SHOWu rdx                   ; second return value

    xor  eax, eax
    add  rsp, 64
    pop  rbp
    ret

; Float constants (must be in .rodata, 8-byte aligned for movsd)
section .rodata
    align 8
    .f1  dq 1.0
    .f2  dq 2.5
    .f3  dq 3.75
    .f4  dq 4.0
