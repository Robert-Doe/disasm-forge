# Makefile — Module 06: Control Flow
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=control.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=control
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): control.o control_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
control.o: control.asm
	$(NASM) -f $(FORMAT) -o $@ $<
control_helper.o: control_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
