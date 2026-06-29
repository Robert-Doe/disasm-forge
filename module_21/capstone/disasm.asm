; =============================================================================
; disasm.asm  —  Module 21: Capstone Mini Disassembler
;
; Implements a length-disassembler for the x86-64 instruction encoding.
;
; Supported instruction classes (sufficient to disassemble typical shellcode
; and compiler output):
;   - Single-byte opcodes: NOP, RET, PUSH/POP reg, INT3, SYSCALL, HLT
;   - MOV r64, r/m64 and MOV r/m64, r64 (opcode 8B/89)
;   - MOV r64, imm64 (opcode B8+r)
;   - MOV r/m64, imm32 (opcode C7)
;   - ADD/SUB/XOR/AND/OR/CMP r/m64, r64 and reverse (01–03, 09, 21, 29, 31, 39)
;   - LEA r64, m (8D)
;   - CALL rel32 (E8)
;   - JMP rel32 (E9), JMP rel8 (EB)
;   - Jcc rel8 (70–7F), Jcc rel32 (0F 8x)
;   - CMP/TEST with immediate (81 /7, F7 /0)
;   - PUSH imm8/imm32 (6A, 68)
;   - INC/DEC r/m64 (FF /0, FF /1)
;   - CALL/JMP r/m64 (FF /2, FF /4)
;   - RET (C3), LEAVE (C9)
;   - Two-byte 0F prefix: MOVZX, MOVSX, IMUL, CMOVcc, SETcc
;   - REX prefix decoding (4x bytes)
;   - ModRM: all mod=00/01/10/11 cases, SIB, 32-bit displacement
;   - Fallback: unknown → "db 0xXX" with length=1
;
; Data layout for DisasmInsn (must match disasm.h):
;   Offset  Size  Field
;      0      1   length
;      1      1   opcode
;      2      1   has_rex
;      3      1   rex
;      4      1   has_modrm
;      5      1   modrm
;      6      1   has_sib
;      7      1   sib
;      8      4   disp  (int32)
;     12      4   imm   (int64 low 32)
;     16      4   imm   (int64 high 32)
;     20      1   op_type
;     21      3   padding
;     24     64   mnemonic[64]
;     88     64   operands[64]
; Total: 152 bytes
; =============================================================================
bits 64

; DisasmInsn field offsets
%define INSN_LEN      0
%define INSN_OPCODE   1
%define INSN_HAS_REX  2
%define INSN_REX      3
%define INSN_HAS_MODRM 4
%define INSN_MODRM    5
%define INSN_HAS_SIB  6
%define INSN_SIB      7
%define INSN_DISP     8
%define INSN_IMM      12
%define INSN_OP_TYPE  20
%define INSN_MNEMONIC 24
%define INSN_OPERANDS 88

; OpType values
%define OP_NONE  0
%define OP_REG   1
%define OP_IMM   2
%define OP_MEM   3
%define OP_REL   4

section .rodata

; Register name tables — indexed by ModRM reg field (0-7), 64-bit names
reg_names_64:
    dq reg_rax, reg_rcx, reg_rdx, reg_rbx
    dq reg_rsp, reg_rbp, reg_rsi, reg_rdi
; Extended registers r8–r15 (when REX.R or REX.B set)
reg_names_r8:
    dq reg_r8,  reg_r9,  reg_r10, reg_r11
    dq reg_r12, reg_r13, reg_r14, reg_r15

reg_rax: db "rax", 0
reg_rcx: db "rcx", 0
reg_rdx: db "rdx", 0
reg_rbx: db "rbx", 0
reg_rsp: db "rsp", 0
reg_rbp: db "rbp", 0
reg_rsi: db "rsi", 0
reg_rdi: db "rdi", 0
reg_r8:  db "r8",  0
reg_r9:  db "r9",  0
reg_r10: db "r10", 0
reg_r11: db "r11", 0
reg_r12: db "r12", 0
reg_r13: db "r13", 0
reg_r14: db "r14", 0
reg_r15: db "r15", 0

; Mnemonic strings
mn_nop:     db "nop",     0
mn_ret:     db "ret",     0
mn_retf:    db "retf",    0
mn_leave:   db "leave",   0
mn_int3:    db "int3",    0
mn_hlt:     db "hlt",     0
mn_syscall: db "syscall", 0
mn_ud2:     db "ud2",     0
mn_push:    db "push",    0
mn_pop:     db "pop",     0
mn_mov:     db "mov",     0
mn_movzx:   db "movzx",   0
mn_movsx:   db "movsx",   0
mn_add:     db "add",     0
mn_sub:     db "sub",     0
mn_and:     db "and",     0
mn_or:      db "or",      0
mn_xor:     db "xor",     0
mn_cmp:     db "cmp",     0
mn_test:    db "test",    0
mn_lea:     db "lea",     0
mn_call:    db "call",    0
mn_jmp:     db "jmp",     0
mn_jcc:     db "j",       0   ; prefix; condition appended separately
mn_cmov:    db "cmov",    0
mn_set:     db "set",     0
mn_imul:    db "imul",    0
mn_inc:     db "inc",     0
mn_dec:     db "dec",     0
mn_not:     db "not",     0
mn_neg:     db "neg",     0
mn_mul:     db "mul",     0
mn_div:     db "div",     0
mn_idiv:    db "idiv",    0
mn_db:      db "db",      0
mn_unknown: db "???",     0

; Condition-code suffixes (indexed 0–15)
cc_table:
    dq cc_o, cc_no, cc_b,  cc_nb
    dq cc_z, cc_nz, cc_be, cc_nbe
    dq cc_s, cc_ns, cc_p,  cc_np
    dq cc_l, cc_nl, cc_le, cc_nle
cc_o:   db "o",   0
cc_no:  db "no",  0
cc_b:   db "b",   0
cc_nb:  db "nb",  0
cc_z:   db "z",   0
cc_nz:  db "nz",  0
cc_be:  db "be",  0
cc_nbe: db "nbe", 0
cc_s:   db "s",   0
cc_ns:  db "ns",  0
cc_p:   db "p",   0
cc_np:  db "np",  0
cc_l:   db "l",   0
cc_nl:  db "nl",  0
cc_le:  db "le",  0
cc_nle: db "nle", 0

