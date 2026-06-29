# Makefile — Module 14: ELF & PE Binary Formats
CC=gcc
CFLAGS=-Wall -Wextra -std=c11 -g

ifeq ($(OS),Windows_NT)
  ELF_EXE=
  PE_EXE=pe_reader.exe
  ALL_TARGETS=$(PE_EXE)
  NOTE=NOTE: elf_reader requires Linux (uses elf.h). Build pe_reader only on Windows.
else
  ELF_EXE=elf_reader
  PE_EXE=pe_reader
  ALL_TARGETS=$(ELF_EXE) $(PE_EXE)
  NOTE=Both elf_reader and pe_reader built.
endif

all: $(ALL_TARGETS)
	@echo "$(NOTE)"

elf_reader: elf_reader.c
	$(CC) $(CFLAGS) -o $@ $<

pe_reader: pe_reader.c
	$(CC) $(CFLAGS) -o $@ $<

pe_reader.exe: pe_reader.c
	$(CC) $(CFLAGS) -o $@ $<

# Demo: run elf_reader on itself (Linux only)
demo-elf: elf_reader
	./elf_reader ./elf_reader

# Demo: run pe_reader on a Windows exe (adjust path)
demo-pe: $(PE_EXE)
	./$(PE_EXE) /c/Windows/System32/ntdll.dll 2>/dev/null || \
	echo "Pass a .exe or .dll path as argument: ./pe_reader <file>"

clean:
	rm -f elf_reader pe_reader pe_reader.exe
.PHONY: all demo-elf demo-pe clean
