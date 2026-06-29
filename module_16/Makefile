# Makefile — Module 16: Linker & Loader Internals
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g

ifeq ($(OS),Windows_NT)
  FORMAT=win64
  NASMFLAGS=-DWIN64
  EXE=link_demo.exe
  LDFLAGS=
else
  FORMAT=elf64
  NASMFLAGS=
  EXE=link_demo
  LDFLAGS=-no-pie
endif

all: $(EXE)

# Link all three objects into one binary
$(EXE): a.o b.o link_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

a.o: a.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<

b.o: b.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<

link_helper.o: link_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Show relocations in object files before linking (Linux only)
relocs:
	@echo "=== Relocations in a.o ==="
	objdump -r a.o
	@echo ""
	@echo "=== Relocations in b.o ==="
	objdump -r b.o

# Show symbol table of final binary
syms:
	nm -n $(EXE) | grep -E "(a_multiply|b_add|b_counter|a_message)"

clean:
	rm -f *.o $(EXE)

.PHONY: all relocs syms clean
