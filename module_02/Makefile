# =============================================================================
# Makefile — Module 02: Registers
# =============================================================================

CC     = gcc
NASM   = nasm
CFLAGS = -Wall -Wextra -std=c11 -g

ifeq ($(OS),Windows_NT)
    FORMAT  = win64
    EXE     = registers.exe
    LDFLAGS =
else
    FORMAT  = elf64
    EXE     = registers
    LDFLAGS = -no-pie
endif

all: $(EXE)

$(EXE): registers.o print_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

registers.o: registers.asm
	$(NASM) -f $(FORMAT) -o $@ $<

print_helper.o: print_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o $(EXE)

.PHONY: all clean
