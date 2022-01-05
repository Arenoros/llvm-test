#include <errno.h>
#include <string.h>
#include <iostream>
#include "parser.h"
#include "parser_priv.h"

int main() {
    yyscan_t scanner;
    yylex_init(&scanner);
    FILE* fin = nullptr;
    auto err = fopen_s(&fin, "test2.txt", "r");
    if (err) {
        char errmsg[255] = {0};
        strerror_s(errmsg, 254, err);
        std::cerr << errmsg << std::endl;
        return 1;
    }
    yyset_in(fin, scanner);

    parser_t parser;
    //yyset_extra(&parser, scanner);
    //parser_t* test = (parser_t*)yyget_extra(scanner);

    int rv = yyparse(scanner, &parser);

    yylex_destroy(scanner);
    return 0;
}

void yyerror(YYLTYPE* locp, yyscan_t scanner, parser_t* parser, const char* msg) {}