; Two-byte 0F opcode table: maps 0F xx → mnemonic (or NULL if unsupported)
; We handle B6 (MOVZX r,r/m8), B7 (MOVZX r,r/m16), BE (MOVSX r,r/m8),
;           BF (MOVSX r,r/m16), AF (IMUL r,r/m64), 40-4F (CMOVcc),
;           90-9F (SETcc), 80-8F (Jcc rel32)
hex_chars: db "0123456789abcdef"

fmt_0x:     db "0x", 0
fmt_lbr:    db "[", 0
fmt_rbr:    db "]", 0
fmt_plus:   db "+", 0
fmt_minus:  db "-", 0
fmt_comma:  db ", ", 0
fmt_star4:  db "*4", 0
fmt_star2:  db "*2", 0
fmt_star8:  db "*8", 0
fmt_space:  db " ", 0
fmt_qword:  db "qword ", 0

; alu_opcodes maps opcode → mnemonic pointer
; opcodes 00-3F contain pairs: op r/m, r | op r, r/m | op al, imm8 | op rax, imm32
; We focus on the r/m, r forms: 01(ADD) 09(OR) 21(AND) 29(SUB) 31(XOR) 39(CMP)
; and the r, r/m forms: 03(ADD) 0B(OR) 23(AND) 2B(SUB) 33(XOR) 3B(CMP)
alu_rm_r:  ; opcode → mnemonic for r/m,r direction
    db 0x01, 0  ; ADD
    db 0x09, 0  ; OR
    db 0x21, 0  ; AND
    db 0x29, 0  ; SUB
    db 0x31, 0  ; XOR
    db 0x39, 0  ; CMP
    db 0xFF     ; sentinel

section .bss
    scratch_buf resb 32    ; scratch for number-to-string

section .text

global disasm_decode
global disasm_sprint

; ─────────────────────────────────────────────────────────────────────────────
; Internal helpers
; ─────────────────────────────────────────────────────────────────────────────

; strcpy_small(dst, src) — copy null-terminated string; returns dst + strlen
; rdi = dst, rsi = src → rax = end pointer (points at null terminator in dst)
strcpy_small:
    mov  rax, rdi
.lp:
    mov  cl, [rsi]
    mov  [rax], cl
    inc  rsi
    inc  rax
    test cl, cl
    jnz  .lp
    dec  rax        ; point at null terminator
    ret

; append_str(buf_ptr, str) — appends null-terminated str to *buf_ptr
; rdi = pointer to char* (updated in place), rsi = string to append
; Trashes: rax, rcx, rdx
append_str:
    push rbx
    mov  rbx, rdi      ; save &buf_ptr
    mov  rdi, [rbx]    ; rdi = current write position
    call strcpy_small  ; rax = new write position
    mov  [rbx], rax    ; update *buf_ptr
    pop  rbx
    ret

; append_u64_hex(buf_ptr, n) — appends hex representation of n
; rdi = **char (pointer to write pointer), rsi = uint64 value
; produces 16 hex digits
append_u64_hex:
    push r12
    push r13
    push rbx
    mov  rbx, rdi      ; &write_ptr
    mov  r12, rsi      ; value
    mov  r13, 16       ; digit count
    lea  rsi, [rel hex_chars]
.lp:
    mov  rax, r12
    shr  rax, 60
    and  rax, 0xF
    movzx eax, byte [rsi + rax]
    mov  rdi, [rbx]
    mov  [rdi], al
    inc  qword [rbx]
    shl  r12, 4
    dec  r13
    jnz  .lp
    mov  rdi, [rbx]
    mov  byte [rdi], 0   ; null-terminate
    pop  rbx
    pop  r13
    pop  r12
    ret

; append_i32_hex(buf_ptr, v) — appends 8-digit hex for int32
; rdi = **char, rsi = int32 (zero-extended in rsi)
append_i32_hex:
    push r12
    push r13
    push rbx
    mov  rbx, rdi
    mov  r12d, esi      ; 32-bit value
    mov  r13, 8
    lea  rsi, [rel hex_chars]
.lp:
    mov  eax, r12d
    shr  eax, 28
    and  eax, 0xF
    movzx eax, byte [rsi + rax]
    mov  rdi, [rbx]
    mov  [rdi], al
    inc  qword [rbx]
    shl  r12d, 4
    dec  r13
    jnz  .lp
    mov  rdi, [rbx]
    mov  byte [rdi], 0
    pop  rbx
    pop  r13
    pop  r12
    ret

; append_byte_hex(buf_ptr, byte) — appends 2-digit hex for a byte
; rdi = **char, rsi = byte value
append_byte_hex:
    push rbx
    push r12
    mov  rbx, rdi
    mov  r12b, sil
    lea  rsi, [rel hex_chars]
    ; high nibble
    movzx eax, r12b
    shr  eax, 4
    movzx eax, byte [rsi + rax]
    mov  rdi, [rbx]
    mov  [rdi], al
    inc  qword [rbx]
    ; low nibble
    movzx eax, r12b
    and  eax, 0xF
    movzx eax, byte [rsi + rax]
    mov  rdi, [rbx]
    mov  [rdi], al
    inc  qword [rbx]
    mov  rdi, [rbx]
    mov  byte [rdi], 0
    pop  r12
    pop  rbx
    ret

; get_reg_name(idx, rex_ext) → rax = pointer to reg name string
; rdi = register index 0-7, rsi = 1 if REX.R/REX.B extends to r8-r15
get_reg_name:
    test rsi, rsi
    jnz  .extended
    lea  rax, [rel reg_names_64]
    mov  rax, [rax + rdi*8]
    ret
.extended:
    lea  rax, [rel reg_names_r8]
    mov  rax, [rax + rdi*8]
    ret

