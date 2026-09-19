import './style.css';
import { disassemble, parseHexBytes, type DecodedInstruction, type FieldTag } from './decoder';

const app = document.querySelector<HTMLDivElement>('#app')!;

const QUICKLOADS: Array<{ label: string; hex: string }> = [
  {
    label: 'Prologue: push rbp; mov rbp,rsp',
    hex: '55 48 89 e5',
  },
  {
    label: 'mov rax, imm64',
    hex: '48 b8 48 47 46 45 44 43 42 41',
  },
  {
    label: 'SIB: mov qword [rsp+8], rcx',
    hex: '48 89 4c 24 08',
  },
  {
    label: 'Linux write+exit syscalls',
    hex: [
      '48 c7 c0 01 00 00 00', // mov rax, 1 (SYS_WRITE)
      '48 c7 c7 01 00 00 00', // mov rdi, 1 (stdout)
      '48 8d 35 00 00 00 00', // lea rsi, [rip+0]
      '48 c7 c2 0d 00 00 00', // mov rdx, 13
      '0f 05', // syscall
      '48 c7 c0 3c 00 00 00', // mov rax, 60 (SYS_EXIT)
      '48 31 ff', // xor rdi, rdi
      '0f 05', // syscall
    ].join(' '),
  },
];

app.innerHTML = `
  <div class="topbar">
    <div class="brand">disasm<span class="dot">-</span>forge</div>
    <nav>
      <a href="https://github.com/Robert-Doe/disasm-forge" target="_blank" rel="noopener">GitHub</a>
      <a href="https://robertdoe.com">← robertdoe.com</a>
    </nav>
  </div>

  <div class="hero">
    <div class="pill">real REX / ModRM / SIB decoding — not a mockup</div>
    <h1>Disasm Forge <span class="accent">—</span> Mini x86-64 Disassembler</h1>
    <p class="tagline">Paste raw x86-64 machine code bytes and get real Intel-syntax disassembly, with a byte-by-byte breakdown of every REX bit, ModRM field, SIB field, displacement and immediate — a TypeScript port of this course's Module 21 capstone decoder (originally written in x86-64 assembly itself).</p>
  </div>

  <main class="demo">
    <div class="card">
      <h3>Input <span class="hint">hex bytes, any separator</span></h3>
      <div class="quickload" id="quickloads"></div>
      <label for="hex-input">Bytes</label>
      <textarea id="hex-input" rows="3" spellcheck="false" placeholder="e.g. 48 89 e5"></textarea>
      <div class="btn-row">
        <button class="primary" id="disasm-btn">Disassemble</button>
      </div>
    </div>

    <div class="two-pane">
      <div class="card" style="margin-bottom:0;">
        <h3>Disassembly <span class="hint">Intel syntax</span></h3>
        <div class="listing" id="listing"><div class="note">Paste bytes and click Disassemble.</div></div>
      </div>
      <div class="card" style="margin-bottom:0;">
        <h3>Byte breakdown <span class="hint">selected instruction</span></h3>
        <div class="breakdown" id="breakdown"><div class="note">Select a decoded instruction on the left.</div></div>
      </div>
    </div>

    <div class="card">
      <h3>Supported subset <span class="hint">module_21's own scope</span></h3>
      <div class="note">
        Single-byte no-operand: nop, ret, retf, leave, int3, hlt &middot;
        push/pop reg &middot; mov r64,imm64 &middot; push imm8/imm32 &middot;
        call/jmp rel32, jmp rel8, Jcc rel8/rel32 &middot;
        add/or/and/sub/xor/cmp (register and r/m,imm32 group 81) &middot;
        mov r/m64,r64 and reverse &middot; lea &middot; mov r/m64,imm32 &middot;
        test r/m64,r64 &middot; group F7 (test/not/neg/mul/div/idiv) &middot;
        group FF (inc/dec/call/jmp r/m) &middot; two-byte 0F: syscall, ud2,
        Jcc rel32, cmovcc, setcc, movzx, movsx, imul &middot; REX prefix
        decoding &middot; full ModRM incl. SIB (base/index*scale/disp) and
        RIP-relative addressing. Anything else decodes as <code class="inline">db 0xXX</code> and the byte is skipped — this
        was scoped to the instruction subset the module's own tutorial and
        capstone actually cover, not the full x86-64 ISA.
      </div>
    </div>
  </main>

  <footer>
    Ported from module_21/capstone/disasm.asm (Module 21 — Capstone: A Mini x86-64 Disassembler).
  </footer>
`;

