#pragma once

/* file with declaration of absyntax classes... */
#include "ast.h"

#include "core.h"
#include "flex_priv.h"

#include <cstdarg>

#include "parser_priv.h"

/******************************************************/
/* whether we are supporting safe extensions          */
/* as defined in PLCopen - Technical Committee 5      */
/* Safety Software Technical Specification,           */
/* Part 1: Concepts and Function Blocks,              */
/* Version 1.0 – Official Release                   */
/******************************************************/
runtime_options_t runtime_options;

bool get_opt_safe_extensions() {
    return runtime_options.safe_extensions;
}

/************************************/
/* whether to allow nested comments */
/************************************/
bool get_opt_nested_comments() {
    return runtime_options.nested_comments;
}

/**************************************************************************/
/* whether to allow REF(), DREF(), REF_TO, NULL and ^ operators/keywords  */
/**************************************************************************/
bool get_opt_ref_standard_extensions() {
    return runtime_options.ref_standard_extensions;
}

/**********************************************************************************************/
/* whether bison is doing the pre-parsing, where POU bodies and var declarations are ignored! */
/**********************************************************************************************/
static bool preparse_state__ = false;

void set_preparse_state(void) {
    preparse_state__ = true;
}
void rst_preparse_state(void) {
    preparse_state__ = false;
}
bool get_preparse_state(void) {
    return preparse_state__;
}  // returns true if bison is in preparse state

/****************************************************/
/* Controlling the entry to the body_state in flex. */
/****************************************************/
static int goto_body_state__ = 0;

void cmd_goto_body_state(void) {
    goto_body_state__ = 1;
}
int get_goto_body_state(void) {
    return goto_body_state__;
}
void rst_goto_body_state(void) {
    goto_body_state__ = 0;
}

/*************************************************************/
/* Controlling the entry to the sfc_qualifier_state in flex. */
/*************************************************************/
static int goto_sfc_qualifier_state__ = 0;

void cmd_goto_sfc_qualifier_state(void) {
    goto_sfc_qualifier_state__ = 1;
}
int get_goto_sfc_qualifier_state(void) {
    return goto_sfc_qualifier_state__;
}
void rst_goto_sfc_qualifier_state(void) {
    goto_sfc_qualifier_state__ = 0;
}

/*************************************************************/
/* Controlling the entry to the sfc_priority_state in flex.  */
/*************************************************************/
static int goto_sfc_priority_state__ = 0;

void cmd_goto_sfc_priority_state(void) {
    goto_sfc_priority_state__ = 1;
}
int get_goto_sfc_priority_state(void) {
    return goto_sfc_priority_state__;
}
void rst_goto_sfc_priority_state(void) {
    goto_sfc_priority_state__ = 0;
}

/*************************************************************/
/* Controlling the entry to the sfc_qualifier_state in flex. */
/*************************************************************/
static int goto_task_init_state__ = 0;

void cmd_goto_task_init_state(void) {
    goto_task_init_state__ = 1;
}
int get_goto_task_init_state(void) {
    return goto_task_init_state__;
}
void rst_goto_task_init_state(void) {
    goto_task_init_state__ = 0;
}

/****************************************************************/
/* Returning to state in flex previously pushed onto the stack. */
/****************************************************************/
static int pop_state__ = 0;

void cmd_pop_state(void) {
    pop_state__ = 1;
}
int get_pop_state(void) {
    return pop_state__;
}
void rst_pop_state(void) {
    pop_state__ = 0;
}

/*********************************/
/* The global symbol tables...   */
/*********************************/
/* NOTE: only accessed indirectly by the lexical parser (flex)
 *       through the function get_identifier_token()
 */
/* A symbol table to store all the library elements */
/* e.g.: <function_name , function_decl>
 *       <fb_name , fb_decl>
 *       <type_name , type_decl>
 *       <program_name , program_decl>
 *       <configuration_name , configuration_decl>
 */
/* static */ library_element_symtable_t library_element_symtable;

/* A symbol table to store the declared variables of
 * the function currently being parsed...
 */
/* static */ variable_name_symtable_t variable_name_symtable;

