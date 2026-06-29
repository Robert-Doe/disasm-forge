; =============================================================================
; addressing.asm  —  Module 10: Memory Addressing Modes
; =============================================================================
bits 64

extern print_label
extern print_u64
extern print_ptr

section .rodata
    lbl_imm     db "Immediate: value encoded in instruction", 0
    lbl_reg     db "Register: value in a register", 0
    lbl_direct  db "Direct (absolute): [address]", 0
    lbl_indir   db "Register-indirect: [reg]", 0
    lbl_scaled  db "Scaled-index: [base + index*scale + disp]", 0
    lbl_lea     db "LEA: address arithmetic without memory access", 0
    lbl_rip     db "RIP-relative: [rel label]", 0
    lbl_2d      db "2D array walk using scaled-index", 0
    lbl_sizes   db "Size overrides: BYTE/WORD/DWORD/QWORD PTR", 0

section .data
    ; A 3x4 array of int32_t (each element = 4 bytes)
    ; Row 0: 10 11 12 13
    ; Row 1: 20 21 22 23
    ; Row 2: 30 31 32 33
    array2d  dd 10,11,12,13, 20,21,22,23, 30,31,32,33
    COLS     equ 4           ; number of columns
    ELEM     equ 4           ; bytes per element (int32_t)

    direct_val  dq 0xCAFEBABEDEADBEEF
    byte_val    db 0xAB, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

section .text
    global main

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
%macro SHOWp 1
    mov  rdi, %1
    mov  rcx, rdi
    call print_ptr
%endmacro

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 64

    ; ── Mode 1: Immediate ────────────────────────────────────────────────────
    LABEL lbl_imm
    ; The value is embedded directly in the instruction encoding
    mov  rax, 42            ; 42 is an immediate — no memory access needed
    SHOWu rax

    ; ── Mode 2: Register ─────────────────────────────────────────────────────
    LABEL lbl_reg
    mov  rbx, 0x1234
    mov  rax, rbx           ; value comes from rbx — no memory access
    SHOWu rax

    ; ── Mode 3: Direct (absolute address) ────────────────────────────────────
    LABEL lbl_direct
    ; [label] dereferences the address of label
    ; In 64-bit, absolute addresses are 64 bits — rarely used directly
    ; We use RIP-relative instead (see below), but this shows the concept
    mov  rax, [rel direct_val]
    SHOWu rax               ; 0xCAFEBABEDEADBEEF

    ; ── Mode 4: Register-indirect ────────────────────────────────────────────
    LABEL lbl_indir
    ; [reg] reads the memory at the address stored in reg
    lea  rbx, [rel direct_val]   ; rbx = address of direct_val
    mov  rax, [rbx]              ; dereference: rax = *rbx
    SHOWu rax               ; 0xCAFEBABEDEADBEEF

    ; pointer increment
    add  rbx, 4             ; advance 4 bytes
    mov  eax, [rbx]         ; read 4-byte value at new position
    SHOWu rax               ; upper 32 bits: 0xCAFEBABE (but zero-extended)

    ; ── Mode 5: Scaled-index [base + index*scale + disp] ─────────────────────
    LABEL lbl_scaled
    ; Full form: [base_reg + index_reg * scale + displacement]
    ; scale must be 1, 2, 4, or 8
    ; displacement is a signed 8-bit or 32-bit constant

    lea  rbx, [rel array2d]     ; rbx = base address of array

    ; Access array2d[1][2] = 22
    ; Address = base + (row * COLS + col) * ELEM
    ;         = rbx + (1   * 4    + 2  ) * 4
    ;         = rbx + 6 * 4 = rbx + 24
    mov  rax, 1              ; row = 1
    imul rax, COLS           ; rax = row * COLS = 4
    add  rax, 2              ; rax = 4 + col(2) = 6  (element index)
    mov  eax, [rbx + rax*ELEM]  ; [base + index*4] = array2d[1][2]
    SHOWu rax               ; 22

    ; Access array2d[2][3] = 33 using displacement
    ; Element index = 2*4 + 3 = 11
    ; Displacement = 11*4 = 44 bytes
    mov  eax, [rbx + 44]    ; direct offset from base
    SHOWu rax               ; 33

    ; ── LEA: load effective address without memory access ─────────────────────
    LABEL lbl_lea
    ; lea dst, [expr]  computes the address expression and stores it in dst
    ; — NO memory is read. This is just arithmetic using the addressing unit.

    ; Multiply rdi by 5 in one instruction: rdi*4 + rdi = rdi*5
    mov  rdi, 7
    lea  rax, [rdi + rdi*4]  ; rax = 7 + 7*4 = 35  (multiply by 5, no MUL!)
    SHOWu rax               ; 35

    ; Compute address of array2d[2][1] without a load
    lea  rbx, [rel array2d]
    mov  rdi, 2              ; row
    mov  rsi, 1              ; col
    imul rdi, COLS           ; row * COLS
    add  rdi, rsi            ; + col = element index (9)
    lea  rax, [rbx + rdi*ELEM]   ; address of array2d[2][1] — no load
    SHOWp rax               ; some address in .data

    ; Now dereference it to get the value
    mov  eax, [rax]
    SHOWu rax               ; 31

    ; ── RIP-relative addressing ───────────────────────────────────────────────
    LABEL lbl_rip
    ; [rel label] = [rip + (label - next_instruction)]
    ; This is position-independent — it works regardless of where the binary loads
    ; ALL data accesses in this program use [rel ...] for this reason
    lea  rax, [rel direct_val]
    SHOWp rax               ; address of direct_val

    ; Compute the offset from rip to direct_val
    ; (just showing that [rel label] is how you access .data in PIE binaries)
    mov  rax, [rel direct_val]
    SHOWu rax               ; 0xCAFEBABEDEADBEEF

    ; ── Size overrides ────────────────────────────────────────────────────────
    LABEL lbl_sizes
    lea  rbx, [rel byte_val]

    movzx rax, byte [rbx]       ; load 1 byte, zero-extend to 64 bits
    SHOWu rax                   ; 0xAB

    movzx rax, word [rbx]       ; load 2 bytes, zero-extend
    SHOWu rax                   ; 0x00AB (byte_val[0]=AB, [1]=00)

    mov   eax, dword [rbx]      ; load 4 bytes (zero-extends to rax)
    SHOWu rax                   ; 0x000000AB

    mov   rax, qword [rbx]      ; load 8 bytes
    SHOWu rax                   ; 0x00000000000000AB

    ; ── 2D array walk ─────────────────────────────────────────────────────────
    LABEL lbl_2d
    lea  rbx, [rel array2d]
    xor  r12, r12           ; row = 0

.row_loop:
    cmp  r12, 3
    jge  .array_done
    xor  r13, r13           ; col = 0

.col_loop:
    cmp  r13, 4
    jge  .next_row
    ; element address = base + (row*COLS + col)*ELEM
    mov  rax, r12
    imul rax, COLS
    add  rax, r13
    mov  eax, [rbx + rax*ELEM]
    SHOWu rax
    inc  r13
    jmp  .col_loop

.next_row:
    inc  r12
    jmp  .row_loop
.array_done:

    xor  eax, eax
    add  rsp, 64
    pop  rbp
    ret
