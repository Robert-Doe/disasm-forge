/*
 * target_crackme.c — Module 19: RE Target 4 (Crackme)
 *
 * A license-key validator compiled stripped at -O2.
 * The student must find the valid key by reading disassembly only.
 *
 * The validation algorithm (do not read until after solving):
 *   1. Key must be exactly 16 characters
 *   2. Characters at indices 0,4,8,12 must be uppercase letters (A-Z)
 *   3. Sum of all 16 character values must equal 0x500 (1280)
 *   4. Key[0] XOR Key[8] must equal 0x1F
 *   5. Key[4] XOR Key[12] must equal 0x0A
 *
 * RE skills exercised:
 *   - Identifying length check (cmp + conditional jump)
 *   - Loop with modulo check (index & 3 == 0 pattern)
 *   - Sum accumulation loop
 *   - XOR comparisons with constants
 *   - Boolean AND of multiple conditions
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

static int validate_key(const char *key) {
    size_t len = strlen(key);

    /* Check 1: exact length */
    if (len != 16) return 0;

    /* Check 2: every 4th character must be uppercase A-Z */
    for (int i = 0; i < 16; i += 4) {
        if (key[i] < 'A' || key[i] > 'Z') return 0;
    }

    /* Check 3: sum of all bytes must be 0x500 */
    uint32_t sum = 0;
    for (int i = 0; i < 16; i++)
        sum += (uint8_t)key[i];
    if (sum != 0x500) return 0;

    /* Check 4: XOR of positions 0 and 8 */
    if ((key[0] ^ key[8]) != 0x1F) return 0;

    /* Check 5: XOR of positions 4 and 12 */
    if ((key[4] ^ key[12]) != 0x0A) return 0;

    return 1;  /* valid */
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <license-key>\n", argv[0]);
        printf("Find the valid 16-character key by reading the disassembly.\n");
        return 1;
    }

    if (validate_key(argv[1])) {
        printf("VALID KEY! Access granted.\n");
        return 0;
    } else {
        printf("INVALID KEY.\n");
        return 1;
    }
}
