; =============================================================================
; strings.asm  —  Module 11: String & Array Operations
; =============================================================================
bits 64

extern print_label
extern print_u64
extern print_cstr

section .rodata
    lbl_strlen  db "asm_strlen: count bytes until null", 0
    lbl_strcpy  db "asm_strcpy: copy bytes including null", 0
    lbl_memset  db "asm_memset: fill block with byte value", 0
    lbl_memcmp  db "asm_memcmp: compare two byte blocks", 0
    lbl_repmovsb db "rep movsb: bulk copy 256 bytes", 0
    lbl_repscasb db "rep scasb: scan for byte in buffer", 0
    lbl_repcmpsb db "rep cmpsb: compare two strings", 0

    src_str     db "Hello, Assembly Language!", 0
    cmp_str1    db "AAABBBCCC", 0
    cmp_str2    db "AAABBBDDD", 0
    cmp_str3    db "AAABBBCCC", 0

section .data
    ; 256-byte source buffer, filled at runtime
    src_buf     times 256 db 0xAA

section .bss
    dst_buf     resb 512       ; destination buffer for copy demos
    str_copy    resb 64        ; space to copy src_str

section .text
    global main
    global asm_strlen
    global asm_strcpy
    global asm_memset
    global asm_memcmp

; ─────────────────────────────────────────────────────────────────────────────
; asm_strlen(const char *s) → rax = length (not counting null)
; ─────────────────────────────────────────────────────────────────────────────
asm_strlen:
    ; rdi = s (Linux) / rcx = s (Windows)
%ifdef WIN64
    mov  rdi, rcx
%endif
    xor  rax, rax           ; rax = 0 (counter)
.loop:
    cmp  byte [rdi + rax], 0
    je   .done
    inc  rax
    jmp  .loop
.done:
    ret

; ─────────────────────────────────────────────────────────────────────────────
; asm_strlen_rep(const char *s) → rax = length (using repne scasb)
; ─────────────────────────────────────────────────────────────────────────────
asm_strlen_rep:
%ifdef WIN64
    mov  rdi, rcx
%endif
    ; repne scasb: while (rdi[0] != al) { rdi++; rcx-- }
    ; We need rdi = s, al = 0, rcx = max length
    mov  rcx, -1             ; effectively unlimited
    xor  al, al              ; search for 0x00
    repne scasb              ; scan forward until [rdi] == al
    ; After: rdi points one past the null, rcx is decremented
    ; Length = original_rcx - remaining_rcx - 1
    ; Simpler: rdi - original_rdi - 1
    ; But we need original rdi. Use the relationship:
    ; rcx started at -1 (0xFFFFFFFFFFFFFFFF), ended at (0xFFFFFFFFFFFFFFFF - len - 1)
    ; So len = (~rcx) - 1 = -rcx - 2
    not  rcx
    dec  rcx
    mov  rax, rcx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; asm_strcpy(char *dst, const char *src)
; Copies src to dst including the null terminator
; ─────────────────────────────────────────────────────────────────────────────
asm_strcpy:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    ; rdi = dst, rsi = src
.loop:
    mov  al, [rsi]
    mov  [rdi], al
    inc  rsi
    inc  rdi
    test al, al
    jnz  .loop
    ret

; ─────────────────────────────────────────────────────────────────────────────
; asm_strcpy_rep(char *dst, const char *src) — using rep movsb variant
; We must know the length first; here we use a combined approach
; ─────────────────────────────────────────────────────────────────────────────
asm_strcpy_rep:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
%endif
    push rdi                 ; save dst start
    push rsi                 ; save src start
    ; First measure length
    mov  rcx, -1
    xor  al, al
    repne scasb
    not  rcx                 ; rcx = strlen + 1 (includes null)
    ; Restore and copy
    pop  rsi                 ; src
    pop  rdi                 ; dst
    rep  movsb               ; copy rcx bytes from [rsi] to [rdi]
    ret

; ─────────────────────────────────────────────────────────────────────────────
; asm_memset(void *dst, int val, size_t n)
; Fills n bytes at dst with val (low byte only)
; ─────────────────────────────────────────────────────────────────────────────
asm_memset:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    ; rdi = dst, rsi = val, rdx = n
    mov  al, sil             ; al = low byte of val
    mov  rcx, rdx            ; rcx = count
    rep  stosb               ; store al into [rdi], decrement rcx, repeat
    ret

; ─────────────────────────────────────────────────────────────────────────────
; asm_memcmp(const void *a, const void *b, size_t n) → rax
; Returns 0 if equal, negative if a < b, positive if a > b
; ─────────────────────────────────────────────────────────────────────────────
asm_memcmp:
%ifdef WIN64
    mov  rdi, rcx
    mov  rsi, rdx
    mov  rdx, r8
