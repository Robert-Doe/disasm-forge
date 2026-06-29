; =============================================================================
; syscall_wrappers.asm  —  Module 20: Bare-Metal Runtime
;
; Thin wrappers around Linux syscalls with C-compatible calling convention.
; Arguments arrive in rdi, rsi, rdx, rcx, r8, r9 (System V).
; syscall uses rdi, rsi, rdx, r10, r8, r9 (4th arg is r10, not rcx).
; =============================================================================
bits 64

global sys_write
global sys_read
global sys_open
global sys_close
global sys_mmap
global sys_munmap
global sys_brk
global sys_exit

SYS_READ   equ 0
SYS_WRITE  equ 1
SYS_OPEN   equ 2
SYS_CLOSE  equ 3
SYS_MMAP   equ 9
SYS_MUNMAP equ 11
SYS_BRK    equ 12
SYS_EXIT   equ 60

section .text

; ssize_t sys_write(int fd, const void *buf, size_t count)
sys_write:
    mov  rax, SYS_WRITE
    syscall
    ret

; ssize_t sys_read(int fd, void *buf, size_t count)
sys_read:
    mov  rax, SYS_READ
    syscall
    ret

; int sys_open(const char *path, int flags, int mode)
sys_open:
    mov  rax, SYS_OPEN
    syscall
    ret

; int sys_close(int fd)
sys_close:
    mov  rax, SYS_CLOSE
    syscall
    ret

; void* sys_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off)
; 4th arg (flags) arrives in rcx — must move to r10 for syscall ABI
sys_mmap:
    mov  r10, rcx           ; flags: 4th arg rcx → r10
    mov  rax, SYS_MMAP
    syscall
    ret

; int sys_munmap(void *addr, size_t len)
sys_munmap:
    mov  rax, SYS_MUNMAP
    syscall
    ret

; void* sys_brk(void *addr)
sys_brk:
    mov  rax, SYS_BRK
    syscall
    ret

; noreturn sys_exit(int status)
sys_exit:
    mov  rax, SYS_EXIT
    syscall
    ud2                     ; should never reach here; ud2 = undefined insn fault
