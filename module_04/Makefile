# Makefile — Module 04: Arithmetic & the ALU
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=arith.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=arith
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): arith.o arith_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
arith.o: arith.asm
	$(NASM) -f $(FORMAT) -o $@ $<
arith_helper.o: arith_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
