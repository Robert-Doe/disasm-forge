# DECISIONS.md — Module 21: Capstone Mini Disassembler

## Decision 1: Implement a length-disassembler, not a full symbolic disassembler

**Decision:** The disassembler identifies instruction length, opcode, and primary operand type. It does NOT resolve symbols, compute effective addresses at runtime, or follow call graphs.

**Why:** Length-disassembly is the hard part of disassembly and the part that requires deep understanding of the x86-64 encoding. A full symbolic disassembler like objdump requires access to the symbol table (ELF or PE), relocation entries, and a control-flow graph — all of which require linking the disassembler to an object file parser (Module 14's territory). The length-disassembler is a self-contained assembly exercise.

**Trade-off:** Students who want a full disassembler should build on this core and add the symbol table resolver from Module 14.

## Decision 2: ModRM/SIB decoding in a shared `decode_modrm` subroutine

**Decision:** The ModRM byte decoder (`decode_modrm`) is factored into a standalone function called by every instruction that has a r/m operand.

**Why:** ModRM appears in dozens of opcodes. Duplicating the mod/reg/rm extraction and displacement logic for each instruction handler would be hundreds of lines of nearly identical code. The shared subroutine also makes the SIB and displacement logic auditable in one place — critical for a security course where correctness matters.

**Trade-off:** The calling convention for `decode_modrm` is slightly unusual (passes `offset` in rcx rather than on the stack) to avoid conflicts with the System V ABI's rcx being clobbered by syscall. This is documented in comments.

## Decision 3: Fallback to `db 0xXX` for unknown opcodes

**Decision:** Unknown opcodes are emitted as `db 0xXX` with length 1, allowing the disassembler to advance byte-by-byte and continue decoding the rest of the stream.

**Why:** A disassembler that stops at the first unknown byte is useless for analyzing real-world shellcode or compiler output, both of which may contain unusual encodings or data interleaved with code. The byte-at-a-time fallback mirrors how real disassemblers (capstone, objdump) handle gaps.

**Trade-off:** Byte-at-a-time advancement can cause the disassembler to lose sync on a misaligned stream. A production disassembler uses control-flow analysis to re-sync. That is a graduate-level topic beyond this module's scope.

## Decision 4: C driver + assembly core (not a standalone assembly binary)

**Decision:** `main.c` provides the test harness, formatted output, and test cases. `disasm.asm` provides the decode and sprint functions. They are linked with gcc.

**Why:** Keeping the driver in C makes it easy to write test cases and compare against expected results without manually computing everything in assembly. The assembly is what matters for the learning objective; the scaffolding should be in the easiest language for the task. This also demonstrates the mixed C/assembly interop pattern from Module 17.

**Trade-off:** A production security tool would likely use the disassembler as a library (which this structure already supports via `disasm.h`).
