%define api.pure full
%define parse.error verbose
%locations
%code requires {
#include "core.h"
    typedef void* yyscan_t;
}
%param { yyscan_t scanner }
%code {
#include "parser.h"
// VAR_IN_OUT A: ARRAY[*] OF INT; ENDVAR;
// VAR i, sum2: DINT; ENDVAR;
}

%union {
  const char *lexeme;
  union obj *val;
  wchar_t chr;
  cnum lineno;
}

%token <lexeme> LREAL LINT 
%token <lexeme> var_name type
%token COMMA

%%
NUMBERS: NUMBER
| NUMBERS NUMBER 

NUMBER: LREAL { printf("LREAL: %s\n", $1); }
    | LINT { printf("LINT: %s\n", $1); }

VAR: var_names ':' type
var_names: var_name | var_names COMMA var_name
