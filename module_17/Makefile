# Makefile — Module 17: Inline Assembly & Reading Compiler Output
CC=gcc
CFLAGS=-Wall -Wextra -std=c11 -g
OPT_CFLAGS=-O2 -std=c11

ifeq ($(OS),Windows_NT)
  EXE=inline_asm.exe
else
  EXE=inline_asm
endif

all: $(EXE)

$(EXE): inline_asm.c
	$(CC) $(CFLAGS) -o $@ $<

# Generate optimized assembly for comparison study
asm-O0: inline_asm.c
	$(CC) -O0 -S -fverbose-asm -o inline_asm_O0.s $<
	@echo "Written: inline_asm_O0.s"

asm-O2: inline_asm.c
	$(CC) -O2 -S -fverbose-asm -o inline_asm_O2.s $<
	@echo "Written: inline_asm_O2.s"

# Show specific function assembly side-by-side
compare: asm-O0 asm-O2
	@echo "=== multiply_by_5 at -O0 ==="
	@grep -A 15 "multiply_by_5:" inline_asm_O0.s | head -20
	@echo ""
	@echo "=== multiply_by_5 at -O2 ==="
	@grep -A 10 "multiply_by_5:" inline_asm_O2.s | head -15

clean:
	rm -f $(EXE) *.s *.o
.PHONY: all asm-O0 asm-O2 compare clean
