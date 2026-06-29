# Makefile — Module 18: Stack Exploitation & Mitigations
CC=gcc
NASM=nasm

# ── Vulnerable build (all protections disabled) ──────────────────────────────
# Educational only. Never deploy this.
VULN_FLAGS = -Wall -g -std=c11 \
             -fno-stack-protector \
             -no-pie \
             -z execstack \
             -D_FORTIFY_SOURCE=0

# ── Protected build (all protections enabled) ────────────────────────────────
SAFE_FLAGS = -Wall -g -std=c11 \
             -fstack-protector-strong \
             -pie \
             -D_FORTIFY_SOURCE=2

all: vuln-unsafe vuln-safe exploit

# Vulnerable binary: no canary, no pie, no NX
vuln-unsafe: exploit/vuln.c
	$(CC) $(VULN_FLAGS) -o $@ $<
	@echo "[!] Built vuln-unsafe with ALL protections DISABLED"

# Protected binary: canary + pie + fortify
vuln-safe: exploit/vuln.c
	$(CC) $(SAFE_FLAGS) -o $@ $<
	@echo "[+] Built vuln-safe with protections ENABLED"

# Exploit payload builder (Linux only, uses syscalls)
exploit: exploit/exploit.asm
	$(NASM) -f elf64 -o exploit/exploit.o exploit/exploit.asm
	ld -o exploit exploit/exploit.o
	@echo "[*] Built exploit (payload builder)"

# Generate assembly to see canary insertion
asm-canary: exploit/vuln.c
	$(CC) -O0 -fstack-protector-strong -S -fverbose-asm \
	      -o exploit/vuln_canary.s exploit/vuln.c
	@echo "Canary pattern in exploit/vuln_canary.s:"
	@grep -A3 "fs:0x28" exploit/vuln_canary.s || true

# Run the vulnerable binary and show stack layout
demo: vuln-unsafe
	./vuln-unsafe

# Disable ASLR for the demo (Linux only, requires sudo)
disable-aslr:
	sudo sysctl -w kernel.randomize_va_space=0
	@echo "ASLR disabled — run 'make enable-aslr' to restore"

enable-aslr:
	sudo sysctl -w kernel.randomize_va_space=2
	@echo "ASLR restored"

clean:
	rm -f vuln-unsafe vuln-safe exploit exploit/exploit.o exploit/*.s
.PHONY: all demo asm-canary disable-aslr enable-aslr clean
