/* disasm.h — Module 21: Capstone Mini Disassembler
 *
 * Public C interface to the assembly disassembler core.
 * All functions follow the System V AMD64 ABI.
 */
#ifndef DISASM_H
#define DISASM_H

#include <stdint.h>
#include <stddef.h>

/* Maximum decoded-instruction string length */
#define DISASM_MNEMONIC_MAX 64
#define DISASM_OPERANDS_MAX 64

/* Operand types returned in DisasmInsn.op_type */
typedef enum {
    OP_NONE   = 0,
    OP_REG    = 1,
    OP_IMM    = 2,
    OP_MEM    = 3,
    OP_REL    = 4     /* relative branch target */
} OpType;

/* Decoded instruction structure — filled by disasm_decode() */
typedef struct {
    uint8_t  length;                     /* total byte length of instruction   */
    uint8_t  opcode;                     /* primary opcode byte (after REX/pfx)*/
    uint8_t  has_rex;                    /* 1 if REX prefix present            */
    uint8_t  rex;                        /* REX byte value                     */
    uint8_t  has_modrm;                  /* 1 if ModRM byte present            */
    uint8_t  modrm;                      /* ModRM byte value                   */
    uint8_t  has_sib;                    /* 1 if SIB byte present              */
    uint8_t  sib;                        /* SIB byte value                     */
    int32_t  disp;                       /* displacement (sign-extended)       */
    int64_t  imm;                        /* immediate value (sign-extended)    */
    OpType   op_type;                    /* primary operand type               */
    char     mnemonic[DISASM_MNEMONIC_MAX];
    char     operands[DISASM_OPERANDS_MAX];
} DisasmInsn;

/*
 * disasm_decode(buf, buf_len, insn) → instruction byte length, or 0 on error.
 *
 * Decodes the first instruction in buf[0..buf_len-1].
 * Fills *insn with parsed fields.
 * Returns the number of bytes consumed (== insn->length), or 0 if unrecognised.
 *
 * Implemented in capstone/disasm.asm.
 */
extern int disasm_decode(const uint8_t *buf, size_t buf_len, DisasmInsn *insn);

/*
 * disasm_sprint(insn, out, out_len) — format decoded instruction into out[].
 *
 * Writes "OFFSET  HEX_BYTES  MNEMONIC  OPERANDS" into out.
 * Returns number of characters written (without null terminator).
 *
 * Implemented in capstone/disasm.asm.
 */
extern int disasm_sprint(const DisasmInsn *insn, const uint8_t *raw, char *out, size_t out_len);

#endif /* DISASM_H */
