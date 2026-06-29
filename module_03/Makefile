# Makefile — Module 03: Data Representation & Memory

CC     = gcc
NASM   = nasm
CFLAGS = -Wall -Wextra -std=c11 -g

ifeq ($(OS),Windows_NT)
    FORMAT  = win64
    EXE     = data_demo.exe
    LDFLAGS =
else
    FORMAT  = elf64
    EXE     = data_demo
    LDFLAGS = -no-pie
endif

all: $(EXE)

$(EXE): data.o data_demo.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

data.o: data.asm
	$(NASM) -f $(FORMAT) -o $@ $<

data_demo.o: data_demo.c
	$(CC) $(CFLAGS) -c -o $@ $<

clean:
	rm -f *.o $(EXE)

.PHONY: all clean
