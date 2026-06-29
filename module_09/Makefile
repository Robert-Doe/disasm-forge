# Makefile — Module 09: Calling Conventions & the ABI
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g

ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=abi.exe
  LDFLAGS=
  NASMFLAGS=-DWIN64
else
  FORMAT=elf64
  EXE=abi
  LDFLAGS=-no-pie
  NASMFLAGS=
endif

all: $(EXE)

$(EXE): abi.o abi_caller.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

abi.o: abi.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<

abi_caller.o: abi_caller.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o $(EXE)

.PHONY: all clean
