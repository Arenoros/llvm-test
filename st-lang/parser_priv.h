#pragma once
#include <stdint.h>
#include "parser.tab.h"
#include "parser.lex.h"

inline void yyerror(YYLTYPE* locp, yyscan_t scanner, const char* msg) {}