# Makefile — Module 07: The Call Stack
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=stack.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=stack
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): stack.o stack_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
stack.o: stack.asm
	$(NASM) -f $(FORMAT) -o $@ $<
stack_helper.o: stack_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
