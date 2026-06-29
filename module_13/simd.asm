; =============================================================================
; simd.asm  —  Module 13: SIMD — SSE, AVX & Packed Data
; =============================================================================
bits 64

extern print_label
extern print_f64
extern print_u64

section .rodata
    lbl_sse2pd  db "SSE2 packed double: addpd / mulpd (2x f64)", 0
    lbl_sse2ps  db "SSE2 packed float:  addps / mulps (4x f32)", 0
    lbl_avxpd   db "AVX  packed double: vaddpd 256-bit (4x f64)", 0
    lbl_int16   db "SSE2 integer SIMD: paddw / pmullw (8x i16)", 0
    lbl_blend   db "SSE4.1 blendpd: select lanes from two regs", 0
    lbl_dot4    db "Packed dot product: 4 doubles in one pass", 0
    lbl_hadd    db "Horizontal add: haddpd reduces xmm to scalar", 0

    align 16
    pd_a        dq 1.0, 2.0          ; packed double pair a
    pd_b        dq 3.0, 4.0          ; packed double pair b

    align 16
    ps_a        dd 1.0, 2.0, 3.0, 4.0   ; four single-precision floats
    ps_b        dd 5.0, 6.0, 7.0, 8.0

    align 32
    avx_a       dq 1.0, 2.0, 3.0, 4.0   ; four doubles (256-bit)
    avx_b       dq 5.0, 6.0, 7.0, 8.0

    align 16
    ; Eight signed 16-bit integers packed into 128 bits
    sw_a        dw 1, 2, 3, 4, 5, 6, 7, 8
    sw_b        dw 10, 20, 30, 40, 50, 60, 70, 80

    align 16
    dot4_a      dq 1.0, 2.0, 3.0, 4.0   ; a=[1,2,3,4]
    dot4_b      dq 5.0, 6.0, 7.0, 8.0   ; b=[5,6,7,8]
    ; Expected: 1*5 + 2*6 + 3*7 + 4*8 = 5+12+21+32 = 70

section .bss
    tmp_qword   resq 4     ; 32 bytes for AVX spill

section .text
    global main

%macro LABEL 1
    lea  rdi, [rel %1]
    mov  rcx, rdi
    call print_label
%endmacro
%macro SHOWf 1
    movsd xmm0, %1
    call  print_f64
%endmacro
%macro SHOWu 1
    mov  rdi, %1
    mov  rcx, rdi
    call print_u64
