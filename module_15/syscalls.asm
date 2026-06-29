; =============================================================================
; syscalls.asm  —  Module 15: System Calls & Direct OS Interaction (Linux)
;
; Demonstrates the Linux x86-64 syscall interface with zero libc dependency.
; Each section invokes the kernel directly via the SYSCALL instruction.
;
; Linux syscall ABI:
;   rax = syscall number
;   rdi, rsi, rdx, r10, r8, r9 = arguments (NOT rcx — SYSCALL destroys rcx)
;   Return value in rax (negative errno on error)
; =============================================================================
bits 64

; ── Syscall numbers (x86-64 Linux) ──────────────────────────────────────────
SYS_READ    equ 0
SYS_WRITE   equ 1
SYS_OPEN    equ 2
SYS_CLOSE   equ 3
SYS_MMAP    equ 9
SYS_MPROTECT equ 10
SYS_MUNMAP  equ 11
SYS_BRK     equ 12
SYS_EXIT    equ 60

; ── mmap flags & protection ──────────────────────────────────────────────────
PROT_READ    equ 1
PROT_WRITE   equ 2
PROT_EXEC    equ 4
PROT_NONE    equ 0

MAP_PRIVATE  equ 2
MAP_ANONYMOUS equ 0x20
MAP_ANON     equ MAP_ANONYMOUS
MAP_FIXED    equ 0x10

; ── O_flags ──────────────────────────────────────────────────────────────────
O_RDONLY    equ 0
O_WRONLY    equ 1
O_CREAT     equ 0x40
O_TRUNC     equ 0x200
O_RDWR      equ 2

; File descriptor constants
STDIN   equ 0
STDOUT  equ 1
STDERR  equ 2

section .rodata
    msg_hello   db "Hello from syscall write!", 10
    msg_hello_len equ $ - msg_hello

    msg_open    db "Opening /tmp/asm_test.txt ...", 10
    msg_open_len equ $ - msg_open

    msg_mmap    db "Allocated page via mmap", 10
    msg_mmap_len equ $ - msg_mmap

    msg_done    db "All syscall demos complete.", 10
    msg_done_len equ $ - msg_done

    file_path   db "/tmp/asm_test.txt", 0
    file_write  db "Written by assembly syscall", 10
    file_write_len equ $ - file_write

    hex_chars   db "0123456789ABCDEF"

section .bss
    read_buf    resb 64    ; buffer for reading back the file
    hex_buf     resb 20    ; buffer for hex number output

section .text
    global _start

; ─────────────────────────────────────────────────────────────────────────────
; sys_write(fd, buf, count) — inline helper macro
; ─────────────────────────────────────────────────────────────────────────────
%macro SYS_WRITE 3
    mov  rax, SYS_WRITE
    mov  rdi, %1
    mov  rsi, %2
    mov  rdx, %3
    syscall
%endmacro

; ─────────────────────────────────────────────────────────────────────────────
; print_hex(rax) — prints rax as 16 hex digits to stdout
; Clobbers: rbx, rcx, rdx, rsi, rdi, rax
; ─────────────────────────────────────────────────────────────────────────────
print_hex:
    mov  rcx, 16
    lea  rsi, [rel hex_buf + 18]  ; work backwards from end
    mov  byte [rsi+1], 10          ; newline
    mov  rbx, rax                  ; value to print
.digit:
    mov  rax, rbx
    and  rax, 0xF                  ; low nibble
    lea  rdx, [rel hex_chars]
    movzx eax, byte [rdx + rax]    ; lookup hex char
    mov  [rsi], al
    dec  rsi
    shr  rbx, 4
    dec  rcx
    jnz  .digit
    ; rsi now points one before start; move forward to start
    inc  rsi
    ; write 17 bytes (16 hex + newline)
    SYS_WRITE STDOUT, rsi, 17
    ret

