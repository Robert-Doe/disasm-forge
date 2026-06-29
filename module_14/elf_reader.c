/*
 * elf_reader.c — Module 14: ELF Binary Format
 *
 * Reads an ELF64 binary and prints:
 *   - ELF header fields (class, ABI, entry point, section/program headers)
 *   - All section headers with name, type, address, offset, size
 *   - All program (load) headers with type, vaddr, filesz, memsz, flags
 *   - Symbol table entries (if .symtab exists)
 *
 * Usage: ./elf_reader <elf-file>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <elf.h>   /* /usr/include/elf.h — standard on Linux */

/* ── helpers ──────────────────────────────────────────────────────────────── */

static const char *elf_class_str(uint8_t c) {
    switch (c) {
        case ELFCLASS32: return "ELF32";
        case ELFCLASS64: return "ELF64";
        default:         return "Unknown";
    }
}

static const char *elf_data_str(uint8_t d) {
    switch (d) {
        case ELFDATA2LSB: return "Little-endian (2's complement)";
        case ELFDATA2MSB: return "Big-endian (2's complement)";
        default:          return "Unknown";
    }
}

static const char *elf_type_str(uint16_t t) {
    switch (t) {
        case ET_NONE:   return "NONE";
        case ET_REL:    return "REL (relocatable)";
        case ET_EXEC:   return "EXEC (executable)";
        case ET_DYN:    return "DYN (shared object / PIE)";
        case ET_CORE:   return "CORE";
        default:        return "Unknown";
    }
}

static const char *sh_type_str(uint32_t t) {
    switch (t) {
        case SHT_NULL:     return "NULL";
        case SHT_PROGBITS: return "PROGBITS";
        case SHT_SYMTAB:   return "SYMTAB";
        case SHT_STRTAB:   return "STRTAB";
        case SHT_RELA:     return "RELA";
        case SHT_HASH:     return "HASH";
        case SHT_DYNAMIC:  return "DYNAMIC";
        case SHT_NOTE:     return "NOTE";
        case SHT_NOBITS:   return "NOBITS (.bss)";
        case SHT_REL:      return "REL";
        case SHT_DYNSYM:   return "DYNSYM";
        default:           return "OTHER";
    }
}

static const char *ph_type_str(uint32_t t) {
    switch (t) {
        case PT_NULL:    return "NULL";
        case PT_LOAD:    return "LOAD";
        case PT_DYNAMIC: return "DYNAMIC";
        case PT_INTERP:  return "INTERP";
        case PT_NOTE:    return "NOTE";
        case PT_PHDR:    return "PHDR";
        case PT_TLS:     return "TLS";
        case PT_GNU_STACK: return "GNU_STACK";
        case PT_GNU_RELRO: return "GNU_RELRO";
        default:         return "OTHER";
    }
}

static const char *sym_bind_str(uint8_t info) {
    switch (ELF64_ST_BIND(info)) {
        case STB_LOCAL:  return "LOCAL";
        case STB_GLOBAL: return "GLOBAL";
        case STB_WEAK:   return "WEAK";
        default:         return "OTHER";
    }
}

static const char *sym_type_str(uint8_t info) {
    switch (ELF64_ST_TYPE(info)) {
        case STT_NOTYPE:  return "NOTYPE";
        case STT_OBJECT:  return "OBJECT";
        case STT_FUNC:    return "FUNC";
        case STT_SECTION: return "SECTION";
        case STT_FILE:    return "FILE";
        default:          return "OTHER";
    }
}

