# DECISIONS.md — Module 18: Stack Exploitation & Mitigations

## Decision 1: Target secret_function (ret2func) not injected shellcode

**Decision:** The overflow redirects to `secret_function()`, an existing function in the binary, not to injected shellcode bytes.
**Why:** Return-to-existing-function (ret2func / ret2win) is the clearest demonstration of control-flow hijacking at the assembly level: the return address is overwritten with the address of a function that already exists, so no shellcode injection or NX bypass is required. This isolates the buffer overflow mechanism from the shellcode injection mechanism, letting students understand one concept at a time. Module 15 already showed how code can be placed in executable memory; this module focuses on the return address overwrite primitive.

## Decision 2: Include gen_payload.py alongside exploit.asm

**Decision:** Both an assembly payload builder (exploit.asm) and a Python payload generator (gen_payload.py) are provided.
**Why:** The assembly version shows the payload structure at the byte level — how the 72 bytes are constructed, why the address is stored in little-endian order, why null bytes break strcpy. The Python version is more practical for real exploitation scripts. Having both demonstrates that payload construction is just byte manipulation, not magic.

## Decision 3: Show four separate Makefile targets (unsafe/safe/canary/NX)

**Decision:** The Makefile provides `vuln-unsafe` (all protections off) and `vuln-safe` (all on), plus a `make asm-canary` target to generate disassembly showing the canary instructions.
**Why:** The pedagogical goal is to understand what each mitigation does at the instruction level. Seeing the same C function compiled with and without `-fstack-protector-strong` and diffing the assembly output makes the canary mechanism concrete. Students should be able to point to the exact `xor rax, QWORD PTR fs:0x28; jne __stack_chk_fail` sequence in the disassembly.

## Decision 4: Document null-byte limitation in gen_payload.py

**Decision:** gen_payload.py explicitly warns when the target address contains a null byte and explains why strcpy truncates.
**Why:** The null-byte limitation of string-based overflows is one of the first real-world constraints a security student encounters. Understanding it leads naturally to: (a) choosing exploit primitives that are not null-terminated (read, memcpy, recv), (b) finding alternative targets whose addresses don't contain null bytes, and (c) encoding techniques to avoid null bytes in shellcode. Documenting it in the tool teaches the constraint at the moment it becomes relevant.
