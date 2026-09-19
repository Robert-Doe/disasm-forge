// decoder.ts — TypeScript port of module_21/capstone/disasm.asm
//
// This ports the REAL decoding algorithm taught in Module 21 (the course's
// own capstone): REX prefix detection, ModRM mod/reg/rm extraction, SIB
// scale/index/base extraction, displacement/immediate reading, and
// Intel-syntax mnemonic formatting for a deliberately limited instruction
// subset. See module_21/README.md and module_21/capstone/disasm.asm's own
// header comment for the exact list this was scoped to.
//
// Two intentional departures from the original assembly, both documented at
// the call site below:
//   1. SIB addressing is decoded for REAL (base/index*scale/disp) instead of
//      the original's hardcoded "[rsp+sib]" placeholder string — the asm
//      comment for decode_modrm's .has_sib branch says "for simplicity,
//      emit... or just [base+disp]" and never actually does; this port
//      finishes that intent properly.
//   2. Everything else — including several genuine quirks of the taught
//      encoder (immediates/displacements always rendered as unsigned
//      zero-padded hex with no minus sign; MOV r64,imm64 always consuming a
//      full 8-byte immediate with no REX.W check) — is preserved exactly,
//      because those are real, observable behaviors of the module's own
//      tool, not accidents of the port.

export type FieldTag = 'prefix' | 'opcode' | 'modrm' | 'sib' | 'disp' | 'imm';

export interface FieldByte {
  offset: number; // absolute offset within the input buffer
  byte: number;
  field: FieldTag;
}

export interface RexInfo {
  byte: number;
  W: boolean;
  R: boolean;
  X: boolean;
  B: boolean;
}

export interface ModrmInfo {
  byte: number;
  mod: number;
  reg: number;
  rm: number;
}

export interface SibInfo {
  byte: number;
  scale: number;
  index: number;
  base: number;
}

export interface DecodedInstruction {
  offset: number;
  length: number;
  bytes: number[];
  rex: RexInfo | null;
  opcodeBytes: number[]; // 1 byte, or 2 for the 0F escape
  modrm: ModrmInfo | null;
  sib: SibInfo | null;
  dispBytes: number[];
  immBytes: number[];
  mnemonic: string;
  operands: string;
  text: string; // "mnemonic operands" (or just "mnemonic")
  fields: FieldByte[]; // every consumed byte, tagged, in offset order
  isUnknown: boolean;
}

const REG64 = ['rax', 'rcx', 'rdx', 'rbx', 'rsp', 'rbp', 'rsi', 'rdi'];
const REG64_EXT = ['r8', 'r9', 'r10', 'r11', 'r12', 'r13', 'r14', 'r15'];
const CC = ['o', 'no', 'b', 'nb', 'z', 'nz', 'be', 'nbe', 's', 'ns', 'p', 'np', 'l', 'nl', 'le', 'nle'];

function regName(idx: number, extended: boolean): string {
  return extended ? REG64_EXT[idx] : REG64[idx];
}

function hex32(v: number): string {
  return (v >>> 0).toString(16).padStart(8, '0');
}

function hex2(v: number): string {
  return (v & 0xff).toString(16).padStart(2, '0');
}

function readInt8(buf: Uint8Array, o: number): number {
  const v = buf[o];
  return v >= 0x80 ? v - 0x100 : v;
}

function readInt32(buf: Uint8Array, o: number): number {
  return (buf[o] | (buf[o + 1] << 8) | (buf[o + 2] << 16) | (buf[o + 3] << 24)) | 0;
}

/** Reads 8 raw bytes (little-endian in memory) and renders them as a
 * 16-digit big-endian hex string — matches append_u64_hex's shift-from-
 * bit-60-down output order, without needing 64-bit integer arithmetic. */
function hex64LE(buf: Uint8Array, o: number): string {
  const bytes = Array.from(buf.slice(o, o + 8));
  while (bytes.length < 8) bytes.push(0);
  return bytes.slice().reverse().map((b) => b.toString(16).padStart(2, '0')).join('');
}

interface ModrmDecodeResult {
  newOffset: number;
  modrm: ModrmInfo;
  sib: SibInfo | null;
  dispBytes: number[];
  rmText: string;
  rmIsReg: boolean;
  fields: FieldByte[];
}