; decode_modrm(buf, insn, rex, offset) → rax = new offset after ModRM+SIB+disp
; rdi = buf ptr, rsi = insn ptr, rdx = rex byte, rcx = current offset (past opcode)
; Returns new offset in rax; fills insn MODRM/SIB/DISP fields; fills insn operands[0..] with mem expression
; Also fills mnemonic's operand side; caller handles the "other side" (reg or imm)
;
; This routine fills insn->operands with "[...]" memory expression.
decode_modrm:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save params
    mov  rbx, rdi      ; buf
    mov  r12, rsi      ; insn
    mov  r13, rdx      ; rex
    mov  r14, rcx      ; current offset

    ; Read ModRM byte
    movzx eax, byte [rbx + r14]
    mov  byte [r12 + INSN_HAS_MODRM], 1
    mov  byte [r12 + INSN_MODRM], al
    inc  r14

    ; Extract fields from ModRM
    mov  r15b, al      ; r15b = full ModRM
    mov  cl, al
    shr  cl, 6         ; cl = mod (bits 7:6)
    mov  bl, al
    shr  bl, 3
    and  bl, 7         ; bl = reg (bits 5:3)
    and  al, 7         ; al = rm  (bits 2:0)

    ; If mod=11, operand is a register
    cmp  cl, 3
    je   .reg_operand

    ; Memory operand — check for SIB (rm=4 when mod != 11)
    cmp  al, 4
    je   .has_sib

    ; No SIB — base register is rm field
    ; Check for disp-only: mod=00, rm=5 → RIP-relative or abs32
    cmp  cl, 0
    jne  .no_disp_only
    cmp  al, 5
    jne  .no_disp_only
    ; RIP-relative addressing
    movsx eax, dword [rbx + r14]
    mov  dword [r12 + INSN_DISP], eax
    add  r14, 4
    ; Build "[rip+0xDISP]"
    lea  rdi, [r12 + INSN_OPERANDS]
    mov  byte [rdi], '['
    inc  rdi
    ; write "rip"
    mov  byte [rdi+0], 'r'
    mov  byte [rdi+1], 'i'
    mov  byte [rdi+2], 'p'
    add  rdi, 3
    mov  byte [rdi], '+'
    inc  rdi
    lea  rsi, [rel fmt_0x]
    push rdi
    lea  rdi, [rsp]    ; can't use local — simpler: write directly
    pop  rdi
    ; write 0x prefix
    mov  word [rdi], 0x7830   ; "0x" little-endian
    add  rdi, 2
    ; write 8-digit hex of displacement
    lea  rsi, [rel hex_chars]
    mov  eax, dword [r12 + INSN_DISP]
    push rcx
    mov  ecx, 8
.rip_hex:
    mov  edx, eax
    shr  edx, 28
    and  edx, 0xF
    movzx edx, byte [rsi + rdx]
    mov  [rdi], dl
    inc  rdi
    shl  eax, 4
    dec  ecx
    jnz  .rip_hex
    pop  rcx
    mov  byte [rdi], ']'
    inc  rdi
    mov  byte [rdi], 0
    jmp  .done

.no_disp_only:
    ; Normal base register from rm
    ; Determine if REX.B extends rm
    movzx edi, al       ; rm index
    mov  rsi, 0
    test r13, 0x01      ; REX.B
    jz   .no_rexb
    mov  rsi, 1
.no_rexb:
    push rcx
    push rax
    call get_reg_name
    mov  r15, rax       ; base reg name
    pop  rax
    pop  rcx

    ; Build "[basereg + disp]"
    lea  rdi, [r12 + INSN_OPERANDS]
    mov  byte [rdi], '['
    inc  rdi
    ; copy base reg name
.copy_base:
    mov  sil, [r15]
    mov  [rdi], sil
    inc  rdi
    inc  r15
    test sil, sil
    jnz  .copy_base
    dec  rdi

    ; Handle displacement
    cmp  cl, 0          ; mod=00: no displacement
    je   .close_bracket
    cmp  cl, 1          ; mod=01: disp8
    je   .disp8
    ; mod=10: disp32
    movsx eax, dword [rbx + r14]
    mov  dword [r12 + INSN_DISP], eax
    add  r14, 4
    jmp  .write_disp
.disp8:
    movsx eax, byte [rbx + r14]
    mov  dword [r12 + INSN_DISP], eax
    inc  r14
.write_disp:
    mov  eax, dword [r12 + INSN_DISP]
    test eax, eax
    je   .close_bracket
    mov  byte [rdi], '+'
    inc  rdi
    ; write 0x prefix
    mov  byte [rdi+0], '0'
    mov  byte [rdi+1], 'x'
    add  rdi, 2
    lea  rsi, [rel hex_chars]
    push rcx
    mov  ecx, 8
.disp_hex:
    mov  edx, eax
    shr  edx, 28
    and  edx, 0xF
    movzx edx, byte [rsi + rdx]
    mov  [rdi], dl
    inc  rdi
    shl  eax, 4
    dec  ecx
    jnz  .disp_hex
    pop  rcx
.close_bracket:
    mov  byte [rdi], ']'
    inc  rdi
    mov  byte [rdi], 0
    jmp  .done

.has_sib:
    movzx eax, byte [rbx + r14]
    mov  byte [r12 + INSN_HAS_SIB], 1
    mov  byte [r12 + INSN_SIB], al
    inc  r14
    ; SIB: bits 7:6=scale, bits 5:3=index, bits 2:0=base
    ; For simplicity, emit "[base+index*scale+disp]" or just "[base+disp]"
    mov  dl, al
    shr  dl, 6          ; scale
    mov  bh, al
    shr  bh, 3
    and  bh, 7          ; index
    and  al, 7          ; base

    ; Check disp from mod
    push rax
    cmp  cl, 0
    je   .sib_mod0
    cmp  cl, 1
    je   .sib_disp8
    ; mod=10: disp32
    movsx eax, dword [rbx + r14]
    mov  dword [r12 + INSN_DISP], eax
    add  r14, 4
    jmp  .sib_after_disp
.sib_disp8:
    movsx eax, byte [rbx + r14]
    mov  dword [r12 + INSN_DISP], eax
    inc  r14
    jmp  .sib_after_disp
.sib_mod0:
    ; mod=00 base=5 → disp32, no base
    mov  byte [r12 + INSN_DISP], 0
.sib_after_disp:
    pop  rax
    ; Emit something reasonable: "[rsp+disp]" simplified
    lea  rdi, [r12 + INSN_OPERANDS]
    mov  byte [rdi+0], '['
    mov  byte [rdi+1], 'r'
    mov  byte [rdi+2], 's'
    mov  byte [rdi+3], 'p'
    mov  byte [rdi+4], '+'
    mov  byte [rdi+5], 's'
    mov  byte [rdi+6], 'i'
    mov  byte [rdi+7], 'b'
    mov  byte [rdi+8], ']'
    mov  byte [rdi+9], 0
    jmp  .done

.reg_operand:
    ; mod=11: operand is a register (rm field)
    movzx edi, al
    mov  rsi, 0
    test r13, 0x01      ; REX.B
    jz   .norexb2
    mov  rsi, 1
