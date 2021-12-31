%{
#include <iostream>
#include "parser.tab.h"
#define YY_USER_ACTION                                               \
    yylloc->first_line = yylloc->last_line;                          \
    yylloc->first_column = yylloc->last_column;                      \
    if (yylloc->last_line == yylineno)                               \
      yylloc->last_column += yyleng;                                 \
    else {                                                           \
      yylloc->last_line = yylineno;                                  \
      yylloc->last_column = yytext + yyleng - strrchr(yytext, '\n'); \
    }
%}
%option nounistd
%option noyywrap
%option reentrant bison-bridge bison-locations

%%

[/][/].*\n      ; // comment
[0-9]+          { *yylval = strtol(yytext, NULL, 0); return NUM;}
[ \t\r\n]      ; // whitespace
.              { return *yytext; }

%%