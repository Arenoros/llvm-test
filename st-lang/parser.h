#pragma once

#include "core.h"
#include "add_en_eno_param_decl.h"
#include "flex_priv.h"
#include "ast.h"

typedef void* yyscan_t;
struct parser_t {
    yyscan_t scanner;
};