/* ── main parsing ─────────────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <elf-file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("fopen"); return 1; }

    /* Read entire file into memory for easy pointer arithmetic */
    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc((size_t)fsize);
    if (!buf) { perror("malloc"); fclose(f); return 1; }
    if (fread(buf, 1, (size_t)fsize, f) != (size_t)fsize) {
        perror("fread"); free(buf); fclose(f); return 1;
    }
    fclose(f);

    /* Validate ELF magic: 0x7F 'E' 'L' 'F' */
    if (buf[0] != 0x7F || buf[1] != 'E' || buf[2] != 'L' || buf[3] != 'F') {
        fprintf(stderr, "Not an ELF file (bad magic bytes)\n");
        free(buf); return 1;
    }

    Elf64_Ehdr *ehdr = (Elf64_Ehdr *)buf;

    /* ── ELF Header ──────────────────────────────────────────────────────── */
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                     ELF HEADER                           ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  Magic:       %02X %02X %02X %02X\n",
           buf[0], buf[1], buf[2], buf[3]);
    printf("  Class:       %s\n",     elf_class_str(ehdr->e_ident[EI_CLASS]));
    printf("  Data:        %s\n",     elf_data_str(ehdr->e_ident[EI_DATA]));
    printf("  Version:     %u\n",     ehdr->e_ident[EI_VERSION]);
    printf("  OS/ABI:      %u\n",     ehdr->e_ident[EI_OSABI]);
    printf("  Type:        %s\n",     elf_type_str(ehdr->e_type));
    printf("  Machine:     0x%X\n",   ehdr->e_machine);
    printf("  Entry point: 0x%lX\n",  (unsigned long)ehdr->e_entry);
    printf("  PHoff:       0x%lX  (%u program headers, %u bytes each)\n",
           (unsigned long)ehdr->e_phoff, ehdr->e_phnum, ehdr->e_phentsize);
    printf("  SHoff:       0x%lX  (%u section headers, %u bytes each)\n",
           (unsigned long)ehdr->e_shoff, ehdr->e_shnum, ehdr->e_shentsize);
    printf("  SHstrndx:    %u  (section header string table index)\n\n",
           ehdr->e_shstrndx);

    /* ── Section Headers ─────────────────────────────────────────────────── */
    Elf64_Shdr *shdrs = (Elf64_Shdr *)(buf + ehdr->e_shoff);
    /* The section name string table section */
    char *shstrtab = (char *)(buf + shdrs[ehdr->e_shstrndx].sh_offset);

    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                   SECTION HEADERS                        ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  %-4s  %-20s  %-12s  %-18s  %-10s  %-10s\n",
           "IDX", "Name", "Type", "Address", "Offset", "Size");
    printf("  %s\n", "-----------------------------------------------------------------------");

    int symtab_idx  = -1;  /* index of .symtab section */
    int strtab_idx  = -1;  /* index of .strtab section */

    for (int i = 0; i < ehdr->e_shnum; i++) {
        Elf64_Shdr *sh = &shdrs[i];
        const char *name = (sh->sh_name) ? shstrtab + sh->sh_name : "";
        printf("  %-4d  %-20s  %-12s  0x%016lX  0x%-8lX  %-10lu\n",
               i, name, sh_type_str(sh->sh_type),
               (unsigned long)sh->sh_addr,
               (unsigned long)sh->sh_offset,
               (unsigned long)sh->sh_size);
        if (sh->sh_type == SHT_SYMTAB) symtab_idx = i;
        if (strcmp(name, ".strtab") == 0) strtab_idx = i;
    }

    /* ── Program Headers ─────────────────────────────────────────────────── */
    printf("\n╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                  PROGRAM (LOAD) HEADERS                  ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  %-14s  %-18s  %-12s  %-12s  %-6s  %s\n",
           "Type", "VirtAddr", "FileSize", "MemSize", "Flags", "Align");
    printf("  %s\n", "-----------------------------------------------------------------------");

    Elf64_Phdr *phdrs = (Elf64_Phdr *)(buf + ehdr->e_phoff);
    for (int i = 0; i < ehdr->e_phnum; i++) {
        Elf64_Phdr *ph = &phdrs[i];
        char flags[4] = "---";
        if (ph->p_flags & PF_R) flags[0] = 'R';
        if (ph->p_flags & PF_W) flags[1] = 'W';
        if (ph->p_flags & PF_X) flags[2] = 'X';
        printf("  %-14s  0x%016lX  %-12lu  %-12lu  %s     %lu\n",
               ph_type_str(ph->p_type),
               (unsigned long)ph->p_vaddr,
               (unsigned long)ph->p_filesz,
               (unsigned long)ph->p_memsz,
               flags,
               (unsigned long)ph->p_align);
    }

    /* ── Symbol Table ────────────────────────────────────────────────────── */
    if (symtab_idx >= 0 && strtab_idx >= 0) {
        Elf64_Shdr *sym_sh  = &shdrs[symtab_idx];
        Elf64_Shdr *str_sh  = &shdrs[strtab_idx];
        Elf64_Sym  *syms    = (Elf64_Sym *)(buf + sym_sh->sh_offset);
        char       *strtab  = (char *)(buf + str_sh->sh_offset);
        int         nsyms   = (int)(sym_sh->sh_size / sizeof(Elf64_Sym));

        printf("\n╔═══════════════════════════════════════════════════════════╗\n");
        printf("║                    SYMBOL TABLE                          ║\n");
        printf("╚═══════════════════════════════════════════════════════════╝\n");
        printf("  %-4s  %-24s  %-18s  %-8s  %-8s  %s\n",
               "IDX", "Name", "Value", "Bind", "Type", "Size");
        printf("  %s\n", "-----------------------------------------------------------------------");

        for (int i = 0; i < nsyms; i++) {
            Elf64_Sym *s = &syms[i];
            const char *name = (s->st_name) ? strtab + s->st_name : "(none)";
            printf("  %-4d  %-24s  0x%016lX  %-8s  %-8s  %lu\n",
                   i, name,
                   (unsigned long)s->st_value,
                   sym_bind_str(s->st_info),
                   sym_type_str(s->st_info),
                   (unsigned long)s->st_size);
        }
    }

    free(buf);
    return 0;
}
