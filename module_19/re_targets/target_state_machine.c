/*
 * target_state_machine.c — Module 19: RE Target 3
 *
 * A finite state machine that processes a byte stream.
 * In disassembly, state machines appear as:
 *   - A central dispatch: switch/jump table OR cmp chain
 *   - State variable in a register or memory location
 *   - Transitions: mov [state], NEW_STATE or a direct jmp to next state
 *
 * This one parses a minimal subset of HTTP status lines:
 *   "HTTP/1.1 200 OK\r\n" → emits status code as integer
 *
 * Exercise: reconstruct the state transition diagram from the disassembly.
 * Identify each state as a named concept (LOOKING_FOR_SPACE, READING_CODE…).
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <ctype.h>

typedef enum {
    ST_VERSION = 0,
    ST_SPACE1,
    ST_CODE,
    ST_SPACE2,
    ST_PHRASE,
    ST_DONE,
    ST_ERROR
} State;

static int parse_status(const char *line, int *status_out, char *phrase_out) {
    State   state   = ST_VERSION;
    int     code    = 0;
    int     phrase_i = 0;
    phrase_out[0] = '\0';

    for (size_t i = 0; line[i] != '\0'; i++) {
        char c = line[i];
        switch (state) {
        case ST_VERSION:
            if (c == ' ') state = ST_SPACE1;
            break;
        case ST_SPACE1:
            if (isdigit((unsigned char)c)) {
                code  = c - '0';
                state = ST_CODE;
            } else { state = ST_ERROR; }
            break;
        case ST_CODE:
            if (isdigit((unsigned char)c)) {
                code = code * 10 + (c - '0');
            } else if (c == ' ') {
                state = ST_SPACE2;
            } else { state = ST_ERROR; }
            break;
        case ST_SPACE2:
            if (c != '\r' && c != '\n') {
                phrase_out[phrase_i++] = c;
                state = ST_PHRASE;
            } else { state = ST_DONE; }
            break;
        case ST_PHRASE:
            if (c == '\r' || c == '\n') {
                phrase_out[phrase_i] = '\0';
                state = ST_DONE;
            } else {
                phrase_out[phrase_i++] = c;
            }
            break;
        case ST_DONE:
        case ST_ERROR:
            goto done;
        }
    }
done:
    *status_out = code;
    return (state == ST_DONE || state == ST_PHRASE) ? 0 : -1;
}

int main(void) {
    const char *lines[] = {
        "HTTP/1.1 200 OK\r\n",
        "HTTP/1.1 404 Not Found\r\n",
        "HTTP/1.1 500 Internal Server Error\r\n",
        "INVALID INPUT\r\n",
        NULL
    };

    for (int i = 0; lines[i]; i++) {
        int  status = 0;
        char phrase[64] = {0};
        int  rc = parse_status(lines[i], &status, phrase);
        if (rc == 0)
            printf("Status: %d  Phrase: \"%s\"\n", status, phrase);
        else
            printf("Parse error for: %s", lines[i]);
    }

    return 0;
}
