
%define api.pure full
%locations
%error-verbose
%param { yyscan_t scanner }
%parse-param { oper_t** ast }

%code top {
    #include <stdio.h>
} 
%code requires {
    typedef void* yyscan_t;
}
%{
    #include "ast.h"   
    #define YYSTYPE ast_t
%}

%code {
    int yylex(YYSTYPE* yylvalp, YYLTYPE* yyllocp, yyscan_t scanner);
    void yyerror(YYLTYPE* yyllocp, yyscan_t, oper_t**, const char* msg);
}

%token IF ELSE WHILE EXIT
%token EQ LE GE NE
%token STRING NUM ID

%type<str> ID NUM STRING
%type<oper> OPS OP1 OP2 OP
%type<expr> EXPR EXPR1 EXPR2 TERM VAL ARG
%type<args> ARGS

%%

PROGRAM: OPS                           { *ast = $1; }
;

OPS:    OP                              // inherit
|       OPS OP                          { $$ = new block($1, $2); }
;

OP1:    '{' OPS '}'                     { $$ = $2; }
|       EXPR ';'                        { $$ = new exprop($1); }
|       IF '(' EXPR ')' OP1 ELSE OP1    { $$ = new ifop($3, $5, $7); }
|       WHILE '(' EXPR ')' OP1          { $$ = new whileop($3, $5); }
|       EXIT ';'                        { $$ = new exitop(); }
;

OP2:    IF '(' EXPR ')' OP              { $$ = new ifop($3, $5, new block()); }
|       IF '(' EXPR ')' OP1 ELSE OP2    { $$ = new ifop($3, $5, $7); }
|       WHILE '(' EXPR ')' OP2          { $$ = new whileop($3, $5); }
;

OP:     OP1 | OP2 ;                     // inherit

EXPR:   EXPR1                           // inherit
|       ID '=' EXPR                     { $$ = new assign($1, $3); }

EXPR1:  EXPR2                           // inherit
|       EXPR1 EQ EXPR2                  { $$ = new binary('=', $1, $3); }
|       EXPR1 LE EXPR2                  { $$ = new binary('L', $1, $3); }
|       EXPR1 GE EXPR2                  { $$ = new binary('G', $1, $3); }
|       EXPR1 NE EXPR2                  { $$ = new binary('N', $1, $3); }
|       EXPR1 '>' EXPR2                 { $$ = new binary('>', $1, $3); }
|       EXPR1 '<' EXPR2                 { $$ = new binary('<', $1, $3); }
;

EXPR2:  TERM                            // inherit
|       EXPR2 '+' TERM                  { $$ = new binary('+', $1, $3); }
|       EXPR2 '-' TERM                  { $$ = new binary('-', $1, $3); }
;

TERM:   VAL                             // inherit
|       TERM '*' VAL                    { $$ = new binary('*', $1, $3); }
|       TERM '/' VAL                    { $$ = new binary('/', $1, $3); }
;

VAL:    NUM                             { $$ = new value($1); }
|       '-' VAL                         { $$ = new unary('-', $2); }
|       '!' VAL                         { $$ = new unary('!', $2); }
|       '(' EXPR ')'                    { $$ = $2; }
|       ID                              { $$ = new varref($1); }
|       ID '(' ARGS ')'                 { $$ = new funcall($1, $3); }
;

ARGS:                                   { $$.clear(); }
|       ARG                             { $$.clear(); $$.push_back($1); }
|       ARGS ',' ARG                    { $$ = $1; $$.push_back($3); }
;

ARG:    EXPR                            // inherit
|       STRING                          { $$ = new str($1); }
;


%%

