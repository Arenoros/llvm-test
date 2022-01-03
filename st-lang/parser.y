%define api.pure full
%define parse.error verbose
%locations
%code requires {
    typedef void* yyscan_t;
}
%param { yyscan_t scanner }
%code {
    #include "parser.h"
}
%union {
    int start;
}
%%

PROG: