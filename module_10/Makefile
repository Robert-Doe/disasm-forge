# Makefile — Module 10: Memory Addressing Modes
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=addressing.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=addressing
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): addressing.o addr_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
addressing.o: addressing.asm
	$(NASM) -f $(FORMAT) -o $@ $<
addr_helper.o: addr_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
