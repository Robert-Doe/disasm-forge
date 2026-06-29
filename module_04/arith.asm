; =============================================================================
; arith.asm  —  Module 04: Arithmetic & the ALU
; =============================================================================
bits 64

extern print_u64
extern print_s64
extern print_label
extern print_two_u64        ; prints "hi:lo = 0x... 0x..."

section .rodata
    lbl_add    db "add / sub / inc / dec", 0
    lbl_mul    db "mul: unsigned 64x64 -> 128-bit result in rdx:rax", 0
    lbl_imul   db "imul: signed multiply", 0
    lbl_div    db "div/idiv: quotient in rax, remainder in rdx", 0
    lbl_adc    db "adc/sbb: multi-precision (128-bit add)", 0
    lbl_flags  db "overflow (OF) vs carry (CF) demonstration", 0

section .text
    global main

%macro LABEL 1
    lea rdi, [rel %1]
    lea rcx, [rel %1]
    call print_label
%endmacro
%macro SHOWu 1
    mov rdi, %1
    mov rcx, %1
    call print_u64
%endmacro
%macro SHOWs 1
    mov rdi, %1
    mov rcx, %1
    call print_s64
%endmacro

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

    ; ── add / sub / inc / dec ────────────────────────────────────────────────
    LABEL lbl_add

    mov  rax, 100
    add  rax, 42            ; rax = 142
    SHOWu rax

    mov  rax, 200
    sub  rax, 57            ; rax = 143
    SHOWu rax

    mov  rax, 0
    inc  rax                ; rax = 1  (does NOT affect CF — unlike add rax,1)
    inc  rax                ; rax = 2
    dec  rax                ; rax = 1
    SHOWu rax

    ; neg: two's complement negation
    mov  rax, 42
    neg  rax                ; rax = -42  (same as: xor all bits then +1)
    SHOWs rax

    ; ── mul: unsigned 64×64 → 128-bit ────────────────────────────────────────
    LABEL lbl_mul

    ; mul src  multiplies rax (implicit) by src
    ; Result: upper 64 bits in rdx, lower 64 bits in rax
    mov  rax, 0xFFFFFFFFFFFFFFFF   ; largest 64-bit unsigned
    mov  rbx, 2
    mul  rbx                        ; rdx:rax = 0xFFFFFFFFFFFFFFFF * 2
                                    ; = 0x0000000000000001_FFFFFFFFFFFFFFFE

    ; print both halves
    mov  rdi, rdx
    mov  rcx, rdx
    call print_u64          ; high half: 1
    SHOWu rax               ; low half:  0xFFFFFFFFFFFFFFFE

    ; ── imul: signed multiply (two-operand form) ──────────────────────────────
    LABEL lbl_imul

    ; Two-operand imul: dst = dst * src  (result truncated to 64 bits)
    mov  rax, -3
    mov  rbx, 7
    imul rax, rbx           ; rax = -21
    SHOWs rax

    ; Three-operand imul: dst = src * imm  (compiler's favourite form)
    imul rax, rbx, 6        ; rax = 7 * 6 = 42  (rbx=7 still from above)
    SHOWs rax

    ; ── div / idiv ───────────────────────────────────────────────────────────
    LABEL lbl_div

    ; div src divides rdx:rax by src
    ; Quotient → rax, Remainder → rdx
    ; BEFORE div: must set up rdx (upper half of dividend)
    mov  rax, 100
    xor  rdx, rdx           ; zero rdx (unsigned divide: upper half = 0)
    mov  rbx, 7
    div  rbx                 ; rax = 14 (quotient), rdx = 2 (remainder)
    SHOWu rax                ; 14
    SHOWu rdx                ; 2

    ; idiv: signed division — use cqo to sign-extend rax into rdx:rax
    mov  rax, -100
    cqo                      ; sign-extend rax → rdx:rax (rdx = 0xFFFF... if rax < 0)
    mov  rbx, 7
    idiv rbx                 ; rax = -14, rdx = -2
    SHOWs rax
    SHOWs rdx

    ; ── adc/sbb: multi-precision 128-bit addition ────────────────────────────
    LABEL lbl_adc

    ; Add two 128-bit numbers stored as pairs of 64-bit registers
    ; A = rdx:rax = 0xFFFFFFFFFFFFFFFF_0000000000000001
    ; B = rcx:rbx = 0x0000000000000000_FFFFFFFFFFFFFFFF
    ; Expected result: 0x0000000000000001_0000000000000000

    mov  rax, 0x0000000000000001   ; low half of A
    mov  rdx, 0xFFFFFFFFFFFFFFFF   ; high half of A
    mov  rbx, 0xFFFFFFFFFFFFFFFF   ; low half of B
    mov  rcx, 0x0000000000000000   ; high half of B

    add  rax, rbx           ; low halves: 1 + FFFF...FFFF = 0 with CF=1
    adc  rdx, rcx           ; high halves + carry: FFFF...FFFF + 0 + 1 = 0 with CF=1
                            ; final: rdx=0, rax=0... wait we need to check:
                            ; 1 + FFFFFFFFFFFFFFFF = 10000000000000000 (17 hex digits)
                            ; low = 0000000000000000, carry = 1
                            ; FFFFFFFFFFFFFFFF + 0 + 1 = 0000000000000000, carry=1

    ; print the 128-bit result
    mov  rdi, rdx           ; high half
    mov  rcx, rdx
    call print_u64
    SHOWu rax               ; low half

    ; ── CF vs OF: unsigned overflow vs signed overflow ────────────────────────
    LABEL lbl_flags

    ; CF (Carry Flag) = unsigned overflow
    mov  rax, 0xFFFFFFFFFFFFFFFF
    add  rax, 1             ; CF=1 (result wrapped around to 0), OF=0
    SHOWu rax               ; prints 0

    ; OF (Overflow Flag) = signed overflow
    mov  rax, 0x7FFFFFFFFFFFFFFF   ; largest positive signed 64-bit value
    add  rax, 1                    ; OF=1 (result is now negative: 0x8000...0000)
    SHOWs rax                      ; prints -9223372036854775808

    xor  eax, eax
    add  rsp, 64
    pop  rbp
    ret
