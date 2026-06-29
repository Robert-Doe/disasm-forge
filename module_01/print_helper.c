/* print_helper.c — Module 01
 * A tiny C helper so hello.asm can print without knowing platform ABI yet.
 * Modules 09+ will teach calling C functions directly from asm.
 */
#include <stdio.h>

void print_hello(void)
{
    puts("Hello, Assembly!");
}
