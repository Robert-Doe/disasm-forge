# Makefile — Module 19: Reading Disassembly & Reverse Engineering Patterns
CC=gcc
STRIP=strip

# Stripped, optimized build — what the student disassembles
OPT_FLAGS=-O2 -std=c11
STRIP_FLAGS=-s

# Debug build for reference (with symbols)
DBG_FLAGS=-O0 -g -std=c11

all: targets-stripped targets-debug

# ── Stripped targets (the RE targets) ────────────────────────────────────────
targets-stripped: re_targets/cipher re_targets/recursive \
                  re_targets/state_machine re_targets/crackme

re_targets/cipher: re_targets/target_cipher.c
	$(CC) $(OPT_FLAGS) $(STRIP_FLAGS) -o $@ $<

re_targets/recursive: re_targets/target_recursive.c
	$(CC) $(OPT_FLAGS) $(STRIP_FLAGS) -o $@ $<

re_targets/state_machine: re_targets/target_state_machine.c
	$(CC) $(OPT_FLAGS) $(STRIP_FLAGS) -o $@ $<

re_targets/crackme: re_targets/target_crackme.c
	$(CC) $(OPT_FLAGS) $(STRIP_FLAGS) -o $@ $<

# ── Debug targets (for comparison after solving) ──────────────────────────────
targets-debug: re_targets/cipher.dbg re_targets/recursive.dbg \
               re_targets/state_machine.dbg re_targets/crackme.dbg

re_targets/cipher.dbg: re_targets/target_cipher.c
	$(CC) $(DBG_FLAGS) -o $@ $<

re_targets/recursive.dbg: re_targets/target_recursive.c
	$(CC) $(DBG_FLAGS) -o $@ $<

re_targets/state_machine.dbg: re_targets/target_state_machine.c
	$(CC) $(DBG_FLAGS) -o $@ $<

re_targets/crackme.dbg: re_targets/target_crackme.c
	$(CC) $(DBG_FLAGS) -o $@ $<

# ── Disassembly helpers ───────────────────────────────────────────────────────
# Generate annotated disassembly for each target
disasm-cipher:
	objdump -d -M intel re_targets/cipher

disasm-recursive:
	objdump -d -M intel re_targets/recursive

disasm-state:
	objdump -d -M intel re_targets/state_machine

disasm-crackme:
	objdump -d -M intel re_targets/crackme

# Compare stripped vs debug symbol table
syms-compare:
	@echo "=== Stripped cipher symbols ==="
	nm re_targets/cipher 2>/dev/null || echo "(stripped — no symbols)"
	@echo ""
	@echo "=== Debug cipher symbols ==="
	nm re_targets/cipher.dbg | grep -v ' U '

# Run targets to see expected output
run-all: targets-stripped
	@echo "=== cipher ==="
	./re_targets/cipher
	@echo ""
	@echo "=== recursive ==="
	./re_targets/recursive
	@echo ""
	@echo "=== state_machine ==="
	./re_targets/state_machine

clean:
	rm -f re_targets/cipher re_targets/recursive \
	      re_targets/state_machine re_targets/crackme \
	      re_targets/*.dbg

.PHONY: all targets-stripped targets-debug disasm-cipher disasm-recursive \
        disasm-state disasm-crackme syms-compare run-all clean
