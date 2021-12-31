#include <fstream>

#include "lexer.flex.cpp"

int main(int /* argc */, char** /* argv */) {
    yyscan_t scanner;
    yylex_init(&scanner);
    auto res = yy_scan_string("12312312sdsad312", scanner);
    yylex(scanner);
    yylex_destroy(scanner);

    return 0;
}