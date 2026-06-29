; =============================================================================
; floats.asm  —  Module 12: x87 FPU & SSE2 Scalar Floating Point
; =============================================================================
bits 64

extern print_label
extern print_f64
extern print_u64

section .rodata
    lbl_sse2    db "SSE2 scalar: movsd / addsd / mulsd / divsd", 0
    lbl_cvt     db "Integer <-> float conversions", 0
    lbl_cmp     db "SSE2 float comparisons (ucomisd)", 0
    lbl_x87     db "x87 FPU stack: fld / fadd / fmul / fstp", 0
    lbl_dot     db "Dot product: a=[1.0,2.0,3.0] b=[4.0,5.0,6.0]", 0
    lbl_sqrt    db "sqrtsd: square roots", 0

    ; SSE2 constants (double-precision IEEE 754)
    val_1_0     dq 1.0
    val_2_0     dq 2.0
    val_3_0     dq 3.0
    val_neg     dq -7.5
    val_pi      dq 3.14159265358979323846

    ; Dot product vectors
    vec_a       dq 1.0, 2.0, 3.0
    vec_b       dq 4.0, 5.0, 6.0
    ; Expected: 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32.0

section .text
    global main
    global asm_dot3

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

; ─────────────────────────────────────────────────────────────────────────────
; asm_dot3(const double *a, const double *b) → xmm0 = a[0]*b[0]+a[1]*b[1]+a[2]*b[2]
; ─────────────────────────────────────────────────────────────────────────────
asm_dot3:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    ; rdi = a, rsi = b
    movsd xmm0, [rdi]          ; xmm0 = a[0]
    mulsd xmm0, [rsi]          ; xmm0 = a[0]*b[0]

    movsd xmm1, [rdi+8]        ; xmm1 = a[1]
    mulsd xmm1, [rsi+8]        ; xmm1 = a[1]*b[1]

    movsd xmm2, [rdi+16]       ; xmm2 = a[2]
    mulsd xmm2, [rsi+16]       ; xmm2 = a[2]*b[2]

    addsd xmm0, xmm1           ; xmm0 = a[0]*b[0] + a[1]*b[1]
    addsd xmm0, xmm2           ; xmm0 += a[2]*b[2]
    ret

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32               ; shadow space + alignment

    ; ── SSE2 basics ──────────────────────────────────────────────────────────
    LABEL lbl_sse2

    ; Load a double from memory into xmm0
    movsd xmm0, [rel val_pi]   ; xmm0 = 3.14159...
    SHOWf xmm0                 ; 3.141593

    ; Add two doubles
    movsd xmm0, [rel val_1_0]
    movsd xmm1, [rel val_2_0]
    addsd xmm0, xmm1           ; xmm0 = 1.0 + 2.0 = 3.0
    SHOWf xmm0                 ; 3.000000

    ; Multiply
    movsd xmm0, [rel val_pi]
    movsd xmm1, [rel val_2_0]
    mulsd xmm0, xmm1           ; xmm0 = pi * 2
    SHOWf xmm0                 ; 6.283185

    ; Divide
    movsd xmm0, [rel val_1_0]
    movsd xmm1, [rel val_3_0]
    divsd xmm0, xmm1           ; xmm0 = 1.0 / 3.0
    SHOWf xmm0                 ; 0.333333

    ; Subtract (subsd)
    movsd xmm0, [rel val_3_0]
    movsd xmm1, [rel val_1_0]
    subsd xmm0, xmm1           ; xmm0 = 3.0 - 1.0 = 2.0
    SHOWf xmm0                 ; 2.000000

    ; ── Integer <-> double conversions ──────────────────────────────────────
    LABEL lbl_cvt

    ; int → double
    mov  rax, 42
    cvtsi2sd xmm0, rax         ; xmm0 = (double)42
    SHOWf xmm0                 ; 42.000000

    ; int → double (64-bit integer)
    mov  rax, 1000000000
    cvtsi2sd xmm0, rax
    SHOWf xmm0                 ; 1000000000.000000

    ; double → int64 (truncates toward zero)
    movsd xmm0, [rel val_pi]   ; 3.14159...
    cvttsd2si rax, xmm0        ; rax = (int64_t)3.14... = 3 (truncate)
    SHOWu rax                  ; 3

    ; double → int64 (rounded, not truncated)
    movsd xmm0, [rel val_pi]
    cvtsd2si rax, xmm0         ; rax = round(3.14...) = 3
    SHOWu rax                  ; 3

    ; negative double → int (truncation toward zero)
    movsd xmm0, [rel val_neg]  ; -7.5
    cvttsd2si rax, xmm0        ; rax = (int64_t)(-7.5) = -7 (toward zero)
    SHOWu rax                  ; 0xFFFFFFFFFFFFFFF9 = -7 in two's complement

    ; ── Float comparisons (ucomisd) ──────────────────────────────────────────
    LABEL lbl_cmp

    ; ucomisd sets CF and ZF, not the usual integer flags
    ; Use ja/jb/je for unsigned-style compare
    movsd xmm0, [rel val_pi]
    movsd xmm1, [rel val_3_0]
    ucomisd xmm0, xmm1         ; compare xmm0 (pi) vs xmm1 (3.0)
    ; pi > 3.0 → CF=0, ZF=0 → condition "above" (ja) is true

    mov  rax, 1                ; assume greater
    ja   .pi_gt_3
    mov  rax, 0                ; actually not greater