/** Decodes ModRM (+ SIB + displacement) starting at `offset`, which must
 * point at the ModRM byte itself. `rex` is null when no REX prefix was
 * present. Returns the formatted operand text for the r/m side. */
function decodeModrm(buf: Uint8Array, offset: number, rex: RexInfo | null): ModrmDecodeResult {
  const rexB = !!rex?.B;
  const rexX = !!rex?.X;

  const modrmByte = buf[offset];
  const mod = (modrmByte >> 6) & 3;
  const reg = (modrmByte >> 3) & 7;
  const rm = modrmByte & 7;
  let o = offset + 1;
  const fields: FieldByte[] = [{ offset, byte: modrmByte, field: 'modrm' }];
  const modrm: ModrmInfo = { byte: modrmByte, mod, reg, rm };

  if (mod === 3) {
    return { newOffset: o, modrm, sib: null, dispBytes: [], rmText: regName(rm, rexB), rmIsReg: true, fields };
  }

  if (rm === 4) {
    // SIB byte present.
    const sibByte = buf[o];
    fields.push({ offset: o, byte: sibByte, field: 'sib' });
    const scale = (sibByte >> 6) & 3;
    const index = (sibByte >> 3) & 7;
    const base = sibByte & 7;
    o += 1;
    const sib: SibInfo = { byte: sibByte, scale, index, base };

    let baseText: string | null = null;
    let disp = 0;
    let dispBytes: number[] = [];
    let noBaseDispOnly = false;

    if (mod === 0 && base === 5) {
      noBaseDispOnly = true;
      disp = readInt32(buf, o);
      dispBytes = Array.from(buf.slice(o, o + 4));
      for (let i = 0; i < 4; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'disp' });
      o += 4;
    } else {
      baseText = regName(base, rexB);
      if (mod === 1) {
        disp = readInt8(buf, o);
        dispBytes = [buf[o]];
        fields.push({ offset: o, byte: buf[o], field: 'disp' });
        o += 1;
      } else if (mod === 2) {
        disp = readInt32(buf, o);
        dispBytes = Array.from(buf.slice(o, o + 4));
        for (let i = 0; i < 4; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'disp' });
        o += 4;
      }
    }

    const indexText = index === 4 ? null : `${regName(index, rexX)}*${1 << scale}`;
    const parts = [baseText, indexText].filter((x): x is string => !!x).join('+');
    let rmText: string;
    if (noBaseDispOnly || disp !== 0) {
      rmText = `[${parts}${parts ? '+' : ''}0x${hex32(disp)}]`;
    } else {
      rmText = `[${parts}]`;
    }
    return { newOffset: o, modrm, sib, dispBytes, rmText, rmIsReg: false, fields };
  }

  if (mod === 0 && rm === 5) {
    // RIP-relative addressing.
    const disp = readInt32(buf, o);
    const dispBytes = Array.from(buf.slice(o, o + 4));
    for (let i = 0; i < 4; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'disp' });
    o += 4;
    return { newOffset: o, modrm, sib: null, dispBytes, rmText: `[rip+0x${hex32(disp)}]`, rmIsReg: false, fields };
  }

  // Normal base register, no SIB.
  const baseText = regName(rm, rexB);
  let disp = 0;
  let dispBytes: number[] = [];
  if (mod === 1) {
    disp = readInt8(buf, o);
    dispBytes = [buf[o]];
    fields.push({ offset: o, byte: buf[o], field: 'disp' });
    o += 1;
  } else if (mod === 2) {
    disp = readInt32(buf, o);
    dispBytes = Array.from(buf.slice(o, o + 4));
    for (let i = 0; i < 4; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'disp' });
    o += 4;
  }
  const rmText = disp !== 0 ? `[${baseText}+0x${hex32(disp)}]` : `[${baseText}]`;
  return { newOffset: o, modrm, sib: null, dispBytes, rmText, rmIsReg: false, fields };
}

const ALU_RM_R: Record<number, string> = { 0x01: 'add', 0x09: 'or', 0x21: 'and', 0x29: 'sub', 0x31: 'xor', 0x39: 'cmp' };
const ALU_R_RM: Record<number, string> = { 0x03: 'add', 0x0b: 'or', 0x23: 'and', 0x2b: 'sub', 0x33: 'xor', 0x3b: 'cmp' };
const GROUP81: Record<number, string> = { 0: 'add', 1: 'or', 4: 'and', 5: 'sub', 6: 'xor', 7: 'cmp' };
const GROUPF7: Record<number, string> = { 0: 'test', 2: 'not', 3: 'neg', 4: 'mul', 6: 'div', 7: 'idiv' };
const GROUPFF: Record<number, string> = { 0: 'inc', 1: 'dec', 2: 'call', 4: 'jmp' };

