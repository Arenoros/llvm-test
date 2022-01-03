#include <errno.h>
#include <string.h>
#include <iostream>
#include "parser.h"

int main() {
    yyscan_t scanner;
    yylex_init(&scanner);
    FILE* fin = nullptr;
    auto err = fopen_s(&fin, "test1.sl", "r+");
    if (err) {
        char errmsg[255] = {0};
        strerror_s(errmsg, 254, err);
        std::cerr << errmsg << std::endl;
        return 1;
    }
    yyset_in(fin, scanner);
    // yy_scan_string("2323+23\n", scanner);

    int rv = yyparse(scanner);

    yylex_destroy(scanner);
    return 0;
}