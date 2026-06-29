/* main.c — Module 21: Capstone Mini Disassembler
 *
 * Test driver for the disasm.asm assembly disassembler core.
 *
 * Tests:
 *   1. Decode a hand-crafted buffer of representative x86-64 opcodes
 *   2. Decode the bytes of this program's own main() function (self-disasm)
 *   3. Decode a small shellcode-like byte sequence
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>

#ifdef __linux__
#  include <sys/mman.h>
#  include <unistd.h>
#endif

#include "disasm.h"

/* ── Helper: print a disassembly listing for buf[0..len-1] ─────────────── */
static void disassemble(const char *label, const uint8_t *buf, size_t len)
{
    printf("\n=== %s (%zu bytes) ===\n", label, len);
    printf("  Bytes                    Mnemonic  Operands\n");
    printf("  ─────────────────────────────────────────────\n");

    size_t offset = 0;
    int    insn_count = 0;

    while (offset < len) {
        DisasmInsn insn;
        memset(&insn, 0, sizeof(insn));

        int n = disasm_decode(buf + offset, len - offset, &insn);
        if (n <= 0) {
            printf("  [decode error at offset %zu]\n", offset);
            break;
        }

        /* Format and print */
        char line[256];
        disasm_sprint(&insn, buf + offset, line, sizeof(line));

        /* Print with offset prefix */
        printf("  %04zx: %s", offset, line);

        offset += (size_t)n;
        insn_count++;

        /* Safety: stop after 64 instructions or if we hit RET/HLT */
        if (insn_count >= 64) {
            printf("  [... truncated at 64 instructions]\n");
            break;
        }
        /* Stop at RET or INT3 for self-disasm to avoid falling into data */
        if (insn.opcode == 0xC3 || insn.opcode == 0xCC || insn.opcode == 0xF4) {
            break;
        }
    }
    printf("  ─────────────────────────────────────────────\n");
    printf("  %d instruction(s) decoded\n", insn_count);
}

/* ── Test 1: representative opcode buffer ─────────────────────────────── */
static void test_opcode_buffer(void)
{
    static const uint8_t sample[] = {
        /* nop                             */ 0x90,
        /* push rbp                        */ 0x55,
        /* mov rbp, rsp                    */ 0x48, 0x89, 0xE5,
        /* sub rsp, 0x20                   */ 0x48, 0x81, 0xEC, 0x20, 0x00, 0x00, 0x00,
        /* mov rax, 0x4142434445464748     */ 0x48, 0xB8, 0x48, 0x47, 0x46, 0x45, 0x44, 0x43, 0x42, 0x41,
        /* xor eax, eax  (REX version)     */ 0x48, 0x33, 0xC0,
        /* cmp rax, rbx                    */ 0x48, 0x3B, 0xC3,
        /* jz +4                           */ 0x74, 0x04,
        /* jnz -8                          */ 0x75, 0xF8,
        /* call rel32 (+0)                 */ 0xE8, 0x00, 0x00, 0x00, 0x00,
        /* jmp rel32 (+0)                  */ 0xE9, 0x00, 0x00, 0x00, 0x00,
        /* mov qword [rsp+8], rcx          */ 0x48, 0x89, 0x4C, 0x24, 0x08,
        /* mov rax, [rbp-0x10]             */ 0x48, 0x8B, 0x45, 0xF0,
        /* add rsp, 0x20                   */ 0x48, 0x81, 0xC4, 0x20, 0x00, 0x00, 0x00,
        /* pop rbp                         */ 0x5D,
        /* ret                             */ 0xC3,
    };

    disassemble("Representative x86-64 opcodes", sample, sizeof(sample));
}

/* ── Test 2: Linux syscall sequence (write + exit) ────────────────────── */
static void test_syscall_sequence(void)
{
    static const uint8_t sc[] = {
        /* mov rax, 1       (SYS_WRITE)    */ 0x48, 0xC7, 0xC0, 0x01, 0x00, 0x00, 0x00,
        /* mov rdi, 1       (stdout)       */ 0x48, 0xC7, 0xC7, 0x01, 0x00, 0x00, 0x00,
        /* lea rsi, [rip+0] (buf)          */ 0x48, 0x8D, 0x35, 0x00, 0x00, 0x00, 0x00,
        /* mov rdx, 13      (len)          */ 0x48, 0xC7, 0xC2, 0x0D, 0x00, 0x00, 0x00,
        /* syscall                         */ 0x0F, 0x05,
        /* mov rax, 60      (SYS_EXIT)     */ 0x48, 0xC7, 0xC0, 0x3C, 0x00, 0x00, 0x00,
        /* xor rdi, rdi     (exit code 0)  */ 0x48, 0x31, 0xFF,
        /* syscall                         */ 0x0F, 0x05,
    };

    disassemble("Linux write+exit syscall sequence", sc, sizeof(sc));
}

/* ── Test 3: Decoder accuracy — decode + re-verify length ─────────────── */
static void test_lengths(void)
{
    /* Each pair: {bytes..., expected_length} */
    struct { uint8_t bytes[16]; int blen; int expected; const char *name; } cases[] = {
        {{0x90},                               1,  1, "NOP"},
        {{0xC3},                               1,  1, "RET"},
        {{0xCC},                               1,  1, "INT3"},
        {{0x48, 0x89, 0xE5},                   3,  3, "MOV rbp,rsp"},
        {{0x48, 0xB8, 1,2,3,4,5,6,7,8},       10, 10, "MOV rax,imm64"},
        {{0xE8, 0,0,0,0},                      5,  5, "CALL rel32"},
        {{0x0F, 0x05},                         2,  2, "SYSCALL"},
        {{0x48, 0x81, 0xEC, 0x20,0,0,0},       7,  7, "SUB rsp,imm32"},
        {{0x48, 0x8B, 0x45, 0xF0},             4,  4, "MOV rax,[rbp-16]"},
        {{0x0F, 0x84, 0,0,0,0},                6,  6, "JZ rel32"},
    };

    printf("\n=== Instruction length accuracy ===\n");
    int pass = 0, fail = 0;
    for (int i = 0; i < (int)(sizeof(cases)/sizeof(cases[0])); i++) {
        DisasmInsn insn;
        memset(&insn, 0, sizeof(insn));
        int got = disasm_decode(cases[i].bytes, cases[i].blen, &insn);
        int ok = (got == cases[i].expected);
        printf("  %s %-20s  expected=%d  got=%d  %s\n",
               ok ? "[PASS]" : "[FAIL]",
               cases[i].name,
               cases[i].expected, got,
               ok ? "" : "  <-- MISMATCH");
        if (ok) pass++; else fail++;
    }
    printf("  Result: %d passed, %d failed\n", pass, fail);
}

/* ── Test 4: Self-disassembly of test_opcode_buffer() ─────────────────── */
static void test_self_disasm(void)
{
    /* Point at the machine code of test_lengths itself */
    const uint8_t *fn = (const uint8_t *)test_lengths;
    disassemble("Self-disassembly of test_lengths()", fn, 128);
}

int main(void)
{
    printf("╔══════════════════════════════════════════════╗\n");
    printf("║   Module 21 — Mini x86-64 Disassembler      ║\n");
    printf("╚══════════════════════════════════════════════╝\n");

    test_opcode_buffer();
    test_syscall_sequence();
    test_lengths();
    test_self_disasm();

    printf("\nAll tests complete.\n");
    return 0;
}
