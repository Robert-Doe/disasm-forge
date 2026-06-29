; =============================================================================
; data.asm  —  Module 03: Data Representation & Memory Fundamentals
; =============================================================================
; Demonstrates:
;   1. db/dw/dd/dq directives — defining data of various widths
;   2. .data, .bss, .rodata sections
;   3. Little-endian byte order (reading memory vs reading registers)
;   4. Two's complement: signed negatives in hex
;   5. resb/resw/resd/resq — uninitialized storage in .bss
; =============================================================================

bits 64

extern print_hex_dump       ; defined in data_demo.c — prints a byte array as hex
extern print_u64
extern print_s64            ; prints signed 64-bit integer
extern print_label

; =============================================================================
; .rodata — read-only constants (no write permission at runtime)
; =============================================================================
section .rodata
    lbl_bytes   db "db: individual bytes", 0
    lbl_words   db "dw: 16-bit words (little-endian in memory)", 0
    lbl_dwords  db "dd: 32-bit dwords", 0
    lbl_qwords  db "dq: 64-bit qwords", 0
    lbl_twos    db "Two's complement: negative numbers", 0
    lbl_bss     db ".bss: uninitialized storage (zeroed by OS)", 0
    lbl_float   db "IEEE 754 float 1.0 as raw bits", 0

; =============================================================================
; .data — initialized read-write data
; =============================================================================
section .data

    ; ── db: define byte(s) ───────────────────────────────────────────────────
    ; Each token after db is a separate byte value (0–255)
    byte_vals   db 0x41, 0x42, 0x43, 0x44   ; 'A','B','C','D' — 4 bytes
    byte_count  equ $ - byte_vals            ; $ = current address; this computes 4

    ; ── dw: define word (2 bytes each) ───────────────────────────────────────
    ; 0x1234 is stored as bytes: 0x34, 0x12  (little-endian!)
    word_vals   dw 0x1234, 0x5678            ; 4 bytes total
    word_count  equ $ - word_vals

    ; ── dd: define dword (4 bytes each) ──────────────────────────────────────
    ; 0xDEADBEEF stored as: EF BE AD DE
    dword_val   dd 0xDEADBEEF               ; 4 bytes
    dword_count equ $ - dword_val

    ; ── dq: define qword (8 bytes each) ──────────────────────────────────────
    qword_val   dq 0x0102030405060708       ; 8 bytes: 08 07 06 05 04 03 02 01
    qword_count equ $ - qword_val

    ; ── Two's complement negative numbers ────────────────────────────────────
    ; In two's complement, -1 as a 64-bit value is 0xFFFFFFFFFFFFFFFF
    ; -128 as a byte is 0x80
    neg_one     dq -1                       ; stored as FF FF FF FF FF FF FF FF
    neg_128     db -128                     ; stored as 0x80
    pos_127     db  127                     ; stored as 0x7F

    ; ── IEEE 754 single-precision float 1.0 ──────────────────────────────────
    ; Sign=0, Exponent=127 (0x7F), Mantissa=0  →  0x3F800000
    float_one   dd 1.0                      ; NASM accepts float literals in dd/dq

; =============================================================================
; .bss — uninitialized data (the OS zeroes this before the program starts)
; =============================================================================
section .bss
    ; resb N  = reserve N bytes  (value undefined until OS zeroes it)
    ; resw N  = reserve N words  (2*N bytes)
    ; resd N  = reserve N dwords (4*N bytes)
    ; resq N  = reserve N qwords (8*N bytes)
    bss_buf     resb 16                     ; 16 bytes, will be zero at startup
    bss_counter resq 1                      ; one 64-bit slot

; =============================================================================
; .text — executable code
; =============================================================================
section .text
    global main

%macro LABEL 1
    lea  rdi, [rel %1]
    lea  rcx, [rel %1]
    call print_label
%endmacro

%macro SHOW_U64 1
    mov  rdi, %1
    mov  rcx, %1
    call print_u64
%endmacro

%macro SHOW_S64 1
    mov  rdi, %1
    mov  rcx, %1
    call print_s64
%endmacro

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32                ; shadow space

    ; ── Show raw bytes (db) ──────────────────────────────────────────────────
    LABEL lbl_bytes
    lea  rdi, [rel byte_vals]   ; pointer to the data
    lea  rcx, [rel byte_vals]
    mov  rsi, byte_count        ; number of bytes
    mov  rdx, byte_count
    call print_hex_dump

    ; ── Show words (dw) — observe little-endian ──────────────────────────────
    LABEL lbl_words
    lea  rdi, [rel word_vals]
    lea  rcx, [rel word_vals]
    mov  rsi, word_count
    mov  rdx, word_count
    call print_hex_dump

    ; ── Show dword (dd) ──────────────────────────────────────────────────────
    LABEL lbl_dwords
    lea  rdi, [rel dword_val]
    lea  rcx, [rel dword_val]
    mov  rsi, dword_count
    mov  rdx, dword_count
    call print_hex_dump

    ; ── Show qword (dq) ──────────────────────────────────────────────────────
    LABEL lbl_qwords
    lea  rdi, [rel qword_val]
    lea  rcx, [rel qword_val]
    mov  rsi, qword_count
    mov  rdx, qword_count
    call print_hex_dump

    ; ── Load qword into register and show it ─────────────────────────────────
    ; Notice: the bytes in memory are 08 07 06 05 04 03 02 01
    ; but rax will contain 0x0102030405060708 (little-endian reassembly)
    mov  rax, [rel qword_val]
    SHOW_U64 rax

    ; ── Two's complement ─────────────────────────────────────────────────────
    LABEL lbl_twos
    mov  rax, [rel neg_one]     ; load the -1 qword
    SHOW_S64 rax                ; prints "-1"
    SHOW_U64 rax                ; prints "18446744073709551615" and 0xFFFF...FFFF

    ; ── IEEE 754 ─────────────────────────────────────────────────────────────
    LABEL lbl_float
    lea  rdi, [rel float_one]
    lea  rcx, [rel float_one]
    mov  rsi, 4                 ; 4 bytes = single precision
    mov  rdx, 4
    call print_hex_dump         ; expect: 00 00 80 3F  (little-endian 0x3F800000)

    ; ── .bss demo ────────────────────────────────────────────────────────────
    LABEL lbl_bss
    lea  rdi, [rel bss_buf]
    lea  rcx, [rel bss_buf]
    mov  rsi, 16
    mov  rdx, 16
    call print_hex_dump         ; expect: 16 zero bytes

    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