%endmacro

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64          ; scratch space, keeps alignment

    ; ── SSE2 packed double (2x f64) ──────────────────────────────────────────
    LABEL lbl_sse2pd

    ; movapd: move aligned packed double (128-bit, both lanes)
    movapd xmm0, [rel pd_a]    ; xmm0 = [1.0 | 2.0]
    movapd xmm1, [rel pd_b]    ; xmm1 = [3.0 | 4.0]

    addpd  xmm0, xmm1           ; xmm0 = [1+3 | 2+4] = [4.0 | 6.0]
    ; Extract low lane (lane 0)
    movsd  xmm2, xmm0           ; xmm2 = 4.0 (low lane)
    SHOWf  xmm2                 ; 4.000000

    ; Extract high lane (lane 1) using psrldq (shift right 8 bytes)
    psrldq xmm0, 8              ; shift right 8 bytes → lane1 into lane0
    SHOWf  xmm0                 ; 6.000000

    ; mulpd
    movapd xmm0, [rel pd_a]    ; [1.0 | 2.0]
    movapd xmm1, [rel pd_b]    ; [3.0 | 4.0]
    mulpd  xmm0, xmm1           ; [1*3 | 2*4] = [3.0 | 8.0]
    movsd  xmm2, xmm0
    SHOWf  xmm2                 ; 3.000000
    psrldq xmm0, 8
    SHOWf  xmm0                 ; 8.000000

    ; ── SSE2 packed single (4x f32) ──────────────────────────────────────────
    LABEL lbl_sse2ps

    movaps xmm0, [rel ps_a]    ; [1 | 2 | 3 | 4]
    movaps xmm1, [rel ps_b]    ; [5 | 6 | 7 | 8]
    addps  xmm0, xmm1           ; [6 | 8 | 10 | 12]

    ; Extract lane 0 as double for printing
    cvtss2sd xmm2, xmm0         ; convert lane0 float → double
    SHOWf xmm2                  ; 6.000000

    ; Shuffle to get lane 1 into position 0, then convert
    shufps xmm0, xmm0, 0b00000001  ; rotate: lane1 → lane0
    cvtss2sd xmm2, xmm0
    SHOWf xmm2                  ; 8.000000

    ; ── AVX 256-bit packed double (4x f64) ───────────────────────────────────
    LABEL lbl_avxpd

    vmovapd ymm0, [rel avx_a]  ; ymm0 = [1.0 | 2.0 | 3.0 | 4.0]
    vmovapd ymm1, [rel avx_b]  ; ymm1 = [5.0 | 6.0 | 7.0 | 8.0]
    vaddpd  ymm0, ymm0, ymm1   ; ymm0 = [6.0 | 8.0 | 10.0 | 12.0]

    ; Store all 4 results
    vmovapd [rel tmp_qword], ymm0

    mov     rax, [rel tmp_qword]
    movq    xmm0, rax
    call    print_f64           ; 6.0

    mov     rax, [rel tmp_qword+8]
    movq    xmm0, rax
    call    print_f64           ; 8.0

    mov     rax, [rel tmp_qword+16]
    movq    xmm0, rax
    call    print_f64           ; 10.0

    mov     rax, [rel tmp_qword+24]
    movq    xmm0, rax
    call    print_f64           ; 12.0

    vzeroupper                  ; clear upper ymm bits — required before SSE calls

    ; ── SSE2 integer SIMD: 8x signed 16-bit ─────────────────────────────────
    LABEL lbl_int16

    movdqa xmm0, [rel sw_a]    ; xmm0 = [1,2,3,4,5,6,7,8] as 16-bit words
    movdqa xmm1, [rel sw_b]    ; xmm1 = [10,20,30,40,50,60,70,80]
    paddw  xmm0, xmm1           ; add 8 pairs: [11,22,33,44,55,66,77,88]

    ; Extract lane 0 (lowest 16 bits) as uint64 for display
    movd   eax, xmm0            ; eax = lowest 32 bits = lane0:lane1 packed
    movzx  rax, ax              ; zero-extend lowest 16 bits
    SHOWu  rax                  ; 11

    ; Multiply (saturating 16-bit)
    movdqa xmm0, [rel sw_a]
    movdqa xmm1, [rel sw_b]
    pmullw xmm0, xmm1           ; multiply low 16 bits of each word pair
    movd   eax, xmm0
    movzx  rax, ax
    SHOWu  rax                  ; 1*10 = 10

    ; ── SSE4.1 blendpd: select lanes from two registers ──────────────────────
    LABEL lbl_blend

    movapd xmm0, [rel pd_a]    ; xmm0 = [1.0 | 2.0]
    movapd xmm1, [rel pd_b]    ; xmm1 = [3.0 | 4.0]
    ; blendpd imm8: bit N=0 → take from xmm0; bit N=1 → take from xmm1
    blendpd xmm0, xmm1, 0b10   ; lane1 from xmm1 (4.0), lane0 from xmm0 (1.0)
    ; xmm0 = [1.0 | 4.0]
    movsd  xmm2, xmm0
    SHOWf  xmm2                 ; 1.000000
    psrldq xmm0, 8
    SHOWf  xmm0                 ; 4.000000

    ; ── Packed 4-wide dot product ─────────────────────────────────────────────
    LABEL lbl_dot4

    vmovapd ymm0, [rel dot4_a] ; [1.0 | 2.0 | 3.0 | 4.0]
    vmovapd ymm1, [rel dot4_b] ; [5.0 | 6.0 | 7.0 | 8.0]
    vmulpd  ymm0, ymm0, ymm1   ; [5.0 | 12.0 | 21.0 | 32.0]

    ; Horizontal reduction: sum all 4 lanes
    ; Step 1: add upper 128-bit half to lower 128-bit half
    vextractf128 xmm1, ymm0, 1  ; xmm1 = [21.0 | 32.0] (upper half)
    ; xmm0 still holds [5.0 | 12.0] (lower half of ymm0)
    addpd   xmm0, xmm1          ; xmm0 = [5+21 | 12+32] = [26.0 | 44.0]

    ; Step 2: horizontal add within the xmm
    haddpd  xmm0, xmm0          ; xmm0[0] = 26.0 + 44.0 = 70.0
    SHOWf   xmm0                ; 70.000000

    vzeroupper

    ; ── haddpd explained separately ──────────────────────────────────────────
    LABEL lbl_hadd

    movapd xmm0, [rel pd_a]    ; [1.0 | 2.0]
    haddpd xmm0, xmm0           ; xmm0[0] = 1.0 + 2.0, xmm0[1] = 1.0 + 2.0
    SHOWf  xmm0                 ; 3.0 (both lanes hold 3.0)

    xor  eax, eax
    add  rsp, 64
    pop  rbp
    ret
