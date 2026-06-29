; =============================================================================
; bits.asm  —  Module 05: Bitwise Operations & Bit Manipulation
; =============================================================================
bits 64

extern print_u64
extern print_label

section .rodata
    lbl_logic  db "and / or / xor / not", 0
    lbl_shifts db "shl / shr / sar (arithmetic) / rol / ror", 0
    lbl_rotate db "rcl / rcr — rotate through carry", 0
    lbl_btest  db "bt / bts / btr / btc — bit test and modify", 0
    lbl_scan   db "bsf / bsr — bit scan forward / reverse", 0
    lbl_pop    db "popcnt / tzcnt / lzcnt", 0
    lbl_tricks db "Security patterns: masking, nibble extract, fast divide", 0

section .text
    global main

%macro LABEL 1
    lea rdi,[rel %1] | lea rcx,[rel %1] | call print_label
%endmacro
%macro SHOWu 1
    mov rdi,%1 | mov rcx,%1 | call print_u64
%endmacro

; NASM doesn't allow | for separating instructions — use separate lines
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

main:
    push rbp
    mov  rbp, rsp
    sub  rsp, 32

    ; ── Logical operations ───────────────────────────────────────────────────
    LABEL lbl_logic

    ; AND: both bits must be 1
    mov  rax, 0xFF00FF00FF00FF00
    and  rax, 0x0F0F0F0F0F0F0F0F   ; isolate lower nibbles
    SHOWu rax                       ; 0x0F000F000F000F00

    ; OR: either bit can be 1
    mov  rax, 0xFF00000000000000
    or   rax, 0x00000000000000FF   ; set lower byte
    SHOWu rax                       ; 0xFF000000000000FF

    ; XOR: bits differ → 1, same → 0
    mov  rax, 0xDEADBEEFCAFEBABE
    xor  rax, rax                   ; anything XOR itself = 0  (canonical zero)
    SHOWu rax                       ; 0

    ; XOR as toggle: flip specific bits without affecting others
    mov  rax, 0b10110011            ; binary literal
    xor  rax, 0b00001111            ; flip the lower 4 bits
    SHOWu rax                       ; 0b10111100 = 0xBC

    ; NOT: flip every bit (one's complement, not two's complement)
    mov  rax, 0x00FF00FF00FF00FF
    not  rax
    SHOWu rax                       ; 0xFF00FF00FF00FF00

    ; ── Shifts ───────────────────────────────────────────────────────────────
    LABEL lbl_shifts

    ; SHL: shift left (fill with 0 on right) — multiply by powers of 2
    mov  rax, 1
    shl  rax, 10                    ; 1 << 10 = 1024
    SHOWu rax

    ; SHR: logical shift right (fill with 0 on left) — unsigned divide by 2^n
    mov  rax, 1024
    shr  rax, 3                     ; 1024 >> 3 = 128
    SHOWu rax

    ; SAR: arithmetic shift right (fill with SIGN BIT) — signed divide by 2^n
    mov  rax, -128                  ; 0xFFFFFFFFFFFFFF80
    sar  rax, 3                     ; -128 / 8 = -16  (sign bit preserved)
    SHOWu rax                       ; 0xFFFFFFFFFFFFFFF0 = -16 as signed

    ; SHR vs SAR on a negative value — critical difference
    mov  rax, -128
    shr  rax, 3                     ; logical: fills with 0 → large positive number
    SHOWu rax                       ; 0x1FFFFFFFFFFFFFF0 — NOT -16!

    ; ── Rotates ──────────────────────────────────────────────────────────────
    LABEL lbl_shifts

    ; ROL: rotate left (bit shifted out of MSB goes into LSB)
    mov  rax, 0x8000000000000001    ; MSB and LSB both set
    rol  rax, 1                     ; 0x0000000000000003  (MSB rotated to LSB)
    SHOWu rax

    ; ROR: rotate right
    mov  rax, 0x8000000000000001
    ror  rax, 1                     ; 0xC000000000000000  (LSB rotated to MSB)
    SHOWu rax

    ; ── Bit test instructions ─────────────────────────────────────────────────
    LABEL lbl_btest

    ; BT: test bit N, copy to CF
    mov  rax, 0b10110101
    bt   rax, 2                     ; test bit 2 (value=1) → CF=1
    ; (we can't easily print CF here; use GDB to verify)

    ; BTS: bit test and SET
    mov  rax, 0b10110101
    bts  rax, 1                     ; set bit 1; old value of bit 1 → CF
    SHOWu rax                       ; 0b10110111 — bit 1 now set

    ; BTR: bit test and RESET (clear)
    mov  rax, 0b10110111
    btr  rax, 2                     ; clear bit 2
    SHOWu rax                       ; 0b10110011

    ; BTC: bit test and COMPLEMENT (toggle)
    mov  rax, 0b10110011
    btc  rax, 7                     ; toggle bit 7
    SHOWu rax                       ; 0b00110011 (bit 7 was 1, now 0)

    ; ── Bit scan ─────────────────────────────────────────────────────────────
    LABEL lbl_scan

    ; BSF: bit scan forward — index of lowest set bit
    mov  rax, 0b00101000            ; bits 3 and 5 are set
    bsf  rbx, rax                   ; rbx = 3  (lowest set bit index)
    SHOWu rbx

    ; BSR: bit scan reverse — index of highest set bit
    bsr  rbx, rax                   ; rbx = 5  (highest set bit index)
    SHOWu rbx

    ; ── POPCNT / TZCNT / LZCNT ───────────────────────────────────────────────
    LABEL lbl_pop

    ; POPCNT: count the number of 1-bits (population count)
    mov  rax, 0xFF0F0F0F0F0F0F0F
    popcnt rbx, rax                 ; rbx = count of 1-bits
    SHOWu rbx

    ; TZCNT: count trailing zeros (lowest N bits are 0)
    mov  rax, 0b00101000            ; 3 trailing zeros
    tzcnt rbx, rax
    SHOWu rbx                       ; 3

    ; LZCNT: count leading zeros
    mov  rax, 0x0000000000000001   ; only bit 0 set → 63 leading zeros
    lzcnt rbx, rax
    SHOWu rbx                       ; 63

    ; ── Security patterns ─────────────────────────────────────────────────────
    LABEL lbl_tricks

    ; Extract lower nibble (4 bits) of a byte
    mov  rax, 0xAB
    and  rax, 0x0F                  ; mask: keep only bits 3-0
    SHOWu rax                       ; 0x0B

    ; Extract upper nibble
    mov  rax, 0xAB
    shr  rax, 4                     ; shift upper nibble down
    SHOWu rax                       ; 0x0A

    ; Fast divide by 8 (power of two) using right shift
    mov  rax, 1000
    shr  rax, 3                     ; 1000 / 8 = 125 (unsigned)
    SHOWu rax

    ; Test if a number is a power of two: (n & (n-1)) == 0
    mov  rax, 64
    mov  rbx, rax
    dec  rbx                        ; rbx = 63 = 0b00111111
    and  rbx, rax                   ; 64 & 63 = 0 → rax IS a power of two
    SHOWu rbx                       ; 0

    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
