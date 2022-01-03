#pragma once

#include <cstdint>
#include "ast.h"
typedef intptr_t cnum;
union obj {
    ast::int64_expr_t* i64;
    ast::float64_expr_t* f64;
};