; ─────────────────────────────────────────────────────────────────────────────
; _start — entry point, no C runtime
; ─────────────────────────────────────────────────────────────────────────────
_start:
    ; ── 1. sys_write: print to stdout ─────────────────────────────────────────
    SYS_WRITE STDOUT, msg_hello, msg_hello_len

    ; ── 2. sys_write to stderr ────────────────────────────────────────────────
    mov  rax, SYS_WRITE
    mov  rdi, STDERR
    lea  rsi, [rel msg_hello]
    mov  rdx, msg_hello_len
    syscall
    ; rax = bytes written (or negative errno)

    ; ── 3. sys_open + sys_write + sys_close ───────────────────────────────────
    SYS_WRITE STDOUT, msg_open, msg_open_len

    ; Open file (create/truncate)
    mov  rax, SYS_OPEN
    lea  rdi, [rel file_path]
    mov  rsi, O_WRONLY | O_CREAT | O_TRUNC
    mov  rdx, 0o644              ; octal permissions: rw-r--r--
    syscall
    ; rax = file descriptor (or negative errno)
    mov  r12, rax                ; save fd

    ; Write to the file
    mov  rax, SYS_WRITE
    mov  rdi, r12
    lea  rsi, [rel file_write]
    mov  rdx, file_write_len
    syscall

    ; Close the file
    mov  rax, SYS_CLOSE
    mov  rdi, r12
    syscall

    ; Read it back: re-open O_RDONLY
    mov  rax, SYS_OPEN
    lea  rdi, [rel file_path]
    mov  rsi, O_RDONLY
    xor  rdx, rdx
    syscall
    mov  r12, rax

    ; Read up to 64 bytes
    mov  rax, SYS_READ
    mov  rdi, r12
    lea  rsi, [rel read_buf]
    mov  rdx, 64
    syscall
    mov  r13, rax                ; bytes actually read

    ; Write what we read back to stdout
    mov  rax, SYS_WRITE
    mov  rdi, STDOUT
    lea  rsi, [rel read_buf]
    mov  rdx, r13
    syscall

    ; Close
    mov  rax, SYS_CLOSE
    mov  rdi, r12
    syscall

    ; ── 4. sys_mmap: allocate an anonymous page ────────────────────────────────
    SYS_WRITE STDOUT, msg_mmap, msg_mmap_len

    ; mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
    mov  rax, SYS_MMAP
    xor  rdi, rdi                ; addr = NULL (kernel chooses)
    mov  rsi, 4096               ; length = one page
    mov  rdx, PROT_READ | PROT_WRITE
    mov  r10, MAP_PRIVATE | MAP_ANON
    mov  r8, -1                  ; fd = -1 (anonymous)
    xor  r9, r9                  ; offset = 0
    syscall
    ; rax = mapped address (or MAP_FAILED = -1)
    mov  r14, rax                ; save mapped address

    ; Print the mapped address as hex
    mov  rax, r14
    call print_hex

    ; Write a string into the mapped memory
    mov  byte [r14+0], 'M'
    mov  byte [r14+1], 'A'
    mov  byte [r14+2], 'P'
    mov  byte [r14+3], '!'
    mov  byte [r14+4], 10

    SYS_WRITE STDOUT, r14, 5    ; prints "MAP!\n"

    ; ── 5. sys_mprotect: make the page executable ─────────────────────────────
    ; (This is what shellcode loaders do to writable pages)
    mov  rax, SYS_MPROTECT
    mov  rdi, r14
    mov  rsi, 4096
    mov  rdx, PROT_READ | PROT_EXEC
    syscall
    ; rax = 0 on success

    ; ── 6. sys_munmap: release the page ───────────────────────────────────────
    mov  rax, SYS_MUNMAP
    mov  rdi, r14
    mov  rsi, 4096
    syscall

    ; ── 7. sys_brk: query current program break ───────────────────────────────
    ; sys_brk(0) returns the current break (top of heap)
    mov  rax, SYS_BRK
    xor  rdi, rdi
    syscall
    ; rax = current break address
    mov  r15, rax
    mov  rax, r15
    call print_hex               ; print heap top

    ; ── 8. sys_exit ───────────────────────────────────────────────────────────
    SYS_WRITE STDOUT, msg_done, msg_done_len

    mov  rax, SYS_EXIT
    xor  rdi, rdi                ; exit code 0
    syscall
    ; Never returns
