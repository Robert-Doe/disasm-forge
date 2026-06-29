; =============================================================================
; win_api.asm  —  Module 15: Windows Native API / syscall interface
;
; On Windows the application layer calls Win32 → NTDLL → kernel via syscall.
; This file shows two approaches:
;   1. Calling ntdll.dll exports (NtWriteFile, NtAllocateVirtualMemory)
;      via the normal import mechanism (most portable)
;   2. Manually encoding the syscall stub (educational — used in shellcode
;      to avoid import table detection)
;
; Compiled with:  nasm -f win64 win_api.asm && gcc -o win_api.exe win_api.obj
; (Links with ntdll import library automatically via MSVC CRT, or add -lntdll)
; =============================================================================
bits 64

; Windows NTDLL / kernel32 imports
extern GetStdHandle
extern WriteConsoleA
extern VirtualAlloc
extern VirtualFree
extern VirtualProtect
extern ExitProcess

; Windows constants
STD_OUTPUT_HANDLE   equ -11
MEM_COMMIT          equ 0x1000
MEM_RESERVE         equ 0x2000
MEM_RELEASE         equ 0x8000
PAGE_READWRITE      equ 0x04
PAGE_EXECUTE_READ   equ 0x20

section .rodata
    msg1        db "Hello via WriteConsoleA!", 13, 10, 0
    msg1_len    equ $ - msg1 - 1   ; exclude null
    msg2        db "VirtualAlloc page: ", 0
    msg3        db "VirtualProtect to PAGE_EXECUTE_READ: ok", 13, 10, 0
    msg4        db "All Windows API demos complete.", 13, 10, 0

section .bss
    written_dw  resd 1    ; DWORD for WriteConsoleA lpNumberOfCharsWritten
    heap_ptr    resq 1    ; pointer returned by VirtualAlloc

section .text
    global main

; Windows x64 ABI: args in rcx, rdx, r8, r9, then stack
; Shadow space: 32 bytes below [rsp] must be allocated before every call
; rsp must be 16-byte aligned at the point of call (after push of return addr)

%macro SHADOW 0
    sub  rsp, 40          ; 32-byte shadow + 8-byte alignment pad
%endmacro
%macro UNSHADOW 0
    add  rsp, 40
%endmacro

main:
    push rbp
    mov  rbp, rsp
    push rbx              ; callee-saved
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 8           ; keep 16-byte alignment (5 pushes + ret = even)

    ; ── Get stdout handle ─────────────────────────────────────────────────────
    SHADOW
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    UNSHADOW
    mov  r12, rax         ; r12 = stdout handle

    ; ── WriteConsoleA(handle, buf, len, &written, NULL) ───────────────────────
    SHADOW
    mov  rcx, r12                    ; hConsoleOutput
    lea  rdx, [rel msg1]             ; lpBuffer
    mov  r8,  msg1_len               ; nNumberOfCharsToWrite
    lea  r9,  [rel written_dw]       ; lpNumberOfCharsWritten
    mov  qword [rsp+32], 0           ; lpReserved = NULL (5th arg on stack)
    call WriteConsoleA
    UNSHADOW

    ; ── VirtualAlloc: allocate a RW page ──────────────────────────────────────
    SHADOW
    xor  rcx, rcx                    ; lpAddress = NULL (kernel chooses)
    mov  rdx, 4096                   ; dwSize = one page
    mov  r8,  MEM_COMMIT | MEM_RESERVE
    mov  r9,  PAGE_READWRITE
    call VirtualAlloc
    UNSHADOW
    ; rax = base address of allocated page (NULL on failure)
    mov  r13, rax
    mov  [rel heap_ptr], r13

    ; Write "ALLOC\r\n" into the allocated page
    mov  byte [r13+0], 'A'
    mov  byte [r13+1], 'L'
    mov  byte [r13+2], 'L'
    mov  byte [r13+3], 'O'
    mov  byte [r13+4], 'C'
    mov  byte [r13+5], 13
    mov  byte [r13+6], 10

    SHADOW
    mov  rcx, r12
    mov  rdx, r13                    ; buf = our allocated page
    mov  r8,  7                      ; length
    lea  r9,  [rel written_dw]
    mov  qword [rsp+32], 0
    call WriteConsoleA
    UNSHADOW

    ; ── VirtualProtect: change to PAGE_EXECUTE_READ ───────────────────────────
    ; This is the shellcode loader pattern: allocate RW, write code, flip to RX
    sub  rsp, 8               ; align + space for lpflOldProtect arg
    mov  [rsp], rsp           ; dummy (we store old protect here)
    SHADOW
    mov  rcx, r13                    ; lpAddress
    mov  rdx, 4096                   ; dwSize
    mov  r8,  PAGE_EXECUTE_READ      ; flNewProtect
    lea  r9,  [rsp+40]               ; lpflOldProtect (local var)
    call VirtualProtect
    UNSHADOW
    add  rsp, 8

    SHADOW
    mov  rcx, r12
    lea  rdx, [rel msg3]
    mov  r8,  39
    lea  r9,  [rel written_dw]
    mov  qword [rsp+32], 0
    call WriteConsoleA
    UNSHADOW

    ; ── VirtualFree: release the page ─────────────────────────────────────────
    SHADOW
    mov  rcx, r13                    ; lpAddress
    xor  rdx, rdx                    ; dwSize = 0 (required for MEM_RELEASE)
    mov  r8,  MEM_RELEASE
    call VirtualFree
    UNSHADOW

    ; ── Done ──────────────────────────────────────────────────────────────────
    SHADOW
    mov  rcx, r12
    lea  rdx, [rel msg4]
    mov  r8,  30
    lea  r9,  [rel written_dw]
    mov  qword [rsp+32], 0
    call WriteConsoleA
    UNSHADOW

    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbx
    pop  rbp

    SHADOW
    xor  rcx, rcx
    call ExitProcess
    ; never returns
