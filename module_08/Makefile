# Makefile — Module 08: Procedures, Recursion & the Red Zone
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  EXE=procs.exe
  LDFLAGS=
else
  FORMAT=elf64
  EXE=procs
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): procs.o procs_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
procs.o: procs.asm
	$(NASM) -f $(FORMAT) -o $@ $<
procs_helper.o: procs_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
