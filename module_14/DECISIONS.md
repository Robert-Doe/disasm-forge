# DECISIONS.md — Module 14: ELF & PE Binary Formats

## Decision 1: Read entire file into memory, use pointer arithmetic

**Decision:** Both readers `malloc` a buffer the size of the file, `fread` everything in, then cast `uint8_t *` pointers to struct types to walk the format.
**Why:** This is how real tools work (readelf, objdump, IDA, Binary Ninja). The alternative — sequential `fread` calls per struct — forces artificial sequencing that hides the random-access nature of binary formats. Seeing that `Elf64_Ehdr *ehdr = (Elf64_Ehdr *)buf` followed by `Elf64_Shdr *shdrs = (Elf64_Shdr *)(buf + ehdr->e_shoff)` directly mirrors how linkers and loaders navigate the format.
**Trade-off:** This approach is unsafe on untrusted input — a malformed binary could have e_shoff pointing past the buffer. For a security professional the lesson is clear: any production parser must bounds-check every offset before dereferencing. The readers here omit bounds checks for clarity; adding them is left as an exercise.

## Decision 2: Use <elf.h> for ELF, hand-define structs for PE

**Decision:** elf_reader.c uses the system `<elf.h>` header. pe_reader.c defines its own structs without `<windows.h>`.
**Why:** `<elf.h>` is present on every Linux system and provides the authoritative struct definitions. `<windows.h>` is not available on Linux (where most security research happens) and carries enormous complexity. Defining the essential PE structs manually teaches the reader what is actually in the file versus the Windows API abstraction.
**Trade-off:** pe_reader.c uses `#pragma pack(push, 1)` to suppress padding — a portability assumption. On x86-64 Linux/Windows this is always correct for these structs.

## Decision 3: Print Data Directory entries only when non-zero

**Decision:** Only data directories with a non-zero RVA are printed.
**Why:** All PE files define 16 data directory slots but most are empty (RVA=0, Size=0). Printing all 16 clutters the output with unused entries. Filtering to non-zero entries highlights what is actually present in the binary — the exact information a security analyst wants first.

## Decision 4: Include both ELF and PE in the same module

**Decision:** Module 14 covers both binary formats rather than splitting into two modules.
**Why:** The contrast between formats is the lesson. ELF section headers describe the binary as the linker sees it (named sections with attributes). PE section headers serve the same purpose but have different alignment fields and flag bits. Program headers (ELF) vs Data Directories (PE) are both mechanisms for the OS loader to find critical tables, but structured differently. Seeing both side-by-side makes the design decisions of each format intelligible.
