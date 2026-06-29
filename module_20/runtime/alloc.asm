; =============================================================================
; alloc.asm  —  Module 20: Bare-Metal Runtime
;
; A bump allocator using sys_brk.
;
; The "program break" is the top of the heap segment.
; sys_brk(0)    → returns current break (top of heap)
; sys_brk(addr) → moves the break to addr, returns new break
;
; Bump allocation: keep a pointer (heap_ptr) to the next free byte.
; Each allocation moves heap_ptr forward by the requested size.
; There is no free() — this is a monotonic allocator.
; For a runtime that runs briefly and exits, this is sufficient.
;
; Alignment: every allocation is rounded up to 8 bytes.
; =============================================================================
bits 64

extern sys_brk

global heap_init
global bump_alloc
global heap_used
global heap_base

section .bss
    heap_base  resq 1    ; pointer: base of the heap
    heap_ptr   resq 1    ; pointer: next free byte
    heap_end   resq 1    ; pointer: current break (end of usable region)

HEAP_INITIAL_SIZE equ 65536    ; 64 KiB initial reservation

section .text

; void heap_init(void)
; Called once from _start before our_main.
heap_init:
    push rbp
    mov  rbp, rsp

    ; Get current program break
    xor  rdi, rdi
    call sys_brk            ; rax = current break

    ; Save base
    mov  [rel heap_base], rax
    mov  [rel heap_ptr],  rax

    ; Extend heap by HEAP_INITIAL_SIZE
    add  rax, HEAP_INITIAL_SIZE
    mov  rdi, rax
    call sys_brk            ; rax = new break (or -1 on error)
    mov  [rel heap_end], rax

    pop  rbp
    ret

; void* bump_alloc(size_t size) → rax = pointer, or NULL on OOM
; Rounds size up to next multiple of 8.
bump_alloc:
    ; rdi = requested size
    add  rdi, 7             ; round up
    and  rdi, ~7            ; mask to 8-byte alignment

    mov  rax, [rel heap_ptr]
    mov  rcx, rax
    add  rcx, rdi           ; new heap_ptr after allocation

    ; Check if we have space
    mov  rdx, [rel heap_end]
    cmp  rcx, rdx
    ja   .oom               ; new_ptr > end → out of memory

    ; Commit: advance heap_ptr
    mov  [rel heap_ptr], rcx

    ; Return old heap_ptr (the allocated block)
    ret

.oom:
    ; Attempt to extend via sys_brk
    push rbx
    push r12
    mov  r12, rdi           ; save requested size

    mov  rax, [rel heap_end]
    add  rax, HEAP_INITIAL_SIZE  ; extend by another 64 KiB
    mov  rdi, rax
    call sys_brk
    ; rax = new break

    mov  rdx, [rel heap_end]
    cmp  rax, rdx
    je   .fail              ; sys_brk didn't extend (returned same value)

    mov  [rel heap_end], rax

    ; Retry allocation
    mov  rax, [rel heap_ptr]
    mov  rcx, rax
    add  rcx, r12
    mov  [rel heap_ptr], rcx

    pop  r12
    pop  rbx
    ret                     ; rax = allocated block

.fail:
    pop  r12
    pop  rbx
    xor  eax, eax           ; return NULL
    ret

; size_t heap_used(void) → rax = bytes allocated so far
heap_used:
    mov  rax, [rel heap_ptr]
    sub  rax, [rel heap_base]
    ret
