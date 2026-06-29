/*
 * pe_reader.c — Module 14: PE Binary Format (Windows)
 *
 * Reads a PE32+ (64-bit) binary and prints:
 *   - DOS header (MZ magic, e_lfanew pointer to PE header)
 *   - PE signature + COFF header (machine, sections, timestamp)
 *   - Optional Header (magic, entry point, image base, section alignment)
 *   - All section headers (name, VA, raw offset, raw size, characteristics)
 *   - Data directory entries (Export, Import, Resource, TLS, etc.)
 *
 * Usage: ./pe_reader <pe-file>
 * Compiles on Linux: gcc -o pe_reader pe_reader.c
 * Compiles on Windows (MSYS2): gcc -o pe_reader.exe pe_reader.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* ── PE structure definitions (portable — no windows.h required) ─────────── */

#pragma pack(push, 1)

typedef struct {
    uint16_t e_magic;       /* 0x5A4D "MZ" */
    uint8_t  _pad[58];
    uint32_t e_lfanew;      /* offset to PE header */
} DOS_Header;

typedef struct {
    uint32_t Signature;     /* 0x00004550 "PE\0\0" */
    uint16_t Machine;
    uint16_t NumberOfSections;
    uint32_t TimeDateStamp;
    uint32_t PointerToSymbolTable;
    uint32_t NumberOfSymbols;
    uint16_t SizeOfOptionalHeader;
    uint16_t Characteristics;
} COFF_Header;

typedef struct {
    uint16_t Magic;         /* 0x010B=PE32, 0x020B=PE32+ */
    uint8_t  MajorLinkerVersion;
    uint8_t  MinorLinkerVersion;
    uint32_t SizeOfCode;
    uint32_t SizeOfInitializedData;
    uint32_t SizeOfUninitializedData;
    uint32_t AddressOfEntryPoint;
    uint32_t BaseOfCode;
} Optional_Header_Common;

typedef struct {
    uint64_t ImageBase;
    uint32_t SectionAlignment;
    uint32_t FileAlignment;
    uint16_t MajorOperatingSystemVersion;
    uint16_t MinorOperatingSystemVersion;
    uint16_t MajorImageVersion;
    uint16_t MinorImageVersion;
    uint16_t MajorSubsystemVersion;
    uint16_t MinorSubsystemVersion;
    uint32_t Win32VersionValue;
    uint32_t SizeOfImage;
    uint32_t SizeOfHeaders;
    uint32_t CheckSum;
    uint16_t Subsystem;
    uint16_t DllCharacteristics;
    uint64_t SizeOfStackReserve;
    uint64_t SizeOfStackCommit;
    uint64_t SizeOfHeapReserve;
    uint64_t SizeOfHeapCommit;
    uint32_t LoaderFlags;
    uint32_t NumberOfRvaAndSizes;
} Optional_Header_PE32plus;

typedef struct {
    uint32_t VirtualAddress;
    uint32_t Size;
} Data_Directory;

typedef struct {
    uint8_t  Name[8];
    uint32_t VirtualSize;
    uint32_t VirtualAddress;
    uint32_t SizeOfRawData;
    uint32_t PointerToRawData;
    uint32_t PointerToRelocations;
    uint32_t PointerToLinenumbers;
    uint16_t NumberOfRelocations;
    uint16_t NumberOfLinenumbers;
    uint32_t Characteristics;
} Section_Header;

#pragma pack(pop)

/* ── helpers ──────────────────────────────────────────────────────────────── */

static const char *machine_str(uint16_t m) {
    switch (m) {
        case 0x8664: return "AMD64 (x86-64)";
        case 0x014C: return "I386 (x86-32)";
        case 0xAA64: return "ARM64 (AArch64)";
        case 0x01C4: return "ARM Thumb-2";
        default:     return "Unknown";
    }
}

static const char *dd_name(int i) {
    static const char *names[] = {
        "Export Table", "Import Table", "Resource Table",
        "Exception Table", "Certificate Table", "Base Relocation Table",
        "Debug", "Architecture", "Global Ptr", "TLS Table",
        "Load Config Table", "Bound Import", "IAT",
        "Delay Import Descriptor", "CLR Runtime Header", "Reserved"
    };
    if (i < 16) return names[i];
    return "Unknown";
}

static void print_section_flags(uint32_t c) {
    if (c & 0x00000020) printf("  CODE ");
    if (c & 0x00000040) printf("  IDATA ");
    if (c & 0x00000080) printf("  UDATA ");
    if (c & 0x20000000) printf("  EXECUTE ");
    if (c & 0x40000000) printf("  READ ");
    if (c & 0x80000000) printf("  WRITE ");
}

