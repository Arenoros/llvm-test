%option noinput nounput noyywrap 8bit nodefault                                 
%option reentrant bison-bridge bison-locations                                  
%option header-file="parser.lex.h"
%{
   #include <string>
    #include "parser.tab.h"
%}

%%