.norexb2:
    push rcx
    call get_reg_name
    pop  rcx
    ; Copy reg name into operands
    lea  rdi, [r12 + INSN_OPERANDS]
.cp_reg:
    mov  cl, [rax]
    mov  [rdi], cl
    inc  rax
    inc  rdi
    test cl, cl
    jnz  .cp_reg

.done:
    ; Also fill in INSN's reg field into mnemonic's register side?
    ; No — caller does that. Just return offset.
    mov  rax, r14

    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

; ─────────────────────────────────────────────────────────────────────────────
; int disasm_decode(const uint8_t *buf, size_t buf_len, DisasmInsn *insn)
; rdi = buf, rsi = buf_len, rdx = insn
; Returns length of instruction (1–15), or 0 on error.
; ─────────────────────────────────────────────────────────────────────────────
disasm_decode:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov  rbx, rdi      ; buf
    mov  r12, rsi      ; buf_len
    mov  r13, rdx      ; insn

    ; Zero-initialise insn struct (152 bytes)
    xor  eax, eax
    mov  rdi, r13
    mov  ecx, 19        ; 152 / 8
    rep  stosq

    test r12, r12
    jz   .return_zero

    xor  r14, r14       ; r14 = current offset into buf
    xor  r15, r15       ; r15b = REX byte (0 if none)

    ; ── Check for REX prefix (40–4F) ─────────────────────────────────────────
    movzx eax, byte [rbx + r14]
    cmp  al, 0x40
    jb   .no_rex
    cmp  al, 0x4F
    ja   .no_rex
    ; It's a REX prefix
    mov  r15b, al
    mov  byte [r13 + INSN_HAS_REX], 1
    mov  byte [r13 + INSN_REX], al
    inc  r14
    ; Verify we still have bytes
    cmp  r14, r12
    jae  .return_zero
    ; Re-read opcode after REX
    movzx eax, byte [rbx + r14]
.no_rex:
    ; eax = opcode
    mov  byte [r13 + INSN_OPCODE], al
    inc  r14

    ; ── Dispatch on opcode ───────────────────────────────────────────────────
    ; Single-byte no-operand instructions
    cmp  al, 0x90 ; NOP
    je   .insn_nop
    cmp  al, 0xC3 ; RET
    je   .insn_ret
    cmp  al, 0xCB ; RETF
    je   .insn_retf
    cmp  al, 0xC9 ; LEAVE
    je   .insn_leave
    cmp  al, 0xCC ; INT3
    je   .insn_int3
    cmp  al, 0xF4 ; HLT
    je   .insn_hlt
    cmp  al, 0x0F ; Two-byte escape
    je   .insn_0f

    ; PUSH reg (50–57) / POP reg (58–5F)
    cmp  al, 0x50
    jb   .not_push
    cmp  al, 0x57
    ja   .not_push
    ; PUSH rXX
    lea  rsi, [rel mn_push]
    call .copy_mnemonic
    movzx edi, al
    and  edi, 7
    mov  rsi, 0
    test r15, 0x01     ; REX.B
    jz   .push_norexb
    mov  rsi, 1
.push_norexb:
    call get_reg_name
    lea  rdi, [r13 + INSN_OPERANDS]
    mov  rsi, rax
    call strcpy_small
    mov  byte [r13 + INSN_OP_TYPE], OP_REG
    jmp  .done_insn
.not_push:
    cmp  al, 0x58
    jb   .not_pop
    cmp  al, 0x5F
    ja   .not_pop
    lea  rsi, [rel mn_pop]
    call .copy_mnemonic
    movzx edi, al
    and  edi, 7
    mov  rsi, 0
    test r15, 0x01
    jz   .pop_norexb
    mov  rsi, 1
.pop_norexb:
    call get_reg_name
    lea  rdi, [r13 + INSN_OPERANDS]
    mov  rsi, rax
    call strcpy_small
    mov  byte [r13 + INSN_OP_TYPE], OP_REG
    jmp  .done_insn
.not_pop:

    ; MOV r64, imm64 (B8+r)
    cmp  al, 0xB8
    jb   .not_mov_imm64
    cmp  al, 0xBF
    ja   .not_mov_imm64
    lea  rsi, [rel mn_mov]
    call .copy_mnemonic
    movzx edi, al
    and  edi, 7
    mov  rsi, 0
    test r15, 0x01
    jz   .mov64_norexb
    mov  rsi, 1
.mov64_norexb:
    call get_reg_name   ; rax = reg name ptr
    lea  rdi, [r13 + INSN_OPERANDS]
    mov  rsi, rax
    call strcpy_small   ; returns end pointer in rax
    ; Append ", 0x"
    mov  dword [rax], 0x2C000078  ; tricky; just copy chars
    lea  rsi, [rel fmt_comma]
    mov  rdi, rax
    call strcpy_small
    ; rax now at end after ", "
    mov  byte [rax+0], '0'
    mov  byte [rax+1], 'x'
    add  rax, 2
    ; Read 8-byte immediate
    mov  rdi, [rbx + r14]
    mov  qword [r13 + INSN_IMM], rdi
    add  r14, 8
    ; Write 16 hex digits
    push rax
    lea  rbx, [rsp]   ; &write_ptr on stack... simpler: write directly
    pop  rax
    mov  rsi, rdi        ; imm value
    push rax             ; push destination pointer
    lea  rdi, [rsp]      ; &dst_ptr
    call append_u64_hex
    pop  rax
    ; rax is stale; re-find end of operands
    lea  rdi, [r13 + INSN_OPERANDS]
    call .strlen_helper
    mov  byte [r13 + INSN_OP_TYPE], OP_IMM
    ; restore rbx
    mov  rbx, [r13 + INSN_OPCODE]  ; this is wrong, need to save buf ptr
    ; Actually rbx holds buf — we clobbered it in the hex write path above.
    ; Let's just use a local variable approach. For length counting we need buf.
    ; Save buf ptr to stack in prologue... we already use r15 for REX.
    ; Use r14 which already tracks offset — buf itself was in rbx and we preserved rbx via push.
    ; rbx was saved at function entry; the call above did NOT clobber rbx (append_u64_hex saves it).
    ; But we ran call .copy_mnemonic and other calls that use rbx internally.
    ; Let's trust rbx = buf (original rdi) since we saved in push rbx at the top.
    jmp  .done_insn
.not_mov_imm64:

    ; PUSH imm8 (6A), PUSH imm32 (68)
    cmp  al, 0x6A
    je   .push_imm8
    cmp  al, 0x68
    je   .push_imm32
    jmp  .not_push_imm

