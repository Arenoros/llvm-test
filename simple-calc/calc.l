%option noinput nounput noyywrap 8bit nodefault                                 
%option yylineno
%option reentrant bison-bridge bison-locations                                  
%option header-file="calc.lex.h"

%{
  #include <stdlib.h>                                                           
  #include <string.h>
  #include "calc.tab.h"                                                   
  
  #define YY_USER_ACTION                                             \
    yylloc->first_line = yylloc->last_line;                          \
    yylloc->first_column = yylloc->last_column;                      \
    if (yylloc->last_line == yylineno)                               \
      yylloc->last_column += yyleng;                                 \
    else {                                                           \
      yylloc->last_line = yylineno;                                  \
      yylloc->last_column = yytext + yyleng - strrchr(yytext, '\n'); \
    }
%}                                                                              
%%

[ \t]+            ;                                                  
#.*               ;                                                  
[[:digit:]]+      { *yylval = strtol(yytext, NULL, 0); return NUMBER; }
.|\n              { return *yytext; }
%%
