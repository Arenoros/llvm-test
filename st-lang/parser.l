%option noinput nounput noyywrap 8bit nodefault                                 
%option reentrant bison-bridge bison-locations                                  
%option header-file="parser.lex.h"
%{
   #include <string>
   #include "parser.tab.h"
%}

TOK     [a-zA-Z0-9_]+
SGN     [+\-]
EXP     [eE][+\-]?[0-9]+
DIG     [0-9]
DIG19   [1-9]
XDIG    [0-9A-Fa-f]
NUM     {SGN}?{DIG}+
FLO     {SGN}?({DIG}*[.]{DIG}+{EXP}?|{DIG}+[.]?{EXP})

WS      [\t ]*
REQWS   [\t ]+
NL      (\n|\r|\r\n)
COMMA   [,]

ASC     [\x00-\x7f]
ASCN    [\x00-\t\v-\x7f]
U       [\x80-\xbf]
U2      [\xc2-\xdf]
U3      [\xe0-\xef]
U4      [\xf0-\xf4]

PARAM  {TOK}|{U2}{U}|{U3}{U}{U}|{U4}{U}{U}{U}

%x VAR_DEF

%%

{FLO}		{ yylval->lexeme = yytext; return LREAL; }
{NUM} 		{ yylval->lexeme = yytext; return LINT; }

<VAR_DEF>{COMMA} { return COMMA; }
<VAR_DEF>{PARAM} { return var_name; }
[ \n\r]+		;

%%

