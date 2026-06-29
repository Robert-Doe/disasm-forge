# =============================================================================
# Makefile — Module 01: Toolchain Setup & Hello World
# Works on: Linux x86-64 and Windows (MSYS2 / MinGW-w64)
# =============================================================================

CC    = gcc
NASM  = nasm
CFLAGS = -Wall -Wextra -std=c11 -g

# ── Platform detection ────────────────────────────────────────────────────────
ifeq ($(OS),Windows_NT)
    FORMAT  = win64
    EXE     = hello.exe
    LDFLAGS =
else
    FORMAT  = elf64
    EXE     = hello
    LDFLAGS = -no-pie
endif

# ── Default target ────────────────────────────────────────────────────────────
all: $(EXE)

$(EXE): hello.o print_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

hello.o: hello.asm
	$(NASM) -f $(FORMAT) -o $@ $<

print_helper.o: print_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<

# ── Cleanup ───────────────────────────────────────────────────────────────────
clean:
	rm -f *.o $(EXE)

.PHONY: all clean
