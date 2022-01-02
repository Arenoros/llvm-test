#define _CRT_SECURE_NO_WARNINGS
#include <fstream>

#include "gram.h"


int main(int argc, char* argv[]) {
    yyscan_t scanner;
    yylex_init(&scanner);/*
    std::ifstream code("test1.ls");*/
    FILE* fin = fopen("test1.sl", "r");
    yyset_in(fin, scanner);
    //yy_scan_string("2323+23\n", scanner);
    oper_t* block;
    int rv = yyparse(scanner, &block);

    yylex_destroy(scanner);
    return 0;
}