/* A symbol table to store the declared direct variables of
 * the function currently being parsed...
 */
/* static */ direct_variable_symtable_t direct_variable_symtable;

/* Function only called from within flex!
 *
 * search for a symbol in either of the two symbol tables
 * declared above, and return the token id of the first
 * symbol found.
 * Searches first in the variables, and only if not found
 * does it continue searching in the library elements
 */
int get_identifier_token(const char* identifier_str) {
    //  std::cout << "get_identifier_token(" << identifier_str << "): \n";
    variable_name_symtable_t ::iterator iter1;
    library_element_symtable_t::iterator iter2;

    if ((iter1 = variable_name_symtable.find(identifier_str)) != variable_name_symtable.end())
        return iter1->second;

    if ((iter2 = library_element_symtable.find(identifier_str)) != library_element_symtable.end())
        return iter2->second;

    return identifier_token;
}

/* Function only called from within flex!
 *
 * search for a symbol in direct variables symbol table
 * declared above, and return the token id of the first
 * symbol found.
 */
int get_direct_variable_token(const char* direct_variable_str) {
    direct_variable_symtable_t::iterator iter;

    if ((iter = direct_variable_symtable.find(direct_variable_str)) != direct_variable_symtable.end())
        return iter->second;

    return direct_variable_token;
}

/************************/
/* Utility Functions... */
/************************/
//
///*
// * Join two strings together. Allocate space with malloc(3).
// */
// char* strdup2(const char* a, const char* b) {
//    char* res = (char*)malloc(strlen(a) + strlen(b) + 1);
//
//    if (!res)
//        return NULL;
//    return strcat(strcpy(res, a), b); /* safe, actually */
//}
//
///*
// * Join three strings together. Allocate space with malloc(3).
// */
// char* strdup3(const char* a, const char* b, const char* c) {
//    char* res = (char*)malloc(strlen(a) + strlen(b) + strlen(c) + 1);
//
//    if (!res)
//        return NULL;
//    return strcat(strcat(strcpy(res, a), b), c); /* safe, actually */
//}

/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
/***********************************************************************/
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
void unput_char(const char c, yyscan_t yyscanner);
/* Return all data in bodystate_buffer back to flex, and empty bodystate_buffer. */
void unput_bodystate_buffer(yyscan_t scanner, parser_t* parser) {
    if (parser->bodystate_buffer.empty())
        ERROR;
    // printf("<<<unput_bodystate_buffer>>>\n%s\n", parser->bodystate_buffer);

    for (size_t i = parser->bodystate_buffer.size(); i > 0; i--)
        unput_char(parser->bodystate_buffer[i - 1], scanner);

    parser->bodystate_buffer.clear();
    parser->bodystate_is_whitespace = true;
    *parser->current_tracking = parser->bodystate_init_tracking;
}

/* append text to bodystate_buffer */
void append_bodystate_buffer(const char* text, parser_t* parser, int is_whitespace) {
    // printf("<<<append_bodystate_buffer>>> %d <%s><%s>\n", parser->bodystate_buffer, text, (NULL !=
    // parser->bodystate_buffer)? parser->bodystate_buffer:"NULL");

    // make backup of tracking if we are starting off a new body_state_buffer
    if (parser->bodystate_buffer.empty())
        parser->bodystate_init_tracking = *parser->current_tracking;
    // set bodystate_is_whitespace flag if we are starting a new buffer
    if (parser->bodystate_buffer.empty())
        parser->bodystate_is_whitespace = true;
    // set bodystate_is_whitespace flag to FALSE if we are adding non white space to buffer
    if (!is_whitespace)
        parser->bodystate_is_whitespace = 0;

    parser->bodystate_buffer += text;
}

/* Return true if bodystate_buffer is empty or ony contains whitespace!! */
int isempty_bodystate_buffer(parser_t* parser) {
    if (parser->bodystate_buffer.empty())
        return 1;
    if (parser->bodystate_is_whitespace)
        return 1;
    return 0;
}

/*******************************/
/* Public Interface for Bison. */
/*******************************/

/* The following functions will be called from inside bison code! */

void include_string(const char* source_code) {}
