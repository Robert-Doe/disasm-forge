/*
 * target_cipher.c — Module 19: RE Target 1
 *
 * A simple XOR cipher. Compiled stripped (-s) at -O2 so the disassembly
 * is optimized but has no symbol names. The student must reconstruct
 * what the function does from the assembly alone.
 *
 * Exercise: Disassemble the compiled binary, identify the loop structure,
 * the XOR operation, and the key schedule. Determine the key from the
 * disassembly without reading this source.
 *
 * Key insight for RE: look for:
 *   - A loop counter (dec + jnz OR sub+cmp+jne)
 *   - XOR of [rdi+rcx] with a constant or a rotating key byte
 *   - A modulo pattern (cmp+cmovge+sub or and with power-of-2 minus 1)
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

static const uint8_t KEY[] = { 0x41, 0x53, 0x4D, 0x21 };   /* "ASM!" */
#define KEY_LEN 4

/* XOR cipher: encrypt and decrypt are the same operation */
static void xor_cipher(uint8_t *data, size_t len) {
    for (size_t i = 0; i < len; i++) {
        data[i] ^= KEY[i % KEY_LEN];
    }
}

/* Checksum: sum all bytes, return mod 256 */
static uint8_t checksum(const uint8_t *data, size_t len) {
    uint8_t acc = 0;
    for (size_t i = 0; i < len; i++)
        acc += data[i];
    return acc;
}

int main(void) {
    uint8_t message[] = "Hello, Reverse Engineer!";
    size_t  len       = strlen((char *)message);

    printf("Original:  ");
    for (size_t i = 0; i < len; i++) printf("%02X ", message[i]);
    printf("\n");

    xor_cipher(message, len);
    printf("Encrypted: ");
    for (size_t i = 0; i < len; i++) printf("%02X ", message[i]);
    printf("\n");
    printf("Checksum:  %02X\n", checksum(message, len));

    xor_cipher(message, len);  /* decrypt — same XOR */
    printf("Decrypted: %s\n", (char *)message);

    return 0;
}
