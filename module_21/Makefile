# Makefile — Module 21: Capstone Mini Disassembler
# Builds the assembly disassembler core + C test driver.
# Linux only (uses ELF64 object format and Linux ABI).

NASM     = nasm
CC       = gcc
LD       = gcc

NASMFLAGS = -f elf64 -g -F dwarf
CFLAGS    = -O0 -g -Wall -Wextra -Icapstone
LDFLAGS   =

EXE = disasm_test

OBJS = capstone/disasm.o capstone/main.o

all: $(EXE)
	@echo "Built: $(EXE)"
	@echo "Run:   ./$(EXE)"

$(EXE): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

capstone/disasm.o: capstone/disasm.asm
	$(NASM) $(NASMFLAGS) -o $@ $<

capstone/main.o: capstone/main.c capstone/disasm.h
	$(CC) $(CFLAGS) -c -o $@ $<

# Disassemble the disassembler itself (meta!)
meta: $(EXE)
	objdump -d -M intel capstone/disasm.o | head -120

# Show symbol table
syms: capstone/disasm.o
	nm capstone/disasm.o

# Run with valgrind to check for memory errors (optional)
valgrind: $(EXE)
	valgrind --error-exitcode=1 ./$(EXE)

clean:
	rm -f capstone/*.o $(EXE)

.PHONY: all meta syms valgrind clean
