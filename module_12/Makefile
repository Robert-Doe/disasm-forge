# Makefile — Module 12: x87 FPU & SSE2 Scalar Floating Point
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g -msse2
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  NASMFLAGS=-DWIN64
  EXE=floats.exe
  LDFLAGS=
else
  FORMAT=elf64
  NASMFLAGS=
  EXE=floats
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): floats.o float_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
floats.o: floats.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<
float_helper.o: float_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
