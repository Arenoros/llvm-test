%option noinput nounput noyywrap 8bit nodefault                                 
%option yylineno
%option reentrant bison-bridge bison-locations                                  
%option header-file="calc.lex.h"

%{
  #include <stdlib.h>                                                           
  #include <string.h>
  #include "calc.tab.h"                                                   

%}                                                                              
%%

[ \t]+            ;                                                  
#.*               ;                                                  
[[:digit:]]+      { *yylval = strtol(yytext, NULL, 0); return NUMBER; }
.|\n              { return *yytext; }
%%