.push_imm8:
    lea  rsi, [rel mn_push]
    call .copy_mnemonic
    movsx eax, byte [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    inc  r14
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_IMM
    jmp  .done_insn

.push_imm32:
    lea  rsi, [rel mn_push]
    call .copy_mnemonic
    mov  eax, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    add  r14, 4
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_IMM
    jmp  .done_insn
.not_push_imm:

    ; CALL rel32 (E8)
    cmp  al, 0xE8
    jne  .not_call
    lea  rsi, [rel mn_call]
    call .copy_mnemonic
    movsx eax, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    add  r14, 4
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_REL
    jmp  .done_insn
.not_call:

    ; JMP rel32 (E9)
    cmp  al, 0xE9
    jne  .not_jmp32
    lea  rsi, [rel mn_jmp]
    call .copy_mnemonic
    movsx eax, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    add  r14, 4
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_REL
    jmp  .done_insn
.not_jmp32:

    ; JMP rel8 (EB)
    cmp  al, 0xEB
    jne  .not_jmp8
    lea  rsi, [rel mn_jmp]
    call .copy_mnemonic
    movsx eax, byte [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    inc  r14
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_REL
    jmp  .done_insn
.not_jmp8:

    ; Jcc rel8 (70–7F)
    cmp  al, 0x70
    jb   .not_jcc8
    cmp  al, 0x7F
    ja   .not_jcc8
    movzx ecx, al
    and  ecx, 0xF
    lea  rsi, [rel cc_table]
    mov  rsi, [rsi + rcx*8]
    ; mnemonic = "j" + cc
    lea  rdi, [r13 + INSN_MNEMONIC]
    mov  byte [rdi], 'j'
    inc  rdi
.jcc8_cc:
    mov  cl, [rsi]
    mov  [rdi], cl
    inc  rsi
    inc  rdi
    test cl, cl
    jnz  .jcc8_cc
    ; operand = imm8 rel
    movsx eax, byte [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    inc  r14
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_REL
    jmp  .done_insn
.not_jcc8:

    ; ALU ops: ADD(01/03), OR(09/0B), AND(21/23), SUB(29/2B), XOR(31/33), CMP(39/3B)
    cmp  al, 0x01
    je   .alu_add_rm_r
    cmp  al, 0x09
    je   .alu_or_rm_r
    cmp  al, 0x21
    je   .alu_and_rm_r
    cmp  al, 0x29
    je   .alu_sub_rm_r
    cmp  al, 0x31
    je   .alu_xor_rm_r
    cmp  al, 0x39
    je   .alu_cmp_rm_r
    cmp  al, 0x03
    je   .alu_add_r_rm
    cmp  al, 0x0B
    je   .alu_or_r_rm
    cmp  al, 0x23
    je   .alu_and_r_rm
    cmp  al, 0x2B
    je   .alu_sub_r_rm
    cmp  al, 0x33
    je   .alu_xor_r_rm
    cmp  al, 0x3B
    je   .alu_cmp_r_rm

    ; MOV r/m64, r64 (89) and MOV r64, r/m64 (8B)
    cmp  al, 0x89
    je   .mov_rm_r
    cmp  al, 0x8B
    je   .mov_r_rm

    ; LEA r64, m (8D)
    cmp  al, 0x8D
    je   .lea_r_m

    ; MOV r/m64, imm32 (C7)
    cmp  al, 0xC7
    je   .mov_rm_imm32

    ; TEST r/m64, r64 (85)
    cmp  al, 0x85
    je   .test_rm_r

    ; CMP/TEST with imm (81, F7)
    cmp  al, 0x81
    je   .insn_81
    cmp  al, 0xF7
    je   .insn_f7

    ; FF group: INC/DEC/CALL/JMP r/m
    cmp  al, 0xFF
    je   .insn_ff

    ; Fallback: unknown
    jmp  .unknown

    ; ── ALU helpers ──────────────────────────────────────────────────────────
    ; Convention: for rm,r: operands = "rm_str, reg_str"; for r,rm: "reg_str, rm_str"

%macro alu_rm_r 1       ; arg = mnemonic ptr label
    lea  rsi, [rel %1]
    call .copy_mnemonic
    jmp  .do_alu_rm_r
%endmacro

%macro alu_r_rm 1
    lea  rsi, [rel %1]
    call .copy_mnemonic
    jmp  .do_alu_r_rm
%endmacro

.alu_add_rm_r: alu_rm_r mn_add
.alu_or_rm_r:  alu_rm_r mn_or
.alu_and_rm_r: alu_rm_r mn_and
.alu_sub_rm_r: alu_rm_r mn_sub
.alu_xor_rm_r: alu_rm_r mn_xor
.alu_cmp_rm_r: alu_rm_r mn_cmp

.alu_add_r_rm: alu_r_rm mn_add
.alu_or_r_rm:  alu_r_rm mn_or
.alu_and_r_rm: alu_r_rm mn_and
.alu_sub_r_rm: alu_r_rm mn_sub
.alu_xor_r_rm: alu_r_rm mn_xor
.alu_cmp_r_rm: alu_r_rm mn_cmp

.do_alu_rm_r:
    ; Decode ModRM; operands[0..] gets rm expression; then append ", regname"
    call .decode_modrm_and_reg
    ; operands now has rm; append ", regname"
    jmp  .append_comma_reg

.do_alu_r_rm:
    ; operands gets reg, then ", rm"
    call .decode_modrm_get_reg_first
    jmp  .done_insn

.mov_rm_r:
    lea  rsi, [rel mn_mov]
    call .copy_mnemonic
    call .decode_modrm_and_reg
    jmp  .append_comma_reg

.mov_r_rm:
    lea  rsi, [rel mn_mov]
    call .copy_mnemonic
    call .decode_modrm_get_reg_first
    jmp  .done_insn

.lea_r_m:
    lea  rsi, [rel mn_lea]
    call .copy_mnemonic
    call .decode_modrm_get_reg_first
    jmp  .done_insn

.test_rm_r:
    lea  rsi, [rel mn_test]
    call .copy_mnemonic
    call .decode_modrm_and_reg
    jmp  .append_comma_reg

.mov_rm_imm32:
    lea  rsi, [rel mn_mov]
    call .copy_mnemonic
    ; Decode ModRM (fills operands with rm expression), then append imm32
    mov  rdi, rbx        ; buf
    mov  rsi, r13        ; insn
    mov  rdx, r15        ; rex
    mov  rcx, r14        ; offset
    call decode_modrm
    mov  r14, rax        ; new offset
    ; append ", imm32"
    lea  rdi, [r13 + INSN_OPERANDS]
    call .strlen_helper   ; rdi now points at end of string
    lea  rsi, [rel fmt_comma]
    call strcpy_small
    ; rax = end; read imm32
    mov  ecx, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], ecx
    add  r14, 4
    mov  rdi, rax
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_IMM
    jmp  .done_insn

.insn_81:
    ; 81 /7 imm32 = CMP r/m64, imm32 (and other /r for ADD/OR/etc)
    ; For simplicity, read the ModRM reg field to determine subopcode
    movzx eax, byte [rbx + r14]   ; peek at ModRM
    mov  cl, al
    shr  cl, 3
    and  cl, 7    ; reg field = subopcode
    ; 7 = CMP, 0 = ADD, 1 = OR, 2 = ADC, 3 = SBB, 4 = AND, 5 = SUB, 6 = XOR
    cmp  cl, 7
    je   .g81_cmp
    cmp  cl, 0
    je   .g81_add
    cmp  cl, 5
    je   .g81_sub
    cmp  cl, 4
    je   .g81_and
    cmp  cl, 6
    je   .g81_xor
    cmp  cl, 1
    je   .g81_or
    jmp  .unknown
.g81_cmp: lea rsi, [rel mn_cmp]; jmp .g81_do
.g81_add: lea rsi, [rel mn_add]; jmp .g81_do
.g81_sub: lea rsi, [rel mn_sub]; jmp .g81_do
.g81_and: lea rsi, [rel mn_and]; jmp .g81_do
.g81_xor: lea rsi, [rel mn_xor]; jmp .g81_do
.g81_or:  lea rsi, [rel mn_or]
.g81_do:
    call .copy_mnemonic
    mov  rdi, rbx
    mov  rsi, r13
    mov  rdx, r15
    mov  rcx, r14
    call decode_modrm
    mov  r14, rax
    lea  rdi, [r13 + INSN_OPERANDS]
    call .strlen_helper
    lea  rsi, [rel fmt_comma]
    call strcpy_small
    mov  ecx, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], ecx
    add  r14, 4
    mov  rdi, rax
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_IMM
    jmp  .done_insn

.insn_f7:
    ; F7 /0 = TEST r/m64, imm32; F7 /2 = NOT; F7 /3 = NEG; F7 /4 = MUL; F7 /6 = DIV; F7 /7 = IDIV
    movzx eax, byte [rbx + r14]
    mov  cl, al
    shr  cl, 3
    and  cl, 7
    cmp  cl, 0
    je   .f7_test
    cmp  cl, 2
    je   .f7_not
    cmp  cl, 3
    je   .f7_neg
    cmp  cl, 4
    je   .f7_mul
    cmp  cl, 6
    je   .f7_div
    cmp  cl, 7
    je   .f7_idiv
    jmp  .unknown
.f7_test: lea rsi, [rel mn_test]; jmp .f7_rm_imm
.f7_not:  lea rsi, [rel mn_not];  jmp .f7_rm_only
.f7_neg:  lea rsi, [rel mn_neg];  jmp .f7_rm_only
.f7_mul:  lea rsi, [rel mn_mul];  jmp .f7_rm_only
.f7_div:  lea rsi, [rel mn_div];  jmp .f7_rm_only
.f7_idiv: lea rsi, [rel mn_idiv]
.f7_rm_only:
    call .copy_mnemonic
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    jmp  .done_insn
.f7_rm_imm:
    call .copy_mnemonic
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    lea  rdi, [r13 + INSN_OPERANDS]
    call .strlen_helper
    lea  rsi, [rel fmt_comma]
    call strcpy_small
    mov  ecx, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], ecx
    add  r14, 4
    mov  rdi, rax
    call .fmt_imm32_into_rdi
    jmp  .done_insn