const quickloadsEl = document.querySelector<HTMLDivElement>('#quickloads')!;
for (const q of QUICKLOADS) {
  const chip = document.createElement('button');
  chip.className = 'chip';
  chip.textContent = q.label;
  chip.addEventListener('click', () => {
    hexInput.value = q.hex;
    runDisassemble();
  });
  quickloadsEl.appendChild(chip);
}

const hexInput = document.querySelector<HTMLTextAreaElement>('#hex-input')!;
const disasmBtn = document.querySelector<HTMLButtonElement>('#disasm-btn')!;
const listingEl = document.querySelector<HTMLDivElement>('#listing')!;
const breakdownEl = document.querySelector<HTMLDivElement>('#breakdown')!;

let currentInstructions: DecodedInstruction[] = [];
let selectedIndex = -1;

function escapeHtml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function runDisassemble() {
  const bytes = parseHexBytes(hexInput.value);
  if (bytes.length === 0) {
    listingEl.innerHTML = '<div class="note">No valid hex bytes found.</div>';
    breakdownEl.innerHTML = '<div class="note">Select a decoded instruction on the left.</div>';
    currentInstructions = [];
    return;
  }
  const { instructions, totalBytes } = disassemble(bytes);
  currentInstructions = instructions;
  selectedIndex = instructions.length ? 0 : -1;

  listingEl.innerHTML = '';
  instructions.forEach((insn, i) => {
    const row = document.createElement('div');
    row.className = 'listing-row' + (i === selectedIndex ? ' selected' : '');
    const hexBytes = insn.bytes.map((b) => b.toString(16).padStart(2, '0')).join(' ');
    row.innerHTML = `<span class="off">${insn.offset.toString(16).padStart(4, '0')}:</span><span class="bytes">${hexBytes}</span><span></span>`;
    const mnemSpan = document.createElement('span');
    if (insn.isUnknown) {
      mnemSpan.innerHTML = `<span class="err">${escapeHtml(insn.text)}</span>`;
    } else {
      mnemSpan.innerHTML = `<span class="mnemonic">${escapeHtml(insn.mnemonic)}</span><span class="operands">${escapeHtml(insn.operands)}</span>`;
    }
    row.children[2].replaceWith(mnemSpan);
    row.addEventListener('click', () => {
      selectedIndex = i;
      renderListing();
      renderBreakdown(insn);
    });
    listingEl.appendChild(row);
  });

  if (totalBytes < bytes.length) {
    const warn = document.createElement('div');
    warn.className = 'note';
    warn.textContent = `Stopped after ${totalBytes} of ${bytes.length} bytes.`;
    listingEl.appendChild(warn);
  }

  if (instructions.length) renderBreakdown(instructions[0]);
}

function renderListing() {
  const rows = listingEl.querySelectorAll('.listing-row');
  rows.forEach((r, i) => r.classList.toggle('selected', i === selectedIndex));
}

const FIELD_LABEL: Record<FieldTag, string> = {
  prefix: 'REX',
  opcode: 'OP',
  modrm: 'ModRM',
  sib: 'SIB',
  disp: 'disp',
  imm: 'imm',
};

function bitfieldHtml(byte: number, highBits: number[]): string {
  let html = '<div class="bitfield">';
  for (let i = 7; i >= 0; i--) {
    const on = (byte >> i) & 1;
    const hi = highBits.includes(i) && on;
    html += `<div class="bit${hi ? ' hi' : ''}">${on}</div>`;
  }
  html += '</div>';
  return html;
}

