# Makefile — Module 11: String & Array Operations
CC=gcc
NASM=nasm
CFLAGS=-Wall -Wextra -std=c11 -g
ifeq ($(OS),Windows_NT)
  FORMAT=win64
  NASMFLAGS=-DWIN64
  EXE=strings.exe
  LDFLAGS=
else
  FORMAT=elf64
  NASMFLAGS=
  EXE=strings
  LDFLAGS=-no-pie
endif
all: $(EXE)
$(EXE): strings.o str_helper.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^
strings.o: strings.asm
	$(NASM) -f $(FORMAT) $(NASMFLAGS) -o $@ $<
str_helper.o: str_helper.c
	$(CC) $(CFLAGS) -c -o $@ $<
clean:
	rm -f *.o $(EXE)
.PHONY: all clean
