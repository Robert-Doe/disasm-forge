# disasm-forge webapp

An interactive demo: "Disasm Forge — Mini x86-64 Disassembler". This is a
TypeScript port of `module_21/capstone/disasm.asm` — the course's own
capstone, originally written in x86-64 assembly — decoding REX prefixes,
ModRM (mod/reg/rm), SIB (scale/index/base), displacements and immediates,
then formatting Intel-syntax mnemonics.

Paste raw hex bytes, get a real disassembly listing plus a full byte-by-byte
breakdown of every field for the selected instruction.

## Scope

Ported faithfully to the instruction subset `module_21` itself covers (see
its README/tutorial and `disasm.asm`'s own header comment) — not the full
x86-64 ISA. Anything outside that subset decodes as `db 0xXX` and is
skipped, exactly like the original. The decoder was verified against every
worked example and length-accuracy test case in `module_21/capstone/main.c`.

One deliberate improvement over the original: SIB addressing (`[base +
index*scale + disp]`) is decoded for real here, where the assembly's own
`decode_modrm` fell back to a hardcoded `"[rsp+sib]"` placeholder string
for that case (see the comment in `decoder.ts`). Every other quirk of the
original — including immediates/displacements always rendering as unsigned
zero-padded hex — is preserved intentionally.

## Local development

```bash
npm install
npm run dev
```

## Build

```bash
npm run build
```

Output goes to `dist/`.

## Deploying

Any static host works — this is a pure client-side Vite build.

- **Vercel / Netlify / Cloudflare Pages**: set the project root to `webapp`,
  build command to `npm run build`, output directory to `dist`.
