# Makefile — Module 15: System Calls & Direct OS Interaction
NASM=nasm
CC=gcc

ifeq ($(OS),Windows_NT)
  # Windows: build win_api.asm only (no elf.h, no Linux syscalls)
  all: win_api.exe
  win_api.exe: win_api.asm
	$(NASM) -f win64 -o win_api.obj win_api.asm
	$(CC) -o win_api.exe win_api.obj
  clean:
	rm -f *.obj win_api.exe
else
  # Linux: build syscalls (standalone, no libc) and also win_api is skipped
  all: syscalls
  syscalls: syscalls.asm
	$(NASM) -f elf64 -o syscalls.o syscalls.asm
	ld -o syscalls syscalls.o
  clean:
	rm -f *.o syscalls
endif

.PHONY: all clean