%endif
    ; rdi = a, rsi = b, rdx = n
    mov  rcx, rdx
    xor  rax, rax
    test rcx, rcx
    jz   .done
    repe cmpsb               ; compare [rdi++] vs [rsi++] while equal, rcx--
    je   .done               ; all bytes equal
    movzx eax, byte [rdi-1]  ; last compared byte from a
    movzx ecx, byte [rsi-1]  ; last compared byte from b
    sub  rax, rcx            ; return a_byte - b_byte
.done:
    ret

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
%macro SHOWs 1
    lea  rdi, [rel %1]
    mov  rcx, rdi
    call print_cstr
%endmacro

main:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8              ; keep 16-byte alignment

    ; ── strlen demo ──────────────────────────────────────────────────────────
    LABEL lbl_strlen
    lea  rdi, [rel src_str]
    mov  rcx, rdi
    call asm_strlen
    SHOWu rax                ; should be 25

    ; strlen with repne scasb
    lea  rdi, [rel src_str]
    mov  rcx, rdi
    call asm_strlen_rep
    SHOWu rax                ; also 25

    ; ── strcpy demo ──────────────────────────────────────────────────────────
    LABEL lbl_strcpy
    lea  rdi, [rel str_copy]
    lea  rsi, [rel src_str]
    mov  rcx, rdi
    mov  rdx, rsi
    call asm_strcpy
    ; verify by printing the copy
    lea  rdi, [rel str_copy]
    mov  rcx, rdi
    call print_cstr
    ; measure the copy's length
    lea  rdi, [rel str_copy]
    mov  rcx, rdi
    call asm_strlen
    SHOWu rax                ; 25

    ; ── memset demo ──────────────────────────────────────────────────────────
    LABEL lbl_memset
    lea  rdi, [rel dst_buf]
    mov  rsi, 0xBE           ; fill byte
    mov  rdx, 16             ; fill 16 bytes
    mov  rcx, rdi
    mov  r8, rdx
    call asm_memset
    ; verify: load first 8 bytes as qword — should be 0xBEBEBEBEBEBEBEBE
    mov  rax, [rel dst_buf]
    SHOWu rax

    ; ── memcmp demos ─────────────────────────────────────────────────────────
    LABEL lbl_memcmp
    ; Compare equal strings
    lea  rdi, [rel cmp_str1]
    lea  rsi, [rel cmp_str3]   ; same content as cmp_str1
    mov  rdx, 9
    mov  rcx, rdi
    mov  r8,  rdx
    call asm_memcmp
    SHOWu rax                ; 0 (equal)

    ; Compare strings that differ at position 6 ('C' vs 'D' = 0x43 vs 0x44)
    lea  rdi, [rel cmp_str1]
    lea  rsi, [rel cmp_str2]
    mov  rdx, 9
    mov  rcx, rdi
    mov  r8,  rdx
    call asm_memcmp
    SHOWu rax                ; negative (C < D)

    ; ── rep movsb bulk copy ──────────────────────────────────────────────────
    LABEL lbl_repmovsb
    lea  rdi, [rel dst_buf]
    lea  rsi, [rel src_buf]
    mov  rcx, 256            ; copy 256 bytes
    rep  movsb
    ; verify: first byte should be 0xAA
    movzx rax, byte [rel dst_buf]
    SHOWu rax                ; 0xAA

    ; ── repne scasb scan for byte ─────────────────────────────────────────────
    LABEL lbl_repscasb
    ; Find the comma ',' (0x2C) in src_str = "Hello, Assembly Language!"
    lea  rdi, [rel src_str]
    mov  rcx, 32             ; max scan length
    mov  al, 0x2C            ; ',' character
    repne scasb
    ; rdi now points one past the comma
    ; index = (rdi - src_str) - 1
    lea  rbx, [rel src_str]
    sub  rdi, rbx
    dec  rdi                 ; rdi = index of ','
    mov  rax, rdi
    SHOWu rax                ; 5 (zero-based index of ',')

    ; ── repe cmpsb string compare ─────────────────────────────────────────────
    LABEL lbl_repcmpsb
    ; Compare cmp_str1 ("AAABBBCCC") vs cmp_str2 ("AAABBBDDD")
    ; They differ at index 6 ('C' vs 'D')
    lea  rdi, [rel cmp_str1]
    lea  rsi, [rel cmp_str2]
    mov  rcx, 9
    repe cmpsb               ; compare while equal
    ; After: rdi/rsi point one past first mismatch
    ; rcx = remaining count (not counting the mismatch byte)
    mov  rax, 9
    sub  rax, rcx
    dec  rax                 ; rax = index of first mismatch
    SHOWu rax                ; 6

    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    xor  eax, eax
    ret
