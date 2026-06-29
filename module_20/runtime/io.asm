; =============================================================================
; io.asm  —  Module 20: Bare-Metal Runtime
;
; I/O primitives built on syscall_wrappers.asm.
; No printf, no puts, no libc — everything goes through sys_write.
;
; Also contains our_main — the application entry point called from _start.
; =============================================================================
bits 64

extern sys_write
extern sys_read
extern bump_alloc
extern heap_used

global our_main
global io_write_str
global io_write_u64
global io_write_hex
global io_write_char
global io_newline
global io_strlen

STDOUT equ 1
STDIN  equ 0

section .rodata
    hex_chars  db "0123456789ABCDEF"
    msg_start  db "=== Bare-Metal Runtime ===", 10
    msg_start_len equ $ - msg_start
    msg_argc   db "argc: ", 0
    msg_argv   db "argv[0]: ", 0
    msg_heap   db "heap used: ", 0
    msg_bytes  db " bytes", 10, 0
    msg_alloc  db "bump_alloc(128) returned: 0x", 0
    msg_done   db "Runtime demo complete.", 10
    msg_done_len equ $ - msg_done
    crlf       db 10

section .bss
    num_buf    resb 24      ; scratch for number-to-string conversion

section .text

; ─────────────────────────────────────────────────────────────────────────────
; size_t io_strlen(const char *s) → rax
; ─────────────────────────────────────────────────────────────────────────────
io_strlen:
    xor  rax, rax
.loop:
    cmp  byte [rdi + rax], 0
    je   .done
    inc  rax
    jmp  .loop
.done:
    ret

; ─────────────────────────────────────────────────────────────────────────────
; void io_write_str(const char *s) — writes null-terminated string to stdout
; ─────────────────────────────────────────────────────────────────────────────
io_write_str:
    push rbx
    mov  rbx, rdi           ; save pointer
    call io_strlen          ; rax = len
    mov  rdx, rax           ; count
    mov  rsi, rbx           ; buf
    mov  rdi, STDOUT
    call sys_write
    pop  rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; void io_write_char(char c) — writes one character to stdout
; ─────────────────────────────────────────────────────────────────────────────
io_write_char:
    push rbx
    mov  byte [rsp-1], dil  ; store char just below rsp (red zone)
    lea  rsi, [rsp-1]
    mov  rdi, STDOUT
    mov  rdx, 1
    call sys_write
    pop  rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; void io_newline(void)
; ─────────────────────────────────────────────────────────────────────────────
io_newline:
    push rbx
    lea  rsi, [rel crlf]
    mov  rdi, STDOUT
    mov  rdx, 1
    call sys_write
    pop  rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; void io_write_u64(uint64_t n) — decimal output
; ─────────────────────────────────────────────────────────────────────────────
io_write_u64:
    push rbx
    push r12
    push r13

    mov  r12, rdi           ; save n
    lea  r13, [rel num_buf + 23]
    mov  byte [r13], 0      ; null terminator

    ; Special case: zero
    test r12, r12
    jnz  .convert
    dec  r13
    mov  byte [r13], '0'
    jmp  .print

.convert:
    mov  rbx, 10
.loop:
    xor  rdx, rdx
    mov  rax, r12
    div  rbx                ; rax = quotient, rdx = remainder
    mov  r12, rax
    add  dl, '0'
    dec  r13
    mov  [r13], dl
    test rax, rax
    jnz  .loop

.print:
    mov  rdi, r13
    call io_write_str

    pop  r13
    pop  r12
    pop  rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; void io_write_hex(uint64_t n) — hex output with 0x prefix
; ─────────────────────────────────────────────────────────────────────────────
io_write_hex:
    push rbx
    push r12

    mov  r12, rdi

    ; Write "0x"
    mov  dil, '0'
    call io_write_char
    mov  dil, 'x'
    call io_write_char

    ; 16 hex digits, most significant first
    mov  rcx, 16
    lea  rbx, [rel hex_chars]
.hex_loop:
    mov  rax, r12
    shr  rax, 60            ; shift top nibble to bottom
    and  rax, 0xF
    movzx eax, byte [rbx + rax]
    mov  dil, al
    push rcx
    call io_write_char
    pop  rcx
    shl  r12, 4             ; shift left to process next nibble
    dec  rcx
    jnz  .hex_loop

    pop  r12
    pop  rbx
    ret

; ─────────────────────────────────────────────────────────────────────────────
; our_main(argc, argv, envp) → exit code in rax
; This is the application-level entry point, called from _start.
; ─────────────────────────────────────────────────────────────────────────────
our_main:
    push rbp
    mov  rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8

    mov  r12, rdi           ; argc
    mov  r13, rsi           ; argv
    mov  r14, rdx           ; envp

    ; ── Banner ───────────────────────────────────────────────────────────────
    mov  rdi, STDOUT
    lea  rsi, [rel msg_start]
    mov  rdx, msg_start_len
    call sys_write

    ; ── Print argc ───────────────────────────────────────────────────────────
    lea  rdi, [rel msg_argc]
    call io_write_str
    mov  rdi, r12
    call io_write_u64
    call io_newline

    ; ── Print argv[0] ────────────────────────────────────────────────────────
    lea  rdi, [rel msg_argv]
    call io_write_str
    mov  rdi, [r13]         ; argv[0] = program name pointer
    call io_write_str
    call io_newline

    ; ── Demonstrate bump_alloc ────────────────────────────────────────────────
    lea  rdi, [rel msg_alloc]
    call io_write_str

    mov  rdi, 128           ; allocate 128 bytes
    call bump_alloc
    mov  r15, rax           ; save pointer

    mov  rdi, r15
    call io_write_hex       ; print address
    call io_newline

    ; Write a string into the allocated memory
    ; "Heap-allocated string!" manually byte by byte
    mov  qword [r15],    0x2D70616548      ; "Heap"
    mov  qword [r15+4],  0x6C6C6F636361   ; "alloc"
    ; simpler: use a loop to copy from .rodata
    ; for this demo, just fill with 'A'
    mov  rdi, r15
    mov  al, 0x41
    mov  rcx, 16
    rep  stosb
    mov  byte [r15+16], 10
    mov  byte [r15+17], 0

    mov  rdi, r15
    call io_write_str

    ; ── Print heap usage ─────────────────────────────────────────────────────
    lea  rdi, [rel msg_heap]
    call io_write_str
    call heap_used
    mov  rdi, rax
    call io_write_u64
    lea  rdi, [rel msg_bytes]
    call io_write_str

    ; ── Done ─────────────────────────────────────────────────────────────────
    mov  rdi, STDOUT
    lea  rsi, [rel msg_done]
    mov  rdx, msg_done_len
    call sys_write

    xor  eax, eax           ; return 0

    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp
    ret