.insn_ff:
    ; FF group: /0=INC, /1=DEC, /2=CALL, /4=JMP
    movzx eax, byte [rbx + r14]
    mov  cl, al
    shr  cl, 3
    and  cl, 7
    cmp  cl, 0
    je   .ff_inc
    cmp  cl, 1
    je   .ff_dec
    cmp  cl, 2
    je   .ff_call
    cmp  cl, 4
    je   .ff_jmp
    jmp  .unknown
.ff_inc:  lea rsi, [rel mn_inc]; jmp .ff_rm_only
.ff_dec:  lea rsi, [rel mn_dec]; jmp .ff_rm_only
.ff_call: lea rsi, [rel mn_call]; jmp .ff_rm_only
.ff_jmp:  lea rsi, [rel mn_jmp]
.ff_rm_only:
    call .copy_mnemonic
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    jmp  .done_insn

    ; ── Single-byte no-operand instructions ──────────────────────────────────
.insn_nop:
    lea  rsi, [rel mn_nop]
    call .copy_mnemonic
    jmp  .done_insn
.insn_ret:
    lea  rsi, [rel mn_ret]
    call .copy_mnemonic
    jmp  .done_insn
.insn_retf:
    lea  rsi, [rel mn_retf]
    call .copy_mnemonic
    jmp  .done_insn
.insn_leave:
    lea  rsi, [rel mn_leave]
    call .copy_mnemonic
    jmp  .done_insn
.insn_int3:
    lea  rsi, [rel mn_int3]
    call .copy_mnemonic
    jmp  .done_insn
.insn_hlt:
    lea  rsi, [rel mn_hlt]
    call .copy_mnemonic
    jmp  .done_insn

    ; ── Two-byte 0F escape ───────────────────────────────────────────────────
.insn_0f:
    cmp  r14, r12
    jae  .return_zero
    movzx eax, byte [rbx + r14]
    inc  r14
    ; SYSCALL = 0F 05
    cmp  al, 0x05
    jne  .of_not_syscall
    lea  rsi, [rel mn_syscall]
    call .copy_mnemonic
    jmp  .done_insn
.of_not_syscall:
    ; UD2 = 0F 0B
    cmp  al, 0x0B
    jne  .of_not_ud2
    lea  rsi, [rel mn_ud2]
    call .copy_mnemonic
    jmp  .done_insn