function renderBreakdown(insn: DecodedInstruction) {
  let html = '';
  html += `<div class="summary-line"><span class="mnem">${escapeHtml(insn.mnemonic)}</span> ${escapeHtml(insn.operands)}</div>`;
  html += `<div class="note">offset 0x${insn.offset.toString(16)} · length ${insn.length} byte${insn.length === 1 ? '' : 's'}</div>`;

  html += '<div class="byte-strip">';
  for (const f of insn.fields) {
    html += `<div class="byte-chip ${f.field}"><span class="hex">${f.byte.toString(16).padStart(2, '0')}</span><span class="tag">${FIELD_LABEL[f.field]}</span></div>`;
  }
  html += '</div>';

  if (insn.rex) {
    html += `<div class="section-label">REX prefix — 0x${insn.rex.byte.toString(16).padStart(2, '0')}</div>`;
    html += bitfieldHtml(insn.rex.byte, [3, 2, 1, 0]);
    html += `<table class="field-table"><tr><th>W</th><th>R</th><th>X</th><th>B</th></tr>
      <tr><td>${insn.rex.W ? '1 (64-bit operand size)' : '0'}</td><td>${insn.rex.R ? '1 (extends ModRM.reg)' : '0'}</td><td>${insn.rex.X ? '1 (extends SIB.index)' : '0'}</td><td>${insn.rex.B ? '1 (extends ModRM.rm / opcode reg)' : '0'}</td></tr></table>`;
  }

  if (insn.modrm) {
    const m = insn.modrm;
    html += `<div class="section-label">ModRM — 0x${m.byte.toString(16).padStart(2, '0')}</div>`;
    html += bitfieldHtml(m.byte, [7, 6, 5, 4, 3, 2, 1, 0]);
    html += `<table class="field-table"><tr><th>mod</th><th>reg</th><th>rm</th></tr>
      <tr><td>${m.mod.toString(2).padStart(2, '0')} (${m.mod})</td><td>${m.reg.toString(2).padStart(3, '0')} (${m.reg})</td><td>${m.rm.toString(2).padStart(3, '0')} (${m.rm})</td></tr></table>`;
  }

  if (insn.sib) {
    const s = insn.sib;
    html += `<div class="section-label">SIB — 0x${s.byte.toString(16).padStart(2, '0')}</div>`;
    html += bitfieldHtml(s.byte, [7, 6, 5, 4, 3, 2, 1, 0]);
    html += `<table class="field-table"><tr><th>scale</th><th>index</th><th>base</th></tr>
      <tr><td>${s.scale.toString(2).padStart(2, '0')} (×${1 << s.scale})</td><td>${s.index.toString(2).padStart(3, '0')} (${s.index === 4 ? 'none' : s.index})</td><td>${s.base.toString(2).padStart(3, '0')} (${s.base})</td></tr></table>`;
  }

  if (insn.dispBytes.length) {
    html += `<div class="section-label">Displacement</div><div class="note">${insn.dispBytes.length} byte(s): ${insn.dispBytes.map((b) => '0x' + b.toString(16).padStart(2, '0')).join(' ')}</div>`;
  }

  if (insn.immBytes.length) {
    html += `<div class="section-label">Immediate</div><div class="note">${insn.immBytes.length} byte(s): ${insn.immBytes.map((b) => '0x' + b.toString(16).padStart(2, '0')).join(' ')}</div>`;
  }

  if (insn.isUnknown) {
    html += `<div class="section-label">Note</div><div class="note">Opcode 0x${insn.opcodeBytes[insn.opcodeBytes.length - 1].toString(16).padStart(2, '0')} is outside this decoder's supported subset — emitted as <code class="inline">db</code> and skipped, matching the original capstone's fallback behavior.</div>`;
  }

  breakdownEl.innerHTML = html;
}

disasmBtn.addEventListener('click', runDisassemble);
hexInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) runDisassemble();
});

// Load the first quickload by default so the page never looks empty.
hexInput.value = QUICKLOADS[0].hex;
runDisassemble();
