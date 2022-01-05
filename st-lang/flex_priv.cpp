#pragma once

#include <cstdarg>
/* file with declaration of absyntax classes... */
#include "ast.h"
#include "flex_priv.h"
#include "core.h"
#include "parser_priv.h"


/***********************************************************************/

void error_exit(const char* file_name, int line_no, const char* errmsg, ...) {
    va_list argptr;
    va_start(argptr, errmsg); /* second argument is last fixed pamater of error_exit() */

    fprintf(stderr, "\nInternal compiler error in file %s at line %d", file_name, line_no);
    if (errmsg != NULL) {
        fprintf(stderr, ": ");
        vfprintf(stderr, errmsg, argptr);
    } else {
        fprintf(stderr, ".");
    }
    fprintf(stderr, "\n");
    va_end(argptr);

    exit(EXIT_FAILURE);
}

/***********************************/
/* Utility function definitions... */
/***********************************/

/* Open an include file, and set the internal state variables of lexical analyser to process a new include file */
void include_file(const char*) {}

/* The body_state tries to find a ';' before a END_PROGRAM, END_FUNCTION or END_FUNCTION_BLOCK or END_ACTION
 * and ignores ';' inside comments and pragmas. This means that we cannot do this in a signle lex rule.
 * Body_state therefore stores ALL text we consume in every rule, so we can push it back into the buffer
 * once we have decided if we are parsing ST or IL code. The following functions manage that buffer used by
 * the body_state.
 */
/* The buffer used by the body_state state */


/*******************************/
/* Public Interface for Bison. */
/*******************************/

/* The following functions will be called from inside bison code! */

void include_string(const char* source_code) {}