/* ── main parsing ─────────────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <pe-file>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[1], "rb");
    if (!f) { perror("fopen"); return 1; }

    fseek(f, 0, SEEK_END);
    long fsize = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint8_t *buf = malloc((size_t)fsize);
    if (!buf) { perror("malloc"); fclose(f); return 1; }
    fread(buf, 1, (size_t)fsize, f);
    fclose(f);

    /* DOS Header */
    DOS_Header *dos = (DOS_Header *)buf;
    if (dos->e_magic != 0x5A4D) {
        fprintf(stderr, "Not a PE file (bad MZ magic)\n");
        free(buf); return 1;
    }

    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                     DOS HEADER                           ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  MZ Magic:    0x%04X\n", dos->e_magic);
    printf("  e_lfanew:    0x%X  (offset to PE signature)\n\n", dos->e_lfanew);

    uint8_t *pe_ptr = buf + dos->e_lfanew;
    COFF_Header *coff = (COFF_Header *)pe_ptr;
    if (coff->Signature != 0x00004550) {
        fprintf(stderr, "Bad PE signature at offset 0x%X\n", dos->e_lfanew);
        free(buf); return 1;
    }

    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                    COFF HEADER                           ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  PE Signature:     0x%08X ('PE\\0\\0')\n", coff->Signature);
    printf("  Machine:          0x%04X  %s\n", coff->Machine, machine_str(coff->Machine));
    printf("  Sections:         %u\n", coff->NumberOfSections);
    printf("  TimeDateStamp:    0x%08X\n", coff->TimeDateStamp);
    printf("  Characteristics:  0x%04X\n\n", coff->Characteristics);

    /* Optional Header (PE32+) */
    uint8_t *opt_ptr = (uint8_t *)(coff + 1);
    Optional_Header_Common  *ohc  = (Optional_Header_Common *)opt_ptr;
    Optional_Header_PE32plus *oh64 = (Optional_Header_PE32plus *)(opt_ptr + sizeof(Optional_Header_Common));
    Data_Directory *dd = (Data_Directory *)((uint8_t *)oh64 + sizeof(Optional_Header_PE32plus));

    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                  OPTIONAL HEADER (PE32+)                 ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  Magic:                0x%04X  %s\n", ohc->Magic,
           ohc->Magic == 0x020B ? "PE32+" : ohc->Magic == 0x010B ? "PE32" : "ROM");
    printf("  AddressOfEntryPoint:  0x%X  (RVA)\n", ohc->AddressOfEntryPoint);
    printf("  BaseOfCode:           0x%X\n", ohc->BaseOfCode);
    printf("  ImageBase:            0x%lX\n", (unsigned long)oh64->ImageBase);
    printf("  SectionAlignment:     0x%X\n", oh64->SectionAlignment);
    printf("  FileAlignment:        0x%X\n", oh64->FileAlignment);
    printf("  SizeOfImage:          0x%X\n", oh64->SizeOfImage);
    printf("  SizeOfHeaders:        0x%X\n", oh64->SizeOfHeaders);
    printf("  Subsystem:            %u\n", oh64->Subsystem);
    printf("  DllCharacteristics:   0x%04X\n\n", oh64->DllCharacteristics);

    /* Data Directories */
    printf("╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                   DATA DIRECTORIES                       ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    uint32_t ndd = oh64->NumberOfRvaAndSizes;
    if (ndd > 16) ndd = 16;
    for (uint32_t i = 0; i < ndd; i++) {
        if (dd[i].VirtualAddress != 0)
            printf("  [%2u] %-28s  RVA=0x%08X  Size=0x%X\n",
                   i, dd_name(i), dd[i].VirtualAddress, dd[i].Size);
    }

    /* Section Headers */
    Section_Header *sections = (Section_Header *)(opt_ptr + coff->SizeOfOptionalHeader);
    printf("\n╔═══════════════════════════════════════════════════════════╗\n");
    printf("║                   SECTION HEADERS                        ║\n");
    printf("╚═══════════════════════════════════════════════════════════╝\n");
    printf("  %-10s  %-10s  %-10s  %-12s  %-12s  %s\n",
           "Name", "VirtSize", "VirtAddr", "RawOffset", "RawSize", "Flags");
    printf("  %s\n", "-----------------------------------------------------------------------");

    for (int i = 0; i < coff->NumberOfSections; i++) {
        Section_Header *s = &sections[i];
        char name[9] = {0};
        memcpy(name, s->Name, 8);
        printf("  %-10s  0x%08X  0x%08X  0x%08X    0x%08X  ",
               name, s->VirtualSize, s->VirtualAddress,
               s->PointerToRawData, s->SizeOfRawData);
        print_section_flags(s->Characteristics);
        printf("\n");
    }

    free(buf);
    return 0;
}