/** Decodes exactly one instruction starting at `offset`. Returns null only
 * when there are zero bytes available (mirrors disasm_decode returning 0
 * for buf_len == 0). Any opcode this subset doesn't recognise still decodes
 * successfully as a 1-instruction "db 0xXX" fallback, exactly like the
 * original — its length equals however many prefix+opcode bytes were
 * already consumed by the time recognition failed. */
export function decodeOne(buf: Uint8Array, offset: number): DecodedInstruction | null {
  if (offset >= buf.length) return null;

  const start = offset;
  let o = offset;
  const fields: FieldByte[] = [];
  let rex: RexInfo | null = null;

  const b0 = buf[o];
  if (b0 >= 0x40 && b0 <= 0x4f) {
    if (o + 1 >= buf.length) return null; // REX with nothing after it
    rex = { byte: b0, W: !!(b0 & 0x08), R: !!(b0 & 0x04), X: !!(b0 & 0x02), B: !!(b0 & 0x01) };
    fields.push({ offset: o, byte: b0, field: 'prefix' });
    o += 1;
  }

  const opcode = buf[o];
  fields.push({ offset: o, byte: opcode, field: 'opcode' });
  o += 1;

  let mnemonic = '';
  let operands = '';
  let modrmInfo: ModrmInfo | null = null;
  let sibInfo: SibInfo | null = null;
  let dispBytes: number[] = [];
  let immBytes: number[] = [];
  let isUnknown = false;
  let opcodeBytes = [opcode];

  const rexR = !!rex?.R;
  const rexB = !!rex?.B;

  function doModrmRmReg(mnem: string, order: 'rm,reg' | 'reg,rm') {
    const r = decodeModrm(buf, o, rex);
    o = r.newOffset;
    fields.push(...r.fields);
    modrmInfo = r.modrm;
    sibInfo = r.sib;
    dispBytes = r.dispBytes;
    const regText = regName(r.modrm.reg, rexR);
    mnemonic = mnem;
    operands = order === 'rm,reg' ? `${r.rmText}, ${regText}` : `${regText}, ${r.rmText}`;
  }

  function readImm32(): number {
    const v = readInt32(buf, o);
    immBytes = Array.from(buf.slice(o, o + 4));
    for (let i = 0; i < 4; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'imm' });
    o += 4;
    return v;
  }

  function readImm8Signed(): number {
    const v = readInt8(buf, o);
    immBytes = [buf[o]];
    fields.push({ offset: o, byte: buf[o], field: 'imm' });
    o += 1;
    return v;
  }

  dispatch: {
    if (opcode === 0x90) { mnemonic = 'nop'; break dispatch; }
    if (opcode === 0xc3) { mnemonic = 'ret'; break dispatch; }
    if (opcode === 0xcb) { mnemonic = 'retf'; break dispatch; }
    if (opcode === 0xc9) { mnemonic = 'leave'; break dispatch; }
    if (opcode === 0xcc) { mnemonic = 'int3'; break dispatch; }
    if (opcode === 0xf4) { mnemonic = 'hlt'; break dispatch; }

    if (opcode === 0x0f) {
      if (o >= buf.length) { isUnknown = true; mnemonic = 'db'; operands = `0x${hex2(opcode)}`; break dispatch; }
      const b2 = buf[o];
      fields.push({ offset: o, byte: b2, field: 'opcode' });
      opcodeBytes = [opcode, b2];
      o += 1;

      if (b2 === 0x05) { mnemonic = 'syscall'; break dispatch; }
      if (b2 === 0x0b) { mnemonic = 'ud2'; break dispatch; }
      if (b2 >= 0x80 && b2 <= 0x8f) {
        mnemonic = 'j' + CC[b2 & 0xf];
        operands = `0x${hex32(readImm32())}`;
        break dispatch;
      }
      if (b2 >= 0x40 && b2 <= 0x4f) {
        mnemonic = 'cmov' + CC[b2 & 0xf];
        doModrmRmReg(mnemonic, 'reg,rm');
        break dispatch;
      }
      if (b2 >= 0x90 && b2 <= 0x9f) {
        mnemonic = 'set' + CC[b2 & 0xf];
        const r = decodeModrm(buf, o, rex);
        o = r.newOffset;
        fields.push(...r.fields);
        modrmInfo = r.modrm;
        sibInfo = r.sib;
        dispBytes = r.dispBytes;
        operands = r.rmText;
        break dispatch;
      }
      if (b2 === 0xb6 || b2 === 0xb7) { doModrmRmReg('movzx', 'reg,rm'); break dispatch; }
      if (b2 === 0xbe || b2 === 0xbf) { doModrmRmReg('movsx', 'reg,rm'); break dispatch; }
      if (b2 === 0xaf) { doModrmRmReg('imul', 'reg,rm'); break dispatch; }

      isUnknown = true;
      mnemonic = 'db';
      operands = `0x${hex2(b2)}`;
      break dispatch;
    }

    if (opcode >= 0x50 && opcode <= 0x57) { mnemonic = 'push'; operands = regName(opcode & 7, rexB); break dispatch; }
    if (opcode >= 0x58 && opcode <= 0x5f) { mnemonic = 'pop'; operands = regName(opcode & 7, rexB); break dispatch; }

    if (opcode >= 0xb8 && opcode <= 0xbf) {
      // MOV r64, imm64 — always reads a full 8-byte immediate, with no
      // REX.W check. That matches disasm.asm exactly; real hardware would
      // treat this as MOV r32,imm32 (4-byte immediate) without REX.W. Every
      // worked example in module_21 uses the REX.W-prefixed form, so this
      // never actually diverges from correct decoding on this course's own
      // material — noted here because it's a genuine quirk, not a bug we
      // introduced.
      mnemonic = 'mov';
      const hex = hex64LE(buf, o);
      immBytes = Array.from(buf.slice(o, o + 8));
      for (let i = 0; i < 8; i++) fields.push({ offset: o + i, byte: buf[o + i], field: 'imm' });
      o += 8;
      operands = `${regName(opcode & 7, rexB)}, 0x${hex}`;
      break dispatch;
    }

    if (opcode === 0x6a) { mnemonic = 'push'; operands = `0x${hex32(readImm8Signed())}`; break dispatch; }
    if (opcode === 0x68) { mnemonic = 'push'; operands = `0x${hex32(readImm32())}`; break dispatch; }
    if (opcode === 0xe8) { mnemonic = 'call'; operands = `0x${hex32(readImm32())}`; break dispatch; }
    if (opcode === 0xe9) { mnemonic = 'jmp'; operands = `0x${hex32(readImm32())}`; break dispatch; }
    if (opcode === 0xeb) { mnemonic = 'jmp'; operands = `0x${hex32(readImm8Signed())}`; break dispatch; }
    if (opcode >= 0x70 && opcode <= 0x7f) { mnemonic = 'j' + CC[opcode & 0xf]; operands = `0x${hex32(readImm8Signed())}`; break dispatch; }

    if (opcode in ALU_RM_R) { doModrmRmReg(ALU_RM_R[opcode], 'rm,reg'); break dispatch; }
    if (opcode in ALU_R_RM) { doModrmRmReg(ALU_R_RM[opcode], 'reg,rm'); break dispatch; }

    if (opcode === 0x89) { doModrmRmReg('mov', 'rm,reg'); break dispatch; }
    if (opcode === 0x8b) { doModrmRmReg('mov', 'reg,rm'); break dispatch; }
    if (opcode === 0x8d) { doModrmRmReg('lea', 'reg,rm'); break dispatch; }
    if (opcode === 0x85) { doModrmRmReg('test', 'rm,reg'); break dispatch; }

    if (opcode === 0xc7) {
      const r = decodeModrm(buf, o, rex);
      o = r.newOffset;
      fields.push(...r.fields);
      modrmInfo = r.modrm; sibInfo = r.sib; dispBytes = r.dispBytes;
      mnemonic = 'mov';
      operands = `${r.rmText}, 0x${hex32(readImm32())}`;
      break dispatch;
    }

    if (opcode === 0x81) {
      // Group 1 (imm32): the ModRM reg field selects the actual operation.
      const sub = (buf[o] >> 3) & 7;
      const name = GROUP81[sub];
      if (name === undefined) { isUnknown = true; mnemonic = 'db'; operands = `0x${hex2(opcode)}`; break dispatch; }
      const r = decodeModrm(buf, o, rex);
      o = r.newOffset;
      fields.push(...r.fields);
      modrmInfo = r.modrm; sibInfo = r.sib; dispBytes = r.dispBytes;
      mnemonic = name;
      operands = `${r.rmText}, 0x${hex32(readImm32())}`;
      break dispatch;
    }

    if (opcode === 0xf7) {
      const sub = (buf[o] >> 3) & 7;
      const name = GROUPF7[sub];
      if (name === undefined) { isUnknown = true; mnemonic = 'db'; operands = `0x${hex2(opcode)}`; break dispatch; }
      const r = decodeModrm(buf, o, rex);
      o = r.newOffset;
      fields.push(...r.fields);
      modrmInfo = r.modrm; sibInfo = r.sib; dispBytes = r.dispBytes;
      mnemonic = name;
      if (sub === 0) {
        operands = `${r.rmText}, 0x${hex32(readImm32())}`;
      } else {
        operands = r.rmText;
      }
      break dispatch;
    }

    if (opcode === 0xff) {
      const sub = (buf[o] >> 3) & 7;
      const name = GROUPFF[sub];
      if (name === undefined) { isUnknown = true; mnemonic = 'db'; operands = `0x${hex2(opcode)}`; break dispatch; }
      const r = decodeModrm(buf, o, rex);
      o = r.newOffset;
      fields.push(...r.fields);
      modrmInfo = r.modrm; sibInfo = r.sib; dispBytes = r.dispBytes;
      mnemonic = name;
      operands = r.rmText;
      break dispatch;
    }

    isUnknown = true;
    mnemonic = 'db';
    operands = `0x${hex2(opcode)}`;
  }

  const length = o - start;
  const bytes = Array.from(buf.slice(start, o));
  fields.sort((a, b) => a.offset - b.offset);

  return {
    offset: start,
    length,
    bytes,
    rex,
    opcodeBytes,
    modrm: modrmInfo,
    sib: sibInfo,
    dispBytes,
    immBytes,
    mnemonic,
    operands,
    text: operands ? `${mnemonic} ${operands}` : mnemonic,
    fields,
    isUnknown,
  };
}

