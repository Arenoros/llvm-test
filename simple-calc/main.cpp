// https://stackoverflow.com/questions/48850242/thread-safe-reentrant-bison-flex
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "calc.h"

int main(int argc, char* argv[]) {
    yyscan_t scanner;
    yylex_init(&scanner);

    do {
        switch (getopt(argc, argv, "sp")) {
        case -1:
            break;
        case 's':
            yyset_debug(1, scanner);
            continue;
        case 'p':
            yydebug = 1;
            continue;
        default:
            exit(1);
        }
        break;
    } while (1);
    yy_scan_string("2323+23\n", scanner);
    int rv = yyparse(scanner);

    yylex_destroy(scanner);
    return 0;
}