.pi_gt_3:
    SHOWu rax                  ; 1 (pi > 3.0)

    ; NaN detection: ucomisd with a NaN sets both CF and ZF (unordered)
    ; jp (parity flag set) fires on unordered result

    ; ── sqrtsd ───────────────────────────────────────────────────────────────
    LABEL lbl_sqrt

    movsd xmm0, [rel val_2_0]
    sqrtsd xmm0, xmm0          ; xmm0 = sqrt(2.0)
    SHOWf xmm0                 ; 1.414214

    movsd xmm1, [rel val_3_0]
    sqrtsd xmm1, xmm1
    SHOWf xmm1                 ; 1.732051

    ; ── x87 FPU (legacy but present in all 64-bit CPUs) ─────────────────────
    LABEL lbl_x87

    ; The x87 FPU has an 8-entry stack: st0..st7
    ; fld  pushes a value onto the stack (st0 becomes the new top)
    ; fstp pops the top to memory
    ; All arithmetic operates on st0 and another operand

    fld  qword [rel val_pi]    ; st0 = pi
    fld  qword [rel val_2_0]   ; st0 = 2.0, st1 = pi
    fmulp                      ; st0 = 2.0 * pi (st0 * st1, pop) = 6.2831...
    ; Move x87 result to xmm for printing
    sub  rsp, 8
    fstp qword [rsp]           ; pop st0 into memory
    movsd xmm0, [rsp]          ; xmm0 = 2*pi
    add  rsp, 8
    SHOWf xmm0                 ; 6.283185

    ; x87 fsin (not available in SSE2)
    fld  qword [rel val_pi]    ; st0 = pi
    fsin                       ; st0 = sin(pi) ≈ 0.0 (tiny floating-point error)
    sub  rsp, 8
    fstp qword [rsp]
    movsd xmm0, [rsp]
    add  rsp, 8
    SHOWf xmm0                 ; ~0.000000 (nearly zero)

    ; ── Dot product ──────────────────────────────────────────────────────────
    LABEL lbl_dot

    lea  rdi, [rel vec_a]
    lea  rsi, [rel vec_b]
    mov  rcx, rdi
    mov  rdx, rsi
    call asm_dot3
    ; xmm0 now holds the result
    call print_f64             ; 32.000000

    add  rsp, 32
    pop  rbp
    xor  eax, eax
    ret