export interface DisassemblyListing {
  instructions: DecodedInstruction[];
  totalBytes: number;
}

/** Decodes a whole buffer, instruction after instruction, the same way
 * main.c's disassemble() helper does — but without its early-exit on
 * RET/INT3/HLT, since this tool is meant to decode whatever the user
 * pastes, not just self-disassembly output. */
export function disassemble(buf: Uint8Array, maxInstructions = 256): DisassemblyListing {
  const instructions: DecodedInstruction[] = [];
  let offset = 0;
  while (offset < buf.length && instructions.length < maxInstructions) {
    const insn = decodeOne(buf, offset);
    if (!insn) break;
    instructions.push(insn);
    offset += insn.length;
  }
  return { instructions, totalBytes: offset };
}

/** Parses freeform hex text ("48 89 e5", "4889e5", "0x48,0x89,0xE5", with
 * newlines/comments) into a byte array. */
export function parseHexBytes(text: string): Uint8Array {
  const cleaned = text
    .split('\n')
    .map((line) => line.replace(/;.*$/, '').replace(/\/\/.*$/, ''))
    .join(' ')
    .replace(/0x/gi, ' ')
    .replace(/[^0-9a-fA-F]+/g, ' ')
    .trim();
  if (!cleaned) return new Uint8Array(0);
  const tokens = cleaned.split(/\s+/);
  const bytes: number[] = [];
  for (const tok of tokens) {
    if (tok.length % 2 === 0) {
      for (let i = 0; i < tok.length; i += 2) bytes.push(parseInt(tok.slice(i, i + 2), 16));
    } else {
      // Odd-length run (e.g. pasted without separators oddly) — pull nibbles
      // off two at a time, left-padding the final leftover nibble.
      let i = 0;
      while (i + 1 < tok.length) { bytes.push(parseInt(tok.slice(i, i + 2), 16)); i += 2; }
      if (i < tok.length) bytes.push(parseInt(tok.slice(i, i + 1), 16));
    }
  }
  return new Uint8Array(bytes);
}
