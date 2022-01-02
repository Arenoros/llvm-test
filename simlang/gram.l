
%{
   #include <string>
   #include "ast.h"
   #define YYSTYPE ast_t
   #include "gram.tab.h"
   void yyerror(const char *s);
%}
%option noinput nounput noyywrap 8bit nodefault                                 
%option reentrant bison-bridge bison-locations                                  
%option header-file="gram.lex.h"

%option yylineno
%option noyywrap

%x STR

%%

[/][/].*\n      ; // comment
if              return IF;
else            return ELSE;
while           return WHILE;
exit            return EXIT;
==              return EQ;
[<]=            return LE;
>=              return GE;
!=              return NE;
[0-9]+          { yylval->str = yytext; return NUM; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval->str = yytext; return ID; }
["]             { yylval->str = ""; BEGIN(STR); }
<STR>[^\\\n"]+  yylval->str += yytext;
<STR>\\n        yylval->str += '\n';
<STR>\\["]      yylval->str += '"';
<STR>\\         yyerror("Invalid escape sequence");
<STR>\n         yyerror("Newline in string literal");
<STR>["]        { BEGIN(INITIAL); return STRING; }
[ \t\r\n]       ; // whitespace
[-{};()=<>+*/!,] { return *yytext; }
.               yyerror("Invalid character");

%%