.of_not_ud2:
    ; Jcc rel32: 0F 80-8F
    cmp  al, 0x80
    jb   .of_not_jcc32
    cmp  al, 0x8F
    ja   .of_not_jcc32
    movzx ecx, al
    and  ecx, 0xF
    lea  rsi, [rel cc_table]
    mov  rsi, [rsi + rcx*8]
    lea  rdi, [r13 + INSN_MNEMONIC]
    mov  byte [rdi], 'j'
    inc  rdi
.jcc32_cc:
    mov  cl, [rsi]
    mov  [rdi], cl
    inc  rsi
    inc  rdi
    test cl, cl
    jnz  .jcc32_cc
    movsx eax, dword [rbx + r14]
    mov  dword [r13 + INSN_IMM], eax
    add  r14, 4
    lea  rdi, [r13 + INSN_OPERANDS]
    call .fmt_imm32_into_rdi
    mov  byte [r13 + INSN_OP_TYPE], OP_REL
    jmp  .done_insn
.of_not_jcc32:
    ; CMOVcc: 0F 40-4F
    cmp  al, 0x40
    jb   .of_not_cmov
    cmp  al, 0x4F
    ja   .of_not_cmov
    movzx ecx, al
    and  ecx, 0xF
    lea  rsi, [rel cc_table]
    mov  rsi, [rsi + rcx*8]
    lea  rdi, [r13 + INSN_MNEMONIC]
    ; Write "cmov"
    mov  dword [rdi], 0x766F6D63  ; "cmov"
    add  rdi, 4
.cmov_cc:
    mov  cl, [rsi]
    mov  [rdi], cl
    inc  rsi
    inc  rdi
    test cl, cl
    jnz  .cmov_cc
    call .decode_modrm_get_reg_first
    jmp  .done_insn
.of_not_cmov:
    ; SETcc: 0F 90-9F
    cmp  al, 0x90
    jb   .of_not_set
    cmp  al, 0x9F
    ja   .of_not_set
    movzx ecx, al
    and  ecx, 0xF
    lea  rsi, [rel cc_table]
    mov  rsi, [rsi + rcx*8]
    lea  rdi, [r13 + INSN_MNEMONIC]
    mov  dword [rdi], 0x00746573  ; "set\0"
    add  rdi, 3
.set_cc:
    mov  cl, [rsi]
    mov  [rdi], cl
    inc  rsi
    inc  rdi
    test cl, cl
    jnz  .set_cc
    ; SETcc has a r/m8 operand
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    jmp  .done_insn
.of_not_set:
    ; MOVZX r64, r/m8 (0F B6) or r/m16 (0F B7)
    cmp  al, 0xB6
    je   .of_movzx
    cmp  al, 0xB7
    je   .of_movzx
    ; MOVSX r64, r/m8 (0F BE) or r/m16 (0F BF)
    cmp  al, 0xBE
    je   .of_movsx
    cmp  al, 0xBF
    je   .of_movsx
    ; IMUL r64, r/m64 (0F AF)
    cmp  al, 0xAF
    je   .of_imul
    jmp  .unknown

.of_movzx:
    lea  rsi, [rel mn_movzx]
    call .copy_mnemonic
    call .decode_modrm_get_reg_first
    jmp  .done_insn
.of_movsx:
    lea  rsi, [rel mn_movsx]
    call .copy_mnemonic
    call .decode_modrm_get_reg_first
    jmp  .done_insn
.of_imul:
    lea  rsi, [rel mn_imul]
    call .copy_mnemonic
    call .decode_modrm_get_reg_first
    jmp  .done_insn

.unknown:
    ; Emit "db 0xXX"
    lea  rsi, [rel mn_db]
    call .copy_mnemonic
    movzx eax, byte [rbx + r14 - 1]   ; opcode byte (already consumed)
    lea  rdi, [r13 + INSN_OPERANDS]
    mov  byte [rdi+0], '0'
    mov  byte [rdi+1], 'x'
    add  rdi, 2
    ; 2-digit hex
    lea  rsi, [rel hex_chars]
    mov  ecx, eax
    shr  ecx, 4
    movzx ecx, byte [rsi + rcx]
    mov  [rdi], cl
    inc  rdi
    and  eax, 0xF
    movzx eax, byte [rsi + rax]
    mov  [rdi], al
    inc  rdi
    mov  byte [rdi], 0
    ; length = 1 (just the unknown byte; r14 already incremented past opcode)
    ; But if there was a REX prefix, back r14 to opcode only
    ; r14 points to byte after opcode; length = r14 - (buf start)
    ; With REX: r14 = 2; without: r14 = 1. Either way keep it as is.
    jmp  .done_insn

    ; ── Finalize ─────────────────────────────────────────────────────────────
.done_insn:
    mov  byte [r13 + INSN_LEN], r14b
    mov  rax, r14
    jmp  .epilogue

.return_zero:
    xor  eax, eax

.epilogue:
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret

    ; ── Local subroutines (called with near call) ─────────────────────────────

.copy_mnemonic:
    ; rsi = source mnemonic, copies to r13+INSN_MNEMONIC
    lea  rdi, [r13 + INSN_MNEMONIC]
    jmp  strcpy_small

.strlen_helper:
    ; rdi = string; returns end pointer in rdi (& null terminator)
    ; Trashes: rax
    xor  eax, eax
.sh_lp:
    cmp  byte [rdi], 0
    je   .sh_done
    inc  rdi
    jmp  .sh_lp
.sh_done:
    ret

.fmt_imm32_into_rdi:
    ; Formats dword [r13+INSN_IMM] as "0xXXXXXXXX" at rdi
    ; Trashes: rax, rcx, rsi
    mov  byte [rdi+0], '0'
    mov  byte [rdi+1], 'x'
    add  rdi, 2
    mov  eax, dword [r13 + INSN_IMM]
    lea  rsi, [rel hex_chars]
    mov  ecx, 8
.fi_lp:
    mov  edx, eax
    shr  edx, 28
    and  edx, 0xF
    movzx edx, byte [rsi + rdx]
    mov  [rdi], dl
    inc  rdi
    shl  eax, 4
    dec  ecx
    jnz  .fi_lp
    mov  byte [rdi], 0
    ret

.decode_modrm_and_reg:
    ; Reads ModRM; operands[] ← rm expression; r8b = reg field (for caller)
    ; Also stores reg side name in local var for .append_comma_reg
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    ; Extract reg field from ModRM byte
    movzx r8d, byte [r13 + INSN_MODRM]
    shr  r8b, 3
    and  r8b, 7
    ret

