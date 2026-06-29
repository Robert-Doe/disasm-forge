; =============================================================================
; control.asm  —  Module 06: Control Flow — Every Jump Instruction
; =============================================================================
bits 64

extern print_label
extern print_cstr           ; prints a null-terminated string
extern print_u64

section .rodata
    lbl_cmp      db "cmp vs test", 0
    lbl_if       db "if / else if / else", 0
    lbl_while    db "while loop", 0
    lbl_for      db "for loop (countdown)", 0
    lbl_switch   db "switch via jump table", 0

    ; strings for switch demo
    case0_str    db "case 0: zero", 10, 0
    case1_str    db "case 1: one", 10, 0
    case2_str    db "case 2: two", 10, 0
    case3_str    db "case 3: three", 10, 0
    case4_str    db "case 4: four", 10, 0
    default_str  db "default: out of range", 10, 0

    ; if/else strings
    pos_str      db "  value is positive", 10, 0
    zero_str     db "  value is zero", 10, 0
    neg_str      db "  value is negative", 10, 0

    ; for loop
    counting_str db "  counting: ", 0
    newline      db 10, 0

section .data
    ; jump table: 5 pointers to case handler labels
    ; each entry is 8 bytes (a 64-bit address)
    jump_table   dq case_0, case_1, case_2, case_3, case_4

section .text
    global main

%macro LABEL 1
    lea  rdi, [rel %1]
    lea  rcx, [rel %1]
    call print_label
%endmacro

%macro PRINTS 1
    lea  rdi, [rel %1]
    lea  rcx, [rel %1]
    call print_cstr
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

    ; ── cmp vs test ──────────────────────────────────────────────────────────
    LABEL lbl_cmp
    ; cmp a, b  computes (a - b) and sets flags, discards the result
    ; test a, b computes (a & b) and sets flags, discards the result
    ;
    ; cmp is used to compare two values
    ; test is used to check whether bits are set (especially test reg,reg for zero)

    mov  rax, 42
    cmp  rax, 42        ; sets ZF=1 (42-42=0), SF=0, OF=0, CF=0
    ; je  somewhere    ; would jump because ZF=1

    mov  rax, 5
    test rax, rax       ; sets ZF=0 (5&5=5≠0), SF=0 — canonical "is rax zero?" test
    ; jz  somewhere    ; would NOT jump because ZF=0

    ; ── if / else if / else ───────────────────────────────────────────────────
    LABEL lbl_if
    ; Classify a signed value: positive, zero, or negative
    ; We run this for three values to see all three branches
    mov  r12, -5        ; use callee-saved r12 as our loop value

.classify_loop:
    ; if (r12 > 0)        →  jg (jump if greater, signed)
    ; else if (r12 == 0)  →  je
    ; else                →  (implicit: must be negative)
    cmp  r12, 0
    jg   .is_positive
    je   .is_zero
    ; else: negative
    PRINTS neg_str
    jmp  .classify_next
.is_positive:
    PRINTS pos_str
    jmp  .classify_next
.is_zero:
    PRINTS zero_str
.classify_next:
    inc  r12
    cmp  r12, 2         ; run loop for -5,-4,...,+1 (but we stop at 1)
    jle  .classify_loop ; signed: jump if less-or-equal

    ; ── while loop ───────────────────────────────────────────────────────────
    LABEL lbl_while
    ; while (rax > 0) { print(rax); rax -= 3; }
    mov  rax, 15

.while_top:             ; condition check at the TOP (like C while)
    cmp  rax, 0
    jle  .while_done    ; exit if rax <= 0 (signed)
    SHOWu rax
    sub  rax, 3
    jmp  .while_top
.while_done:

    ; ── for loop (countdown) ─────────────────────────────────────────────────
    LABEL lbl_for
    ; for (rcx = 5; rcx > 0; rcx--) { print(rcx); }
    ; Assembly naturally inverts: count DOWN so the branch is "loop back if not zero"
    mov  rcx, 5

.for_loop:
    SHOWu rcx
    dec  rcx
    jnz  .for_loop      ; jump back if rcx != 0 (ZF=0)
                        ; equivalent to: loop .for_loop  (but dec+jnz is faster)

    ; ── switch via jump table ─────────────────────────────────────────────────
    LABEL lbl_switch
    ; switch(r13) { case 0..4: ...; default: ... }
    ; A jump table is an array of code addresses.
    ; We index into it with the switch value and jump to the address we find.

    mov  r13, 0         ; run all 6 cases (0-4 + default)
.switch_loop:
    cmp  r13, 4
    ja   .default       ; unsigned: if r13 > 4, go to default

    ; index into jump_table: each entry is 8 bytes
    lea  rbx, [rel jump_table]
    mov  rbx, [rbx + r13*8]    ; load the 8-byte address at jump_table[r13]
    jmp  rbx                    ; jump to that address

.case_done:
    inc  r13
    cmp  r13, 6
    jl   .switch_loop
    jmp  .switch_exit

    ; Case handlers — each falls through to .case_done
case_0:
    PRINTS case0_str
    jmp .case_done
case_1:
    PRINTS case1_str
    jmp .case_done
case_2:
    PRINTS case2_str
    jmp .case_done
case_3:
    PRINTS case3_str
    jmp .case_done
case_4:
    PRINTS case4_str
    jmp .case_done
.default:
    PRINTS default_str
    jmp .case_done

.switch_exit:
    xor  eax, eax
    add  rsp, 32
    pop  rbp
    ret
