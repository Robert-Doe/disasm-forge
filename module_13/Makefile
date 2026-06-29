# Makefile — Module 13: SIMD — SSE, AVX & Packed Data
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g -mavx -msse4.1
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  NASMFLAGS=-DWIN64
  EXE=simd.exe
  LDFLAGS=
else
  FORMAT=elf64
  NASMFLAGS=
  EXE=simd
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): simd.o simd_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
simd.o: simd.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<
simd_helper.o: simd_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
