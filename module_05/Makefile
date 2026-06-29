# Makefile — Module 05: Bitwise Operations
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g -mpopcnt
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=bits.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=bits
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): bits.o bits_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
bits.o: bits.asm
	$(NASM) -f $(FORMAT) -o $@ $<
bits_helper.o: bits_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
