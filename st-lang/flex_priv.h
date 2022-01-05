#pragma once
#include "symtable.h"


/*
 * This file includes the interface through which the lexical parser (stage 1 - flex)
 * and the syntax analyser (stage 2 - bison) interact between themselves.
 *
 * This is mostly through direct access to shared global variables, however some
 * of the global variables will only be accessed through some accessor functions.
 *
 * This file also includes the interface between the main stage1_2() functions and
 * the flex lexical parser.
 *
 * This file also includes some utility functions (strdupX() ) that are both used
 * in the lexical and syntax analysers.
 */

/*************************************************************/
/*************************************************************/
/****                                                    *****/
/****  I n t e r f a c e    B e t w e e n                *****/
/****           F l e x    a n d     s t a g e 1 _ 2 ()  *****/
/****                                                    *****/
/*************************************************************/
/*************************************************************/



/*************************************************************/
/*************************************************************/
/****                                                    *****/
/****  I n t e r f a c e    B e t w e e n                *****/
/****           F l e x    a n d     B i s o n           *****/
/****                                                    *****/
/*************************************************************/
/*************************************************************/

/*****************************************************/
/* Ask flex to include the source code in the string */
/*****************************************************/
/* This is a service that flex provides to bison... */
/* The string should contain valid IEC 61131-3 source code. Bison will ask flex to insert source
 * code into the input stream of IEC code being parsed. The code to be inserted is typically
 * generated automatically.
 * Currently this is used to insert conversion functions ***_TO_*** (as defined by the standard)
 * between user defined (i.e. derived) enumerated datatypes, and some basic datatypes
 * (e.g. INT, STRING, etc...)
 */
void include_string(const char* source_code);


/*************************************************************/
/*************************************************************/
/****                                                    *****/
/****  U t i l i t y   F u n c t i o n s ...             *****/
/****                                                    *****/
/****                                                    *****/
/*************************************************************/
/*************************************************************/

///* Join two strings together. Allocate space with malloc(3). */
//char* strdup2(const char* a, const char* b);
//
///* Join three strings together. Allocate space with malloc(3). */
//char* strdup3(const char* a, const char* b, const char* c);