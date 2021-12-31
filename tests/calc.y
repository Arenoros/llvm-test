%define api.pure full
%locations
%param { yyscan_t scanner }

%code top {
  #include <stdio.h>
} 
%code requires {
  typedef void* yyscan_t;
}
%code {
  int yylex(YYSTYPE* yylvalp, YYLTYPE* yyllocp, yyscan_t scanner);
  void yyerror(YYLTYPE* yyllocp, yyscan_t unused, const char* msg);
}

%token NUMBER UNOP
%left '+' '-'
%left '*' '/' '%'
%precedence UNOP
%%
input: %empty
     | input expr '\n'      { printf("[%d]: %d\n", @2.first_line, $2); }
     | input '\n'
     | input error '\n'     { yyerrok; }
expr : NUMBER
     | '(' expr ')'         { $$ = $2; }
     | '-' expr %prec UNOP  { $$ = -$2; }
     | expr '+' expr        { $$ = $1 + $3; }
     | expr '-' expr        { $$ = $1 - $3; }
     | expr '*' expr        { $$ = $1 * $3; }
     | expr '/' expr        { $$ = $1 / $3; }
     | expr '%' expr        { $$ = $1 % $3; }

%%

void yyerror(YYLTYPE* yyllocp, yyscan_t unused, const char* msg) {
  fprintf(stderr, "[%d:%d]: %s\n",
                  yyllocp->first_line, yyllocp->first_column, msg);
}