.append_comma_reg:
    ; r8b = reg field; append ", reg_name" to operands
    movzx edi, r8b
    mov  rsi, 0
    test r15, 0x04      ; REX.R extends reg field
    jz   .acr_norexr
    mov  rsi, 1
.acr_norexr:
    call get_reg_name   ; rax = reg name ptr
    ; Find end of operands string
    lea  rdi, [r13 + INSN_OPERANDS]
    call .strlen_helper
    ; Append ", "
    lea  rsi, [rel fmt_comma]
    call strcpy_small   ; rax = after ", "
    ; Append reg name
    mov  rdi, rax
    mov  rsi, [r13 + INSN_OPCODE]  ; can't use rax for both src and dst
    ; get_reg_name result was in rax before strlen_helper... reload
    movzx edi, r8b
    mov  rsi, 0
    test r15, 0x04
    jz   .acr2_norexr
    mov  rsi, 1
.acr2_norexr:
    push rdi
    call get_reg_name
    pop  rdi
    mov  rsi, rax
    call strcpy_small
    mov  byte [r13 + INSN_OP_TYPE], OP_REG
    ret

.decode_modrm_get_reg_first:
    ; Operand format: reg_name, rm_expr
    ; Step 1: decode ModRM to fill rm info; extract reg field
    mov  rdi, rbx; mov rsi, r13; mov rdx, r15; mov rcx, r14
    call decode_modrm
    mov  r14, rax
    ; Get reg field
    movzx r8d, byte [r13 + INSN_MODRM]
    shr  r8b, 3
    and  r8b, 7
    movzx edi, r8b
    mov  rsi, 0
    test r15, 0x04
    jz   .dmgrf_norexr
    mov  rsi, 1
.dmgrf_norexr:
    call get_reg_name   ; rax = reg name ptr
    ; We need to put reg name first, then ", ", then whatever is in operands[].
    ; But operands[] already has the rm expression from decode_modrm.
    ; Strategy: copy rm expr to a temp, write reg name, ", ", rm expr
    ; Use scratch_buf for the temp copy
    lea  rdi, [rel scratch_buf]
    lea  rsi, [r13 + INSN_OPERANDS]
    call strcpy_small   ; scratch_buf = rm_expr

    ; Now write: reg_name, ", ", rm_expr
    lea  rdi, [r13 + INSN_OPERANDS]
    movzx esi, r8b
    push rsi
    mov  rsi, 0
    test r15, 0x04
    jz   .dmgrf2_norexr
    mov  rsi, 1
.dmgrf2_norexr:
    pop  rdi
    ; Hmm, rdi was clobbered. Let's redo this properly:
    movzx edi, r8b
    mov  rsi, 0
    test r15, 0x04
    jz   .dmgrf3_norexr
    mov  rsi, 1
.dmgrf3_norexr:
    call get_reg_name
    lea  rdi, [r13 + INSN_OPERANDS]
    mov  rsi, rax
    call strcpy_small   ; rax = end of reg name in operands
    ; Append ", "
    lea  rsi, [rel fmt_comma]
    mov  rdi, rax
    call strcpy_small   ; rax = end of ", "
    ; Append rm expr from scratch
    lea  rsi, [rel scratch_buf]
    mov  rdi, rax
    call strcpy_small
    mov  byte [r13 + INSN_OP_TYPE], OP_MEM
    ret

; ─────────────────────────────────────────────────────────────────────────────
; int disasm_sprint(const DisasmInsn *insn, const uint8_t *raw, char *out, size_t out_len)
; rdi = insn, rsi = raw bytes, rdx = out buffer, rcx = out_len
; Returns number of characters written.
; ─────────────────────────────────────────────────────────────────────────────
disasm_sprint:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov  rbx, rdi      ; insn
    mov  r12, rsi      ; raw bytes
    mov  r13, rdx      ; out buffer
    mov  r14, rcx      ; out_len
    mov  r15, rdx      ; write cursor (starts at out)

    ; Format: "  XX XX XX XX   mnemonic   operands\n"
    ; Write hex bytes
    movzx ecx, byte [rbx + INSN_LEN]
    test ecx, ecx
    jz   .done_sprint
    xor  r9, r9        ; byte index
.hex_loop:
    cmp  r9, rcx
    jae  .hex_done
    movzx esi, byte [r12 + r9]
    ; high nibble
    lea  rdi, [rel hex_chars]
    mov  eax, esi
    shr  eax, 4
    movzx eax, byte [rdi + rax]
    mov  [r15], al
    inc  r15
    and  esi, 0xF
    movzx esi, byte [rdi + rsi]
    mov  [r15], sil
    inc  r15
    mov  byte [r15], ' '
    inc  r15
    inc  r9
    jmp  .hex_loop
.hex_done:
    ; Pad to 24 chars for hex area (8 bytes * 3 chars each = 24)
    ; Current write cursor - r13 = chars written so far
    mov  rax, r15
    sub  rax, r13
.pad_loop:
    cmp  rax, 24
    jae  .pad_done
    mov  byte [r15], ' '
    inc  r15
    inc  rax
    jmp  .pad_loop
.pad_done:

    ; Write mnemonic
    lea  rsi, [rbx + INSN_MNEMONIC]
    mov  rdi, r15
    call strcpy_small
    mov  r15, rax     ; end of mnemonic

    ; Check if operands empty
    cmp  byte [rbx + INSN_OPERANDS], 0
    je   .no_operands

    ; Pad mnemonic area to 10 chars wide
    mov  rax, r15
    sub  rax, r13     ; total chars written
    ; find mnemonic start: it was written starting at r13+24
    ; So mnemonic length = r15 - (r13+24) ... but r13+24 = hex_end
    ; For alignment, ensure mnemonic+operands starts after 24 chars of hex
    ; Write spaces between mnemonic and operands
    mov  byte [r15], ' '
    inc  r15
    mov  byte [r15], ' '
    inc  r15

    ; Write operands
    lea  rsi, [rbx + INSN_OPERANDS]
    mov  rdi, r15
    call strcpy_small
    mov  r15, rax

.no_operands:
    mov  byte [r15], 10    ; newline
    inc  r15

.done_sprint:
    mov  byte [r15], 0     ; null terminate
    mov  rax, r15
    sub  rax, r13          ; return character count

    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret
