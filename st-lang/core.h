#pragma once

#include <cstdint>
#include "ast.h"
typedef intptr_t cnum;

inline char* creat_strcopy(const char* str) {
    size_t len = strlen(str);
    char* cpy = (char*)malloc(len + 1);
    if (!cpy) {
        ERROR_MSG("Out of memory. Bailing out!\n");
    }
    strcpy_s(cpy, len, str);
    cpy[len] = 0;
    return cpy;
}