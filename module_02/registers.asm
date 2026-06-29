; =============================================================================
; registers.asm  —  Module 02: Registers, Every Single One
; =============================================================================
; Demonstrates:
;   1. The zero-extension rule: writing eax zeros the top 32 bits of rax
;   2. Sub-register aliasing: al, ah, ax, eax, rax all overlap the same storage
;   3. Using r8–r15 (the new 64-bit-only registers)
;   4. Why xor eax,eax is the canonical way to zero rax
; =============================================================================

bits 64

; ── External C helpers (defined in print_helper.c) ───────────────────────────
extern print_u64
extern print_label

; ── Read-only strings in .data ────────────────────────────────────────────────
section .data
    lbl_zero_ext  db "Zero-extension: writing to eax clears top 32 bits of rax", 0
    lbl_subregister db "Sub-register aliasing: al / ah / ax / eax / rax", 0
    lbl_new_regs  db "New 64-bit registers: r8 through r15", 0
    lbl_xor_zero  db "Canonical zero: xor eax,eax vs mov rax,0", 0

section .text
    global main

; ── Helper macro: call print_u64 with rax as the argument ────────────────────
; (We will learn the proper way to pass arguments in Module 09.
;  For now: Linux puts first arg in rdi, Windows in rcx.
;  We use a compile-time platform flag set by the Makefile.)
;
; To keep this module platform-independent we route through a C wrapper.
; The wrapper's signature is:  void print_u64(uint64_t value)
; On Linux the first arg lives in rdi; on Windows in rcx.
; We set BOTH so the same .asm runs after either Makefile path assembles it.
; (Setting an unused register is harmless.)

%macro SHOW 0
    mov  rdi, rax          ; Linux  first arg
    mov  rcx, rax          ; Windows first arg
    call print_u64
%endmacro

%macro LABEL 1
    lea  rdi, [rel %1]     ; Linux  first arg  (RIP-relative address)
    lea  rcx, [rel %1]     ; Windows first arg
    call print_label
%endmacro

; =============================================================================
main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32           ; shadow space for Windows (harmless on Linux)

    ; ── Demo 1: Zero-extension rule ──────────────────────────────────────────
    LABEL lbl_zero_ext

    mov  rax, 0xDEADBEEFCAFEBABE   ; fill all 64 bits of rax
    SHOW                            ; prints the full 64-bit value

    mov  eax, 0x12345678            ; write to eax (32-bit)
                                    ; RESULT: upper 32 bits of rax become 0
                                    ; rax is now 0x0000000012345678
    SHOW                            ; proves the upper half was zeroed

    ; ── Demo 2: Sub-register aliasing ────────────────────────────────────────
    LABEL lbl_subregister

    mov  rax, 0xAAAAAAAAAAAAAAAA    ; set a known pattern
    mov  al,  0x11                  ; write the lowest byte only
                                    ; rax is now 0xAAAAAAAAAAAAAA11
                                    ; Note: al write does NOT zero upper bits!
    SHOW

    mov  ah,  0x22                  ; write byte 1 (bits 8–15)
                                    ; rax is now 0xAAAAAAAAAAAA2211
    SHOW

    mov  ax,  0x3344                ; write the low 16-bit word
                                    ; rax is now 0xAAAAAAAAAAAA3344
    SHOW

    mov  eax, 0x55667788            ; write the low 32 bits — ZEROS upper 32!
                                    ; rax is now 0x0000000055667788
    SHOW

    ; ── Demo 3: r8–r15 registers ─────────────────────────────────────────────
    LABEL lbl_new_regs

    mov  r8,  0x0800000000000008    ; r8  through r15 are full 64-bit registers
    mov  r9,  0x0900000000000009    ; added in x86-64; not present in 32-bit mode
    mov  r10, 0x0A0000000000000A
    mov  r15, 0x0F0000000000000F

    mov  rax, r8   ; move r8 into rax so SHOW can print it
    SHOW
    mov  rax, r9
    SHOW
    mov  rax, r10
    SHOW
    mov  rax, r15
    SHOW

    ; r8d, r8w, r8b — same sub-register aliasing applies to r8–r15
    mov  r8,  0xFFFFFFFFFFFFFFFF   ; all bits set
    mov  r8d, 0x00000001           ; writing r8d (32-bit) zeros upper 32 bits of r8
    mov  rax, r8
    SHOW                            ; expect 0x0000000000000001

    ; ── Demo 4: xor eax,eax — the canonical zero ─────────────────────────────
    LABEL lbl_xor_zero

    ; Option A: mov rax, 0  (7 bytes: REX prefix + opcode + 8-byte immediate)
    mov  rax, 0xFFFFFFFFFFFFFFFF
    mov  rax, 0                    ; clears rax — 7 bytes in the encoding
    SHOW

    ; Option B: xor eax, eax  (2 bytes: opcode + ModRM)
    ; Writing to eax zeros the upper 32 bits (zero-extension rule again).
    ; xor of anything with itself is always 0.
    ; This is the idiom every compiler uses — two bytes vs seven.
    mov  rax, 0xFFFFFFFFFFFFFFFF
    xor  eax, eax                  ; 2-byte instruction; rax is now 0
    SHOW

    ; ── Clean exit ───────────────────────────────────────────────────────────
    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
