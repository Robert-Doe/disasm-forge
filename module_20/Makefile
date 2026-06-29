# Makefile — Module 20: Bare-Metal Runtime
NASM=nasm
LD=ld
FORMAT=elf64

# All assembly source files
SRCS = runtime/start.asm \
       runtime/syscall_wrappers.asm \
       runtime/alloc.asm \
       runtime/io.asm

OBJS = $(SRCS:.asm=.o)

EXE = runtime_demo

all: $(EXE)
	@echo "Built bare-metal runtime (no libc): $(EXE)"
	@file $(EXE)

$(EXE): $(OBJS)
	$(LD) -o $@ $^

%.o: %.asm
	$(NASM) -f $(FORMAT) -o $@ $<

# Show the binary does not link against libc
check-no-libc: $(EXE)
	@echo "=== Dynamic dependencies (should be empty for bare-metal) ==="
	ldd $(EXE) || echo "(statically linked — no dynamic deps)"
	@echo ""
	@echo "=== Imported symbols (should be empty) ==="
	nm $(EXE) | grep ' U ' || echo "(no undefined symbols — pure assembly)"

# Show entry point
check-entry: $(EXE)
	readelf -h $(EXE) | grep "Entry point"
	objdump -d -M intel $(EXE) | grep -A5 "<_start>"

clean:
	rm -f runtime/*.o $(EXE)

.PHONY: all check-no-libc check-entry clean
