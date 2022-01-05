%{

#define _CRT_SECURE_NO_WARNINGS
#include <string.h>	/* required for creat_strcopy()  */
#include "ast.h"

/* Macros used to pass the line and column locations when
 * creating a new object for the abstract syntax tree.
 */

#define locloc(foo) foo.first_line, foo.first_column, foo.first_file, foo.first_order, foo.last_line, foo.last_column, foo.last_file, foo.last_order
#define   locf(foo) foo.first_line, foo.first_column, foo.first_file, foo.first_order
#define   locl(foo) foo.last_line,  foo.last_column,  foo.last_file,  foo.last_order

/* Redefine the default action to take for each rule, so that the filenames are correctly processed... */
# define YYLLOC_DEFAULT(Current, Rhs, N)                                \
         do                                                                  \
           if (N)                                                            \
             {                                                               \
               (Current).first_line   = YYRHSLOC(Rhs, 1).first_line;         \
               (Current).first_column = YYRHSLOC(Rhs, 1).first_column;       \
               (Current).first_file   = YYRHSLOC(Rhs, 1).first_file;         \
               (Current).first_order  = YYRHSLOC(Rhs, 1).first_order;        \
               (Current).last_line    = YYRHSLOC(Rhs, N).last_line;          \
               (Current).last_column  = YYRHSLOC(Rhs, N).last_column;        \
               (Current).last_file    = YYRHSLOC(Rhs, 1).last_file;          \
               (Current).last_order   = YYRHSLOC(Rhs, 1).last_order;         \
             }                                                               \
           else                                                              \
             {                                                               \
               (Current).first_line   = (Current).last_line   =              \
                 YYRHSLOC(Rhs, 0).last_line;                                 \
               (Current).first_column = (Current).last_column =              \
                 YYRHSLOC(Rhs, 0).last_column;                               \
               (Current).first_file   = (Current).last_file   =              \
                 YYRHSLOC(Rhs, 0).last_file;                                 \
               (Current).first_order  = (Current).last_order  =              \
                 YYRHSLOC(Rhs, 0).last_order;                                \
             }                                                               \
         while (0)

#define FOR_EACH_ELEMENT(elem, list, code) {		\
  symbol_c *elem;					\
  for(int i = 0; i < list->size(); i++) {			\
    elem = list->get_element(i);			\
    code;						\
  }							\
}

/* A global flag used to tell the parser if overloaded funtions should be allowed.
 * The IEC 61131-3 standard allows overloaded funtions in the standard library,
 * but disallows them in user code...
 */
extern bool allow_function_overloading;

/* A flag to tell the compiler whether to allow the declaration
 * of extensible function (i.e. functions that may have a variable number of
 * input parameters, such as AND(word#33, word#44, word#55, word#66).
 * This is an extension to the standard syntax.
 * See comments below for details why we support this!
 */
extern bool allow_extensible_function_parameters;

/* A global flag used to tell the parser whether to allow use of DREF and '^' operators (defined in IEC 61131-3 v3) */
extern bool allow_ref_dereferencing;

/* A global flag used to tell the parser whether to allow use of REF_TO ANY datatypes (non-standard extension to IEC 61131-3 v3) */
extern bool allow_ref_to_any;

/* A global flag used to tell the parser whether to allow use of REF_TO as a struct or array element (non-standard extension) */
extern bool allow_ref_to_in_derived_datatypes;

/************************/
/* forward declarations */
/************************/
/* The functions declared here are defined at the end of this file... */

/* Convert an il_operator_c into an identifier_c */
identifier_c         *il_operator_c_2_identifier_c        (symbol_c *il_operator);
/* Convert an il_operator_c into an poutype_identifier_c */
poutype_identifier_c *il_operator_c_2_poutype_identifier_c(symbol_c *il_operator);


/* return if current token is a syntax element */
/* ERROR_CHECK_BEGIN */
bool is_current_syntax_token(int token);
/* ERROR_CHECK_END */

/* print an error message */
void print_err_msg(int first_line,
                   int first_column,
                   const char *first_filename,
                   long int first_order,
                   int last_line,
                   int last_column,
                   const char *last_filename,
                   long int last_order,
                   const char *additional_error_msg);
                   
%}

%define api.pure full
%define parse.error verbose
%locations
%code requires {
	#include "parser.h"
#if ! defined YYLTYPE && ! defined YYLTYPE_IS_DECLARED
    typedef struct YYLTYPE {
        int         first_line;
        int         first_column;
        const char *first_file;
        long int    first_order;
        int         last_line;
        int         last_column;
        const char *last_file;
        long int    last_order;
    } YYLTYPE;
    #define YYLTYPE_IS_DECLARED 1
    #define YYLTYPE_IS_TRIVIAL 0
#endif
typedef union YYSTYPE YYSTYPE;
#define YY_DECL \
       int yylex(YYSTYPE* yylval_param, YYLTYPE* yylloc_param, yyscan_t yyscanner, parser_t* parser)
YY_DECL;
void yyerror(YYLTYPE* locp, yyscan_t scanner, parser_t* parser, const char* msg);

}

%param { yyscan_t scanner }
%param { parser_t* parser }
// %parse-param { symbol_c** tree_root }
%code {
    #include "parser_priv.h"

}

%union {
    symbol_c 	*leaf;
    list_c	*list;
    char 	*ID;	/* token value */
}

/*************************************/
/* Prelimenary helpful constructs... */
/*************************************/
/* A token used to identify the very end of the input file
 * after all includes have already been processed.
 *
 * Flex automatically returns the token with value 0
 * at the end of the file. We therefore specify here
 * a token with that exact same value here, so we can use it
 * to detect the very end of the input files.
 */
%token END_OF_INPUT 0

/* A bogus token that, in principle, flex MUST NEVER generate */
/* USE 1:
 * ======
 * This token is currently also being used as the default
 * initialisation value of the token_id member in
 * the symbol_c base class.
 *
 * USE 2
 * =====
 * This token may also be used in the future to remove
 * mysterious reduce/reduce conflicts due to the fact
 * that our grammar may not be LALR(1) but merely LR(1).
 * This means that bison cannot handle it without some
 * caoxing from ourselves. We will then need this token
 * to do the coaxing...
 */
%token BOGUS_TOKEN_ID

%type <leaf>	start

%type <leaf>	any_identifier

%token <ID>	prev_declared_variable_name_token
%token <ID>	prev_declared_direct_variable_token
%token <ID>	prev_declared_fb_name_token
%type <leaf>	prev_declared_variable_name
%type <leaf>	prev_declared_direct_variable
%type <leaf>	prev_declared_fb_name

%token  <ID>	prev_declared_simple_type_name_token
%token  <ID>	prev_declared_subrange_type_name_token
%token  <ID>	prev_declared_enumerated_type_name_token
%token  <ID>	prev_declared_array_type_name_token
%token  <ID>	prev_declared_structure_type_name_token
%token  <ID>	prev_declared_string_type_name_token
%token  <ID>	prev_declared_ref_type_name_token  /* defined in IEC 61131-3 v3 */

%type  <leaf>	prev_declared_simple_type_name
%type  <leaf>	prev_declared_subrange_type_name
%type  <leaf>	prev_declared_enumerated_type_name
%type  <leaf>	prev_declared_array_type_name
%type  <leaf>	prev_declared_structure_type_name
%type  <leaf>	prev_declared_string_type_name
%type  <leaf>	prev_declared_ref_type_name  /* defined in IEC 61131-3 v3 */

%token <ID>	prev_declared_derived_function_name_token
%token <ID>	prev_declared_derived_function_block_name_token
%token <ID>	prev_declared_program_type_name_token
%type  <leaf>	prev_declared_derived_function_name
%type  <leaf>	prev_declared_derived_function_block_name
%type  <leaf>	prev_declared_program_type_name

/* Tokens used to help resolve a reduce/reduce conflict */
/* The mentioned conflict only arises due to a non-standard feature added to matiec.
 * Namely, the permission to call functions returning VOID as an ST statement.
 *   e.g.:   FUNCTION foo: VOID
 *             VAR_INPUT i: INT; END_VAR;
 *             ...
 *           END_FUNCTION
 *
 *           FUNCTION BAR: BOOL
 *             VAR b: bool; END_VAR
 *             foo(i:=42);   <--- Calling foo outside an expression. Function invocation is considered an ST statement!!
 *           END_FUNCTION
 *
 *  The above function invocation may also be reduced to a formal IL function invocation, so we get a 
 *  reduce/reduce conflict to st_statement_list/instruction_list  (or something equivalent).
 *
 *  We solve this by having flex determine if it is ST or IL invocation (ST ends with a ';' !!).
 *  At the start of a function/FB/program body, flex will tell bison whether to expect ST or IL code!
 *  This is why we need the following two tokens!
 *
 *  NOTE: flex was already determing whther it was parsing ST or IL code as it can only send 
 *        EOL tokens when parsing IL. However, did this silently without telling bison about this.
 *        Now, it does
 */
%token          start_ST_body_token
%token          start_IL_body_token



/**********************************************************************************/
/* B XXX - Things that are missing from the standard, but should have been there! */
/**********************************************************************************/

/* Pragmas that our compiler will accept.
 * See the comment in iec.flex for why these pragmas exist. 
 */
%token          disable_code_generation_pragma_token
%token          enable_code_generation_pragma_token
%type <leaf>	disable_code_generation_pragma
%type <leaf>	enable_code_generation_pragma


/* All other pragmas that we do not support... */
/* In most stage 4, the text inside the pragmas will simply be copied to the output file.
 * This allows us to insert C code (if using stage 4 generating C code) 
 * inside/interningled with the IEC 61131-3 code!
 */
%token <ID>	pragma_token
%type <leaf>	pragma

/* The joining of all previous pragmas, i.e. any possible pragma */
%type <leaf>	any_pragma


/* Where do these tokens belong?? They are missing from the standard! */
/* NOTE: There are other tokens related to these 'EN' ENO', that are also 
 * missing from the standard. However, their location in the annex B is 
 * relatively obvious, so they have been inserted in what seems to us their 
 * correct place in order to ease understanding of the parser...
 *
 * please read the comment above the definition of 'variable' in section B1.4 for details.
 */
%token	EN
%token	ENO
%type <leaf>	en_identifier
%type <leaf>	eno_identifier

/* Keywords in IEC 61131-3 v3 */
%token	REF
%token	DREF
%token	REF_TO
%token	NULL_token  /* cannot use simply 'NULL', as it conflicts with the NULL keyword in C++ */



/***************************/
/* B 0 - Programming Model */
/***************************/
%type <list>	library
%type <leaf>	library_element_declaration


/*******************************************/
/* B 1.1 - Letters, digits and identifiers */
/*******************************************/
/* Done totally within flex...
  letter
  digit
  octal_digit
  hex_digit
*/
%token <ID>	identifier_token
%type  <leaf>	identifier

/*********************/
/* B 1.2 - Constants */
/*********************/
%type <leaf>	constant
%type <leaf>	non_int_or_real_constant

/*********************************/
/* B 1.2.XX - Reference Literals */
/*********************************/
/* NOTE: The following syntax was added by MJS in order to add support for the NULL keyword, defined in  IEC 61131-3 v3
 *       In v3 expressions that reduce to a reference datatype (REF_TO) are handled explicitly in the syntax 
 *       (e.g., any variable that is a of reference datatpe falls under the 'ref_name' rule), which means 
 *       that we would need to keep track of which variables are declared as REF_TO. 
 *       In order to reduce the changes to the current IEC 61131-3 v2 syntax, I have opted not to do this,
 *       and simply let the ref_expressions (Ref_Assign, Ref_Compare) be interpreted as all other standard expressions 
 *       in v2. However, ref_expressions allow the use of the 'NULL' constant, which is handled explicitly
 *       in the ref_expressions syntax of v3.
 *       To allow the use of the 'NULL' constant in this extended v2, I have opted to interpret this 'NULL' constant 
 *       as a literal.
 */
%type  <leaf>	ref_value_null_literal  /* defined in IEC 61131-3 v3 - Basically the 'NULL' keyword! */


/******************************/
/* B 1.2.1 - Numeric Literals */
/******************************/
/* Done totally within flex...
  bit
*/
%type  <leaf> numeric_literal
%type  <leaf> integer_literal
%type  <leaf> signed_integer
%token <ID>   integer_token
%type  <leaf> integer
%token <ID>   binary_integer_token
%type  <leaf> binary_integer
%token <ID>   octal_integer_token
%type  <leaf> octal_integer
%token <ID>   hex_integer_token
%type  <leaf> hex_integer
%token <ID>   real_token
%type  <leaf> real
%type  <leaf> signed_real
%type  <leaf> real_literal
// %type  <leaf> exponent
%type  <leaf> bit_string_literal
%type  <leaf> boolean_literal

%token safeboolean_true_literal_token
%token safeboolean_false_literal_token
%token boolean_true_literal_token
%token boolean_false_literal_token

%token FALSE
%token TRUE


/*******************************/
/* B 1.2.2 - Character Strings */
/*******************************/
%token <ID>   single_byte_character_string_token
%token <ID>   double_byte_character_string_token

%type  <leaf> character_string
%type  <leaf> single_byte_character_string
%type  <leaf> double_byte_character_string


/***************************/
/* B 1.2.3 - Time Literals */
/***************************/
%type  <leaf> time_literal


/************************/
/* B 1.2.3.1 - Duration */
/************************/
%type  <leaf>	duration
%type  <leaf>	interval
%type  <leaf>	days
%type  <leaf>	fixed_point
%type  <leaf>	hours
%type  <leaf>	minutes
%type  <leaf>	seconds
%type  <leaf>	milliseconds

%token <ID>	fixed_point_token
%token <ID>	fixed_point_d_token
%token <ID>	integer_d_token
%token <ID>	fixed_point_h_token
%token <ID>	integer_h_token
%token <ID>	fixed_point_m_token
%token <ID>	integer_m_token
%token <ID>	fixed_point_s_token
%token <ID>	integer_s_token
%token <ID>	fixed_point_ms_token
%token <ID>	integer_ms_token
%token <ID>	end_interval_token
%token <ID>	erroneous_interval_token
// %token TIME
%token T_SHARP


/************************************/
/* B 1.2.3.2 - Time of day and Date */
/************************************/
%type  <leaf>	time_of_day
%type  <leaf>	daytime
%type  <leaf>	day_hour
%type  <leaf>	day_minute
%type  <leaf>	day_second
%type  <leaf>	date
%type  <leaf>	date_literal
%type  <leaf>	year
%type  <leaf>	month
%type  <leaf>	day
%type  <leaf>	date_and_time

// %token TIME_OF_DAY
// %token DATE
%token D_SHARP
// %token DATE_AND_TIME


/**********************/
/* B 1.3 - Data Types */
/**********************/
/* Strangely, the following symbol does seem to be required! */
// %type  <leaf> data_type_name
%type  <leaf> non_generic_type_name


/***********************************/
/* B 1.3.1 - Elementary Data Types */
/***********************************/
/* NOTES:
 *
 *    - To make the definition of bit_string_literal more
 *      concise, it is useful to use an extra non-terminal
 *      symbol (i.e. a grouping or construct) that groups the
 *      following elements (BYTE, WORD, DWORD, LWORD).
 *      Note that the definition of bit_string_type_name
 *      (according to the spec) includes the above elements
 *      and an extra BOOL.
 *      We could use an extra construct with the first four
 *      elements to be used solely in the definition of
 *      bit_string_literal, but with the objective of not
 *      having to replicate the actions (if we ever need
 *      to change them, they would need to be changed in both
 *      bit_string_type_name and the extra grouping), we
 *      have re-defined bit_string_type_name as only including
 *      the first four elements.
 *      In order to have our parser implement the specification
 *      correctly we have augmented every occurence of
 *      bit_string_type_name in other rules with the BOOL
 *      token. Since bit_string_type_name only appears in
 *      the rule for elementary_type_name, this does not
 *      seem to be a big concession to make!
 *
 *    - We have added a helper symbol to concentrate the
 *      instantiation of STRING and WSTRING into a single
 *      location (elementary_string_type_name).
 *      These two elements show up in several other rules,
 *      but we want to create the equivalent abstract syntax
 *      in a single location of this file, in order to make
 *      possible future changes easier to edit...
 */
%type  <leaf>	elementary_type_name
%type  <leaf>	numeric_type_name
%type  <leaf>	integer_type_name
%type  <leaf>	signed_integer_type_name
%type  <leaf>	unsigned_integer_type_name
%type  <leaf>	real_type_name
%type  <leaf>	date_type_name
%type  <leaf>	bit_string_type_name
/* helper symbol to concentrate the instantiation
 * of STRING and WSTRING into a single location
 */
%type  <leaf>	elementary_string_type_name

%token BYTE
%token WORD
%token DWORD
%token LWORD

%token LREAL
%token REAL

%token SINT
%token INT
%token DINT
%token LINT

%token USINT
%token UINT
%token UDINT
%token ULINT

%token WSTRING
%token STRING
%token BOOL

%token TIME
%token DATE
%token DATE_AND_TIME
%token DT
%token TIME_OF_DAY
%token TOD

/* A non-standard extension! */
%token VOID

/******************************************************/
/* Symbols defined in                                 */
/* "Safety Software Technical Specification,          */
/*  Part 1: Concepts and Function Blocks,             */
/*  Version 1.0 � Official Release"                   */
/* by PLCopen - Technical Committee 5 - 2006-01-31    */
/******************************************************/

%token SAFEBYTE
%token SAFEWORD
%token SAFEDWORD
%token SAFELWORD

%token SAFELREAL
%token SAFEREAL

%token SAFESINT
%token SAFEINT
%token SAFEDINT
%token SAFELINT

%token SAFEUSINT
%token SAFEUINT
%token SAFEUDINT
%token SAFEULINT

%token SAFEWSTRING
%token SAFESTRING
%token SAFEBOOL

%token SAFETIME
%token SAFEDATE
%token SAFEDATE_AND_TIME
%token SAFEDT
%token SAFETIME_OF_DAY
%token SAFETOD

/********************************/
/* B 1.3.2 - Generic data types */
/********************************/
/* Strangely, the following symbol does seem to be required! */
// %type  <leaf>	generic_type_name

/* The following tokens do not seem to be used either
 * but we declare them so they become reserved words...
 */
%token ANY
%token ANY_DERIVED
%token ANY_ELEMENTARY
%token ANY_MAGNITUDE
%token ANY_NUM
%token ANY_REAL
%token ANY_INT
%token ANY_BIT
%token ANY_STRING
%token ANY_DATE


/********************************/
/* B 1.3.3 - Derived data types */
/********************************/
%type  <leaf>	derived_type_name
%type  <leaf>	single_element_type_name
// %type  <leaf>	simple_type_name
// %type  <leaf>	subrange_type_name
// %type  <leaf>	enumerated_type_name
// %type  <leaf>	array_type_name
// %type  <leaf>	structure_type_name

%type  <leaf>	data_type_declaration
/* helper symbol for data_type_declaration */
%type  <list>	type_declaration_list
%type  <leaf>	type_declaration
%type  <leaf>	single_element_type_declaration

%type  <leaf>	simple_type_declaration
%type  <leaf>	simple_spec_init
%type  <leaf>	simple_specification

%type  <leaf>	subrange_type_declaration
%type  <leaf>	subrange_spec_init
%type  <leaf>	subrange_specification
%type  <leaf>	subrange
/* A non standard construct, used to support the use of variables in array subranges. e.g.: ARRAY [12..max] OF INT */
%type  <leaf>	subrange_with_var

%type  <leaf>	enumerated_type_declaration
%type  <leaf>	enumerated_spec_init
%type  <leaf>	enumerated_specification
/* helper symbol for enumerated_value */
%type  <list>	enumerated_value_list
%type  <leaf>	enumerated_value
//%type  <leaf>	enumerated_value_without_identifier

%type  <leaf>	array_type_declaration
%type  <leaf>	array_spec_init
%type  <leaf>	array_specification
/* helper symbol for array_specification */
%type  <list>	array_subrange_list
%type  <leaf>	array_initialization
/* helper symbol for array_initialization */
%type  <list>	array_initial_elements_list
%type  <leaf>	array_initial_elements
%type  <leaf>	array_initial_element

%type  <leaf>	structure_type_declaration
%type  <leaf>	structure_specification
%type  <leaf>	initialized_structure
%type  <leaf>	structure_declaration
/* helper symbol for structure_declaration */
%type  <list>	structure_element_declaration_list
%type  <leaf>	structure_element_declaration
%type  <leaf>	structure_element_name
%type  <leaf>	structure_initialization
/* helper symbol for structure_initialization */
%type  <list>	structure_element_initialization_list
%type  <leaf>	structure_element_initialization

//%type  <leaf>	string_type_name
%type  <leaf>	string_type_declaration
/* helper symbol for string_type_declaration */
%type  <leaf>	string_type_declaration_size
/* helper symbol for string_type_declaration */
%type  <leaf>	string_type_declaration_init

%token ASSIGN
%token DOTDOT  /* ".." */
%token TYPE
%token END_TYPE
%token ARRAY
%token OF
%token STRUCT
%token END_STRUCT


%type  <leaf>	ref_spec                 /* defined in IEC 61131-3 v3 */
%type  <leaf>	ref_spec_non_recursive   /* helper symbol */
%type  <leaf>	ref_spec_init            /* defined in IEC 61131-3 v3 */
%type  <leaf>	ref_type_decl            /* defined in IEC 61131-3 v3 */



/*********************/
/* B 1.4 - Variables */
/*********************/
%type  <leaf>	variable
%type  <leaf>	symbolic_variable
/* helper symbol for prog_cnxn */
%type  <leaf>	any_symbolic_variable
%type  <leaf>	variable_name




/********************************************/
/* B.1.4.1   Directly Represented Variables */
/********************************************/
/* Done totally within flex...
 location_prefix
 size_prefix
*/
%token <ID>	direct_variable_token
//%type  <leaf>	direct_variable


/*************************************/
/* B.1.4.2   Multi-element Variables */
/*************************************/
%type  <leaf>	multi_element_variable
/* helper symbol for any_symbolic_variable */
%type  <leaf>	any_multi_element_variable
%type  <leaf>	array_variable
/* helper symbol for any_symbolic_variable */
%type  <leaf>	any_array_variable
%type  <leaf>	subscripted_variable
/* helper symbol for any_symbolic_variable */
%type  <leaf>	any_subscripted_variable
%type  <list>	subscript_list
%type  <leaf>	subscript
%type  <leaf>	structured_variable
/* helper symbol for any_symbolic_variable */
%type  <leaf>	any_structured_variable
%type  <leaf>	record_variable
/* helper symbol for any_symbolic_variable */
%type  <leaf>	any_record_variable
%type  <leaf>	field_selector


/******************************************/
/* B 1.4.3 - Declaration & Initialisation */
/******************************************/
%type  <leaf>	input_declarations
/* helper symbol for input_declarations */
%type  <list>	input_declaration_list
%type  <leaf>	input_declaration
%type  <leaf>	edge_declaration
/* en_param_declaration is not in the standard, but should be! */
%type  <leaf>	en_param_declaration
%type  <leaf>	var_init_decl
%type  <leaf>	var1_init_decl
%type  <list>	var1_list
%type  <leaf>	array_var_init_decl
%type  <leaf>	structured_var_init_decl
%type  <leaf>	fb_name_decl
/* helper symbol for fb_name_decl */
%type  <list>	fb_name_list_with_colon
/* helper symbol for fb_name_list_with_colon */
%type  <list>	var1_list_with_colon
// %type  <list>	fb_name_list
// %type  <leaf>	fb_name
%type  <leaf>	output_declarations
%type  <leaf>	var_output_init_decl
%type  <list>	var_output_init_decl_list
/* eno_param_declaration is not in the standard, but should be! */
%type  <leaf>	eno_param_declaration
%type  <leaf>	input_output_declarations
/* helper symbol for input_output_declarations */
%type  <list>	var_declaration_list
%type  <leaf>	var_declaration
%type  <leaf>	temp_var_decl
%type  <leaf>	var1_declaration
%type  <leaf>	array_var_declaration
%type  <leaf>	structured_var_declaration
%type  <leaf>	var_declarations
%type  <leaf>	retentive_var_declarations
%type  <leaf>	located_var_declarations
/* helper symbol for located_var_declarations */
%type  <list>	located_var_decl_list
%type  <leaf>	located_var_decl
%type  <leaf>	external_var_declarations
/* helper symbol for external_var_declarations */
%type  <list>	external_declaration_list
%type  <leaf>	external_declaration
%type  <leaf>	global_var_name
%type  <leaf>	global_var_declarations
/* helper symbol for global_var_declarations */
%type  <list>	global_var_decl_list
%type  <leaf>	global_var_decl
%type  <leaf>	global_var_spec
%type  <leaf>	located_var_spec_init
%type  <leaf>	location
%type  <list>	global_var_list
%type  <leaf>	string_var_declaration
%type  <leaf>	single_byte_string_var_declaration
%type  <leaf>	single_byte_string_spec
%type  <leaf>	double_byte_string_var_declaration
%type  <leaf>	double_byte_string_spec
%type  <leaf>	incompl_located_var_declarations
/* helper symbol for incompl_located_var_declarations */
%type  <list>	incompl_located_var_decl_list
%type  <leaf>	incompl_located_var_decl
%type  <leaf>	incompl_location
%type  <leaf>	var_spec
/* helper symbol for var_spec */
%type  <leaf>	string_spec
/* intermediate helper symbol for:
 *  - non_retentive_var_decls
 *  - var_declarations
 */
%type  <list>	var_init_decl_list

%token  <ID>	incompl_location_token

%token VAR_INPUT
%token VAR_OUTPUT
%token VAR_IN_OUT
%token VAR_EXTERNAL
%token VAR_GLOBAL
%token END_VAR
%token RETAIN
%token NON_RETAIN
%token R_EDGE
%token F_EDGE
%token AT


/***********************/
/* B 1.5.1 - Functions */
/***********************/
// %type  <leaf>	function_name
/* helper symbol for IL language */
%type  <leaf>	function_name_no_clashes
%type  <leaf>	function_name_simpleop_clashes
//%type  <leaf>	function_name_expression_clashes
/* helper symbols for ST language */
//%type  <leaf>	function_name_NOT_clashes
%type  <leaf>	function_name_no_NOT_clashes

//%type  <leaf>	standard_function_name
/* helper symbols for IL language */
%type  <leaf>	standard_function_name_no_clashes
%type  <leaf>	standard_function_name_simpleop_clashes
%type  <leaf>	standard_function_name_expression_clashes
/* helper symbols for ST language */
%type  <leaf>	standard_function_name_NOT_clashes
%type  <leaf>	standard_function_name_no_NOT_clashes

%type  <leaf>	derived_function_name
%type  <leaf>	function_declaration
/* helper symbol for function_declaration */
%type  <leaf>	function_name_declaration
%type  <leaf>	io_var_declarations
%type  <leaf>	function_var_decls
%type  <leaf>	function_body
%type  <leaf>	var2_init_decl
/* intermediate helper symbol for function_declaration */
%type  <list>	io_OR_function_var_declarations_list
/* intermediate helper symbol for function_var_decls */
%type  <list>	var2_init_decl_list

%token <ID>	standard_function_name_token

%token FUNCTION
%token END_FUNCTION
%token CONSTANT


/*****************************/
/* B 1.5.2 - Function Blocks */
/*****************************/
%type  <leaf>	function_block_type_name
%type  <leaf>	standard_function_block_name
%type  <leaf>	derived_function_block_name
%type  <leaf>	function_block_declaration
%type  <leaf>	other_var_declarations
%type  <leaf>	temp_var_decls
%type  <leaf>	non_retentive_var_decls
%type  <leaf>	function_block_body
/* intermediate helper symbol for function_declaration */
%type  <list>	io_OR_other_var_declarations_list
/* intermediate helper symbol for temp_var_decls */
%type  <list>	temp_var_decls_list

%token <ID>	standard_function_block_name_token

%token FUNCTION_BLOCK
%token END_FUNCTION_BLOCK
%token VAR_TEMP
// %token END_VAR
%token VAR
// %token NON_RETAIN
// %token END_VAR


/**********************/
/* B 1.5.3 - Programs */
/**********************/
%type  <leaf>	program_type_name
%type  <leaf>	program_declaration
/* helper symbol for program_declaration */
%type  <list>	program_var_declarations_list

%token PROGRAM
%token END_PROGRAM


/********************************************/
/* B 1.6 Sequential Function Chart elements */
/********************************************/

%type  <list>	sequential_function_chart
%type  <list>	sfc_network
%type  <leaf>	initial_step
%type  <leaf>	step
%type  <list>	action_association_list
%type  <leaf>	step_name
%type  <leaf>	action_association
/* helper symbol for action_association */
%type  <list>	indicator_name_list
%type  <leaf>	action_name
%type  <leaf>	action_qualifier
%type  <leaf>	qualifier
%type  <leaf>	timed_qualifier
%type  <leaf>	action_time
%type  <leaf>	indicator_name
%type  <leaf>	transition
%type  <leaf>	steps
%type  <list>	step_name_list
%type  <leaf>	transition_priority
%type  <leaf>	transition_condition
%type  <leaf>	action
%type  <leaf>	action_body
%type  <leaf>	transition_name


// %token ASSIGN
%token ACTION
%token END_ACTION

%token TRANSITION
%token END_TRANSITION
%token FROM
%token TO
%token PRIORITY

%token INITIAL_STEP
%token STEP
%token END_STEP

%token L
%token D
%token SD
%token DS
%token SL

%token N
%token P
%token P0
%token P1
/* NOTE: the following two clash with the R and S IL operators.
 * It will have to be handled when we include parsing of SFC...
 */
/*
%token R
%token S
*/


/********************************/
/* B 1.7 Configuration elements */
/********************************/
%type  <leaf>	configuration_name
%type  <leaf>	resource_type_name
%type  <leaf>	configuration_declaration
// helper symbol for
//  - configuration_declaration
//  - resource_declaration
//
%type  <list>	global_var_declarations_list
// helper symbol for configuration_declaration
%type  <leaf>	optional_access_declarations
// helper symbol for configuration_declaration
%type  <leaf>	optional_instance_specific_initializations
// helper symbol for configuration_declaration
%type  <list>	resource_declaration_list
%type  <leaf>	resource_declaration
%type  <leaf>	single_resource_declaration
// helper symbol for single_resource_declaration
%type  <list>	task_configuration_list
// helper symbol for single_resource_declaration
%type  <list>	program_configuration_list
%type  <leaf>	resource_name
// %type  <leaf>	access_declarations
// helper symbol for access_declarations
// %type  <leaf>	access_declaration_list
// %type  <leaf>	access_declaration
// %type  <leaf>	access_path
// helper symbol for access_path
%type  <list>	any_fb_name_list
%type  <leaf>	global_var_reference
// %type  <leaf>	access_name
%type  <leaf>	program_output_reference
%type  <leaf>	program_name
// %type  <leaf>	direction
%type  <leaf>	task_configuration
%type  <leaf>	task_name
%type  <leaf>	task_initialization
// 3 helper symbols for task_initialization
%type  <leaf>	task_initialization_single
%type  <leaf>	task_initialization_interval
%type  <leaf>	task_initialization_priority

%type  <leaf>	data_source
%type  <leaf>	program_configuration
// helper symbol for program_configuration
%type  <leaf>	optional_task_name
// helper symbol for program_configuration
%type  <leaf>	optional_prog_conf_elements
%type  <list>	prog_conf_elements
%type  <leaf>	prog_conf_element
%type  <leaf>	fb_task
%type  <leaf>	prog_cnxn
%type  <leaf>	prog_data_source
%type  <leaf>	data_sink
%type  <leaf>	instance_specific_initializations
// helper symbol for instance_specific_initializations
%type  <list>	instance_specific_init_list
%type  <leaf>	instance_specific_init
// helper symbol for instance_specific_init
%type  <leaf>	fb_initialization

%type  <leaf>	prev_declared_global_var_name
%token  <ID>	prev_declared_global_var_name_token

%type  <leaf>	prev_declared_program_name
%token  <ID>	prev_declared_program_name_token

%type  <leaf>	prev_declared_resource_name
%token  <ID>	prev_declared_resource_name_token

%type  <leaf>	prev_declared_configuration_name
%token  <ID>	prev_declared_configuration_name_token

// %type  <leaf>	prev_declared_task_name
// %token  <ID>	prev_declared_task_name_token

%token CONFIGURATION
%token END_CONFIGURATION
%token TASK
%token RESOURCE
%token ON
%token END_RESOURCE
%token VAR_CONFIG
%token VAR_ACCESS
// %token END_VAR
%token WITH
// %token PROGRAM
// %token RETAIN
// %token NON_RETAIN
// %token PRIORITY
%token SINGLE
%token INTERVAL
%token READ_WRITE
%token READ_ONLY


/***********************************/
/* B 2.1 Instructions and Operands */
/***********************************/
%type  <list>	instruction_list
%type  <leaf>	il_instruction
%type  <leaf>	il_incomplete_instruction
%type  <leaf>	label
%type  <leaf>	il_simple_operation
// helper symbol for il_simple_operation
//%type <tmp_symbol> il_simple_operator_clash_il_operand
%type  <leaf>	il_expression
%type  <leaf>	il_jump_operation
%type  <leaf>	il_fb_call
%type  <leaf>	il_formal_funct_call
// helper symbol for il_formal_funct_call
%type  <leaf> il_expr_operator_clash_eol_list
%type  <leaf>	il_operand
%type  <list>	il_operand_list
// helper symbol for il_simple_operation
%type  <list>	il_operand_list2
%type  <list>	simple_instr_list
%type  <leaf>	il_simple_instruction
%type  <list>	il_param_list
%type  <list>	il_param_instruction_list
%type  <leaf>	il_param_instruction
%type  <leaf>	il_param_last_instruction
%type  <leaf>	il_param_assignment
%type  <leaf>	il_param_out_assignment

%token EOL


/*******************/
/* B 2.2 Operators */
/*******************/
%token <ID>	sendto_identifier_token
%type  <leaf>	sendto_identifier

%type  <leaf>	LD_operator
%type  <leaf>	LDN_operator
%type  <leaf>	ST_operator
%type  <leaf>	STN_operator
%type  <leaf>	NOT_operator
%type  <leaf>	S_operator
%type  <leaf>	R_operator
%type  <leaf>	S1_operator
%type  <leaf>	R1_operator
%type  <leaf>	CLK_operator
%type  <leaf>	CU_operator
%type  <leaf>	CD_operator
%type  <leaf>	PV_operator
%type  <leaf>	IN_operator
%type  <leaf>	PT_operator
%type  <leaf>	AND_operator
%type  <leaf>	AND2_operator
%type  <leaf>	OR_operator
%type  <leaf>	XOR_operator
%type  <leaf>	ANDN_operator
%type  <leaf>	ANDN2_operator
%type  <leaf>	ORN_operator
%type  <leaf>	XORN_operator
%type  <leaf>	ADD_operator
%type  <leaf>	SUB_operator
%type  <leaf>	MUL_operator
%type  <leaf>	DIV_operator
%type  <leaf>	MOD_operator
%type  <leaf>	GT_operator
%type  <leaf>	GE_operator
%type  <leaf>	EQ_operator
%type  <leaf>	LT_operator
%type  <leaf>	LE_operator
%type  <leaf>	NE_operator
%type  <leaf>	CAL_operator
%type  <leaf>	CALC_operator
%type  <leaf>	CALCN_operator
%type  <leaf>	RET_operator
%type  <leaf>	RETC_operator
%type  <leaf>	RETCN_operator
%type  <leaf>	JMP_operator
%type  <leaf>	JMPC_operator
%type  <leaf>	JMPCN_operator

%type  <leaf>	il_simple_operator
%type  <leaf>	il_simple_operator_clash
%type  <leaf>	il_simple_operator_clash1
%type  <leaf>	il_simple_operator_clash2
%type  <leaf>	il_simple_operator_clash3
%type  <leaf>	il_simple_operator_noclash

//%type  <leaf>	il_expr_operator
%type  <leaf>	il_expr_operator_clash
%type  <leaf>	il_expr_operator_noclash

%type  <leaf>	il_assign_operator
%type  <leaf>	il_assign_out_operator
%type  <leaf>	il_call_operator
%type  <leaf>	il_return_operator
%type  <leaf>	il_jump_operator


%token LD
%token LDN
%token ST
%token STN
%token NOT
%token S
%token R
%token S1
%token R1
%token CLK
%token CU
%token CD
%token PV
%token IN
%token PT
%token AND
%token AND2  /* character '&' in the source code*/
%token OR
%token XOR
%token ANDN
%token ANDN2 /* characters '&N' in the source code */
%token ORN
%token XORN
%token ADD
%token SUB
%token MUL
%token DIV
%token MOD
%token GT
%token GE
%token EQ
%token LT
%token LE
%token NE
%token CAL
%token CALC
%token CALCN
%token RET
%token RETC
%token RETCN
%token JMP
%token JMPC
%token JMPCN

%token SENDTO   /* "=>" */


/***********************/
/* B 3.1 - Expressions */
/***********************/
/* NOTE:
 *
 *    - unary_operator, multiply_operator,
 *      add_operator and comparison_operator
 *      are not required. Their values are integrated
 *      directly into other rules...
 */
%type  <leaf>	  ref_expression  /* an extension to the IEC 61131-3 v2 standard, based on the IEC 61131-3 v3 standard */ 
%type  <leaf>	deref_expression  /* an extension to the IEC 61131-3 v2 standard, based on the IEC 61131-3 v3 standard */ 
%type  <leaf>	expression
%type  <leaf>	xor_expression
%type  <leaf>	and_expression
%type  <leaf>	comparison
%type  <leaf>	equ_expression
// %type  <leaf>	comparison_operator
%type  <leaf>	add_expression
// %type  <leaf>	add_operator
%type  <leaf>	term
// %type  <leaf>	multiply_operator
%type  <leaf>	power_expression
%type  <leaf>	unary_expression
// %type  <leaf>	unary_operator
%type  <leaf>	primary_expression
%type  <leaf>	non_int_or_real_primary_expression
/* intermediate helper symbol for primary_expression */
%type  <leaf>	function_invocation

// %token AND
// %token XOR
// %token OR
// %token MOD
// %token NOT
%token OPER_NE
%token OPER_GE
%token OPER_LE
%token OPER_EXP


/********************/
/* B 3.2 Statements */
/********************/
%type <list> statement_list
%type <leaf> statement



/*********************************/
/* B 3.2.1 Assignment Statements */
/*********************************/
%type <leaf> assignment_statement
// %token ASSIGN   /* ":=" */


/*****************************************/
/* B 3.2.2 Subprogram Control Statements */
/*****************************************/
%type <leaf>	subprogram_control_statement
%type <leaf>	return_statement
%type <leaf>	fb_invocation
// %type <leaf>	param_assignment
%type <leaf>	param_assignment_formal
%type <leaf>	param_assignment_nonformal
/* helper symbols for fb_invocation */
%type <list> param_assignment_formal_list
%type <list> param_assignment_nonformal_list

// %token ASSIGN
// %token SENDTO   /* "=>" */
%token RETURN


/********************************/
/* B 3.2.3 Selection Statements */
/********************************/
%type <leaf>	selection_statement
%type <leaf>	if_statement
%type <leaf>	case_statement
%type <leaf>	case_element
%type <list>	case_list
%type <leaf>	case_list_element
/* helper symbol for if_statement */
%type <list>	elseif_statement_list
/* helper symbol for elseif_statement_list */
%type <leaf>	elseif_statement
/* helper symbol for case_statement */
%type <list>	case_element_list

%token IF
%token THEN
%token ELSIF
%token ELSE
%token END_IF

%token CASE
// %token OF
// %token ELSE
%token END_CASE



/********************************/
/* B 3.2.4 Iteration Statements */
/********************************/
%type <leaf>	iteration_statement
%type <leaf>	for_statement
%type <leaf>	control_variable
%type <leaf>	while_statement
%type <leaf>	repeat_statement
%type <leaf>	exit_statement
/* Integrated directly into for_statement */
// %type <leaf>	for_list

%token FOR
// %token ASSIGN
// %token TO
%token BY
%token DO
%token END_FOR

%token WHILE
// %token DO
%token END_WHILE

%token REPEAT
%token UNTIL
%token END_REPEAT

%token EXIT

%%


/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/
/********************************************************/

start:
  library	{$$ = $1;}
;


/**********************************************************************************/
/* B XXX - Things that are missing from the standard, but should have been there! */
/**********************************************************************************/


/* the pragmas... */


disable_code_generation_pragma:
  disable_code_generation_pragma_token	{$$ = new disable_code_generation_pragma_c(locloc(@$));}

enable_code_generation_pragma:
  enable_code_generation_pragma_token	{$$ = new enable_code_generation_pragma_c(locloc(@$));}

pragma:
  pragma_token	{$$ = new pragma_c($1, locloc(@$));}

any_pragma:
  disable_code_generation_pragma
| enable_code_generation_pragma
| pragma
;


/* EN/ENO */
/* Tese tokens are essentially used as variable names, so we handle them 
 * similarly to these...
 */
en_identifier:
  EN	{$$ = new identifier_c("EN", locloc(@$));}
;

eno_identifier:
  ENO	{$$ = new identifier_c("ENO", locloc(@$));}
;



/*************************************/
/* Prelimenary helpful constructs... */
/*************************************/

/* NOTE:
 *       short version:
 *       identifier is used for previously undeclared identifiers
 *       any_identifier is used when any identifier, previously
 *       declared or not, is required in the syntax.
 *
 *       long version:
 *       When flex comes across an identifier, it first
 *       searches through the currently declared variables,
 *       functions, types, etc... to determine if it has
 *       been previously declared.
 *       Only if the identifier has not yet been declared
 *       will it return an identifier_token (later turned into
 *       an identifier symbol by the bison generated syntax parser).
 *
 *       Some constructs in the syntax, such as when calling
 *       a function 'F(var1 := 1; var2 := 2);', will accept _any_
 *       identifier in 'var1', even if it has been previously
 *       declared in the current scope, since var1 belongs to
 *       another scope (the variables declared in function F).
 *
 *       For the above reason, we need to define the symbol
 *       any_identifier. All the symbols that may become an
 *       any_identifier are expected to be stored in the
 *       abstract syntax as a identifier_c
 */
/* NOTE:
 *  Type names, function names, function block type names and
 *  program type names are considerd keywords once they are defined,
 *  so may no longer be used for variable names!
 *  BUT the spec is confusing on this issue, as it is not clear when
 *  a function name should be considered as defined. If it is to be
 *  considered defined only from the location from where it is declared
 *  and onwards, it means that before it is declared its name may be
 *  used for variable names!
 *  This means that we must allow names previously used for functions
 *  (et. al.) to also constitue an any_identifier!
 */
any_identifier:
  identifier
| prev_declared_fb_name
| prev_declared_variable_name
/**/
    /* ref_type_name is defined in IEC 61131-3 v3 */
| prev_declared_ref_type_name               {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_simple_type_name            {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_subrange_type_name          {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_enumerated_type_name        {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_array_type_name             {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_structure_type_name         {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_string_type_name            {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_derived_function_name       {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the          poutype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_derived_function_block_name {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the          poutype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
| prev_declared_program_type_name           {$$ = new identifier_c(((token_c *)$1)->value, locloc(@$));}; // change the          poutype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
/**/
| prev_declared_resource_name
| prev_declared_program_name
| prev_declared_global_var_name
;

/* NOTE: Notice that the symbol classes:
 *            - derived_datatype_identifier_c
 *            - poutype_identifier_c
 *       are only inserted into the AST when referencing a derived dataype or a POU
 *       (e.g. when declaring a variable, making a function call, instantiating a program in a resource,
 *        or delaring a derived datatype that derives from another previously delcared datatype).
 *
 *       In the declaration of the datatype or POU itself, the name of the datatype or POU will be stored
 *       inside an identifier_c instead!!
 */
prev_declared_variable_name:        prev_declared_variable_name_token        {$$ = new identifier_c($1, locloc(@$));};
prev_declared_fb_name:              prev_declared_fb_name_token              {$$ = new identifier_c($1, locloc(@$));};

prev_declared_simple_type_name:     prev_declared_simple_type_name_token     {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_subrange_type_name:   prev_declared_subrange_type_name_token   {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_enumerated_type_name: prev_declared_enumerated_type_name_token {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_array_type_name:      prev_declared_array_type_name_token      {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_structure_type_name:  prev_declared_structure_type_name_token  {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_string_type_name:     prev_declared_string_type_name_token     {$$ = new derived_datatype_identifier_c($1, locloc(@$));};
prev_declared_ref_type_name:        prev_declared_ref_type_name_token        {$$ = new derived_datatype_identifier_c($1, locloc(@$));};  /* defined in IEC 61131-3 v3 */

prev_declared_derived_function_name:       prev_declared_derived_function_name_token       {$$ = new poutype_identifier_c($1, locloc(@$));};
prev_declared_derived_function_block_name: prev_declared_derived_function_block_name_token {$$ = new poutype_identifier_c($1, locloc(@$));};
prev_declared_program_type_name:           prev_declared_program_type_name_token           {$$ = new poutype_identifier_c($1, locloc(@$));};
/* NOTE: The poutype_identifier_c was introduced to allow the implementation of remove_forward_dependencies_c */




/***************************/
/* B 0 - Programming Model */
/***************************/
library:
  /* empty */
	{ $$ = parser->root(); }
| library library_element_declaration
	{$$ = $1; $$->add_element($2);}
| library any_pragma
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| library error library_element_declaration
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unknown syntax error."); yyerrok;}
| library error END_OF_INPUT
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unknown syntax error."); yyerrok;}
/* ERROR_CHECK_END */
;


library_element_declaration:
  data_type_declaration
| function_declaration
| function_block_declaration
| program_declaration
| configuration_declaration
;



/*******************************************/
/* B 1.1 - Letters, digits and identifiers */
/*******************************************/
/* NOTE: the spec defines identifier as:
 *         identifier ::= (letter|('_' (letter|digit))) {['_'] (letter|digit)}
 *       In essence, any sequence of letters or digits, starting with a letter
 *       or '_'.
 *
 *       On section 2.1.3 (pg 26) , the spec states
 *       "The keywords listed in annex C shall not be used for any other purpose,
 *         e.g., variable names or extensions as defined in 1.5.1."
 *       (NOTE: the spec itself does not follow this rule, as it defines standard
 *       functions with names identidal to keywords, e.g. 'MOD', 'NOT' !!. This is
 *       another issue altogether, and is worked around somewhere else...)
 *
 *       This means that we must re-define indentifier so as to exclude
 *       any keywords defined in annex C.
 *
 *       Note also that the list includes
 *          - Data type names
 *          - Function names
 *          - Function Block names
 *       This means that any named used for a function name, data type name
 *       or function block name, essentially becomes a keyword, and may therefore
 *       no longer be re-used for any other use! (see NOTE 2)
 *
 *       In our case, excluding the keywords is achieved in the lexical parser,
 *       by two mechanisms:
 *         (1) giving higher priority to the keywords (tokens) than to identifiers,
 *             so when the lexical parser finds a keyword it will be parsed as a
 *             token before being parsed as an identifier.
 *         (2) when an identifier is found that is not a keyword, the lexical parser
 *             then looks in the global symbol table, and will not return an identifier
 *             if the name has been previously used as a data type name, function name,
 *             or function block name! (In these cases it will return a
 *             prev_declared_function_name_token, etc...).
 *
 *       Unfortunately, the language (especially IL) uses tokens that are
 *       not defined as keywords in the spec (e.g. 'IN', 'R1', 'S1', 'PT', etc...)!
 *       This means that it is valid to name a function 'IN', a variable 'PT', etc...
 *       In order to solve this potential ambiguity, flex only parses the above 
 *       identifiers as keywords / tokens if we are currently parsing IL code.
 *       When parsing all code other than IL code, the above identifiers are treated
 *       just like any other identifier.
 *
 *
 *
 *
 * NOTE 2:
 *         I (Mario) find it strange that the writers of the spec really want
 *         names previously used for function names, data type names or function
 *         block names, to become full fledged keywords. I understand that they
 *         do not want these names being used as variable names, but how about
 *         enumeration values? How about structure element names?
 *         If we interpret the spec literally, these would not be accepted,
 *         which would probably burden the programmer quite a bit, in making sure
 *         all these name don't clash!
 *
 *
 *
 * NOTE 3: The keywords, as specified in Annex C are...
 *
 *          - Data type names
 *          - Function names
 *          - Function Block names
 *          - ACTION...END_ACTION
 *          - ARRAY...OF
 *          - AT
 *          - CASE...OF...ELSE...END_CASE
 *          - CONFIGURATION...END_CONFIGURATION
 *          - CONSTANT
 *          - EN, ENO
 *          - EXIT
 *          - FALSE
 *          - F_EDGE
 *          - FOR...TO...BY...DO...END_FOR
 *          - FUNCTION...END_FUNCTION
 *          - FUNCTION_BLOCK...END_FUNCTION_BLOCK
 *          - IF...THEN...ELSIF...ELSE...END_IF
 *          - INITIAL_STEP...END_STEP
 *          - NOT, MOD, AND, XOR, OR
 *          - PROGRAM...WITH...
 *          - PROGRAM...END_PROGRAM
 *          - R_EDGE
 *          - READ_ONLY, READ_WRITE
 *          - REPEAT...UNTIL...END_REPEAT
 *          - RESOURCE...ON...END_RESOURCE
 *          - RETAIN, NON_RETAIN
 *          - RETURN
 *          - STEP...END_STEP
 *          - STRUCT...END_STRUCT
 *          - TASK
 *          - TRANSITION...FROM...TO...END_TRANSITION
 *          - TRUE
 *          - TYPE...END_TYPE
 *          - VAR...END_VAR
 *          - VAR_INPUT...END_VAR
 *          - VAR_OUTPUT...END_VAR
 *          - VAR_IN_OUT...END_VAR
 *          - VAR_TEMP...END_VAR
 *          - VAR_EXTERNAL...END_VAR
 *          - VAR_ACCESS...END_VAR
 *          - VAR_CONFIG...END_VAR
 *          - VAR_GLOBAL...END_VAR
 *          - WHILE...DO...END_WHILE
 *          - WITH
 */

identifier:
  identifier_token	{$$ = new identifier_c($1, locloc(@$));}
;



/*********************/
/* B 1.2 - Constants */
/*********************/
constant:
  character_string
| time_literal
| bit_string_literal
| boolean_literal
| numeric_literal  
/* NOTE: Our definition of numeric_literal is diferent than the one in the standard.
 *       We will now add what is missing in our definition of numeric literal, so our
 *       definition of constant matches what the definition of constant in the standard.
 */
/* NOTE: in order to remove reduce/reduce conflicts,
 * [between -9.5 being parsed as 
 *     (i)   a signed real, 
 *     (ii)  or as a real preceded by the '-' operator
 *  ]
 *  we need to define a variant of the constant construct
 *  where any real or integer constant is always preceded by 
 *  a sign (i.e. the '-' or '+' characters).
 *  (For more info, see comment in the construct non_int_or_real_primary_expression)
 *
 * For the above reason, our definition of the numeric_literal construct
 * is missing the integer and real constrcuts (when not preceded by a sign)
 * so we add then here explicitly!
 */
| real
| integer
/* NOTE: unsigned_integer, although used in some
 * rules, is not defined in the spec!
 * We therefore replaced unsigned_integer as integer
 */
| ref_value_null_literal /* defined in IEC 61131-3 v3. Basically the 'NULL' keyword! */
;




non_int_or_real_constant:
  character_string
| time_literal
| bit_string_literal
| boolean_literal
| numeric_literal  
/* NOTE: Our definition of numeric_literal is diferent than the one in the standard.
 *       It is missing the integer and real when not prefixed by a sign 
 *       (i.e. -54, +42 is included in numerical_literal,
 *        but   54,  42 is not parsed as a numeric_literal!!)
 */
/* NOTE: in order to remove reduce/reduce conflicts,
 * [between -9.5 being parsed as 
 *     (i)   a signed real, 
 *     (ii)  or as a real preceded by the '-' operator
 *  ]
 * [and a similar situation for integers!]
 *  we need to define a variant of the constant construct
 *  where any real or integer constant is always preceded by 
 *  a sign (i.e. the '-' or '+' characters).
 *
 * For the above reason, our definition of the numeric_literal construct
 * is missing the integer and real constrcuts (when not preceded by a sign)
 */
;

/*********************************/
/* B 1.2.XX - Reference Literals */
/*********************************/
/* NOTE: The following syntax was added by MJS in order to add support for the NULL keyword, defined in  IEC 61131-3 v3
 *       Please read the comment where the 'ref_value_null_literal' is declared as a <leaf> 
 */
/* defined in IEC 61131-3 v3 - Basically the 'NULL' keyword! */
ref_value_null_literal: 
  NULL_token	{$$ = new ref_value_null_literal_c(locloc(@$));}
;

/******************************/
/* B 1.2.1 - Numeric Literals */
/******************************/
/* NOTES:
 *
 *    - integer is parsed by flex, but signed_integer
 *      is parsed by bison. Flex cannot parse a signed
 *      integer correctly!  For example: '123+456'
 *      would be parsed by flex as an {integer} {signed_integer}
 *      instead of {integer} '+' {integer}
 *
 *    - Neither flex nor bison can parse a real_literal
 *      completely (and correctly).
 *      Note that we cannot use the definition of real in bison as
 *      real: signed_integer '.' integer [exponent]
 *      exponent: {'E'|'e'} ['+'|'-'] integer
 *      because 123e45 would be parsed by flex as
 *      integer (123) identifier (e45).
 *      I.e., flex never hands over an 'e' directly to
 *      bison, but rather interprets it as an identifier.
 *      I guess we could jump through hoops and get it
 *      working in bison, but the following alternative
 *      seems more straight forward...
 *
 *      We therefore had to break up the definition of
 *      real_literal in discrete parts:
 *      real_literal: [real_type_name '#'] singned_real
 *      signed_real: ['+'|'-'] real
 *      Flex handles real, while bison handles signed_real
 *      and real_literal.
 *
 *    - According to the spec, integer '.' integer
 *      may be reduced to either a real or a fixed_point.
 *      It is nevertheless possible to figure out from the
 *      context which of the two rules should be used in
 *      the reduction.
 *      Unfortunately, due to the issue described above
 *      regarding the exponent of a real, the syntax
 *      integer '.' integer
 *      must be parsed by flex as a single token (i.e.
 *      fixed_point_token). This means we must add fixed_point
 *      to the definition of real!
 *
 *    - The syntax also uses a construct
 *        fixed_point: integer ['.' integer]
 *      Notice that real is not defined based on fixed point,
 *      but rather off integer thus:
 *        real: integer '.' integer [exponent]
 *      This means that a real may not be composed of a single
 *      integer, unlike the construct fixed_point!
 *      This also means that a
 *        integer '.' integer
 *      could be reduced to either a real or a fixed_point
 *      construct. It is probably possible to decide by looking
 *      at the context, BUT:
 *       Unfortunatley, due to the reasons explained way above,
 *      a real (with an exponent) has to be handled by flex as a
 *      whole. This means that we cannot leave to bison (the syntax
 *      parser) the decision of how to reduce an
 *        integer '.' integer
 *      (either to real or to fixed_point)
 *      The decision on how to reduce it would need to be done by
 *      ther lexical analyser (i.e. flex). But flex cannot do this
 *      sort of thing.
 *      The solution I (Mario) adopted is to have flex return
 *      a real_token on (notice that exponent is no longer optional)
 *        integer '.' integer exponent
 *      and to return a fixed_point_token when it finds
 *        integer '.' integer
 *      We now redefine real and fixed_point to be
 *        fixed_point: fixed_point_token | integer
 *        real: real_token | fixed_point_token
 */
real:
  real_token		{$$ = new real_c($1, locloc(@$));}
| fixed_point_token	{$$ = new real_c($1, locloc(@$));}
;

integer:	integer_token		{$$ = new integer_c($1, locloc(@$));};
binary_integer:	binary_integer_token	{$$ = new binary_integer_c($1, locloc(@$));};
octal_integer:	octal_integer_token	{$$ = new octal_integer_c($1, locloc(@$));};
hex_integer:	hex_integer_token	{$$ = new hex_integer_c($1, locloc(@$));};

numeric_literal:
  integer_literal
| real_literal
;


integer_literal:
  integer_type_name '#' signed_integer
	{$$ = new integer_literal_c($1, $3, locloc(@$));}
| integer_type_name '#' binary_integer
	{$$ = new integer_literal_c($1, $3, locloc(@$));}
| integer_type_name '#' octal_integer
	{$$ = new integer_literal_c($1, $3, locloc(@$));}
| integer_type_name '#' hex_integer
	{$$ = new integer_literal_c($1, $3, locloc(@$));}
| binary_integer
| octal_integer
| hex_integer
//|signed_integer  /* We expand the construct signed_integer here, so we can remove one of its constituents */
//|  integer       /* REMOVED! see note in the definition of constant for reason why integer is missing here! */
| '+' integer   {$$ = $2;}
| '-' integer	{$$ = new neg_integer_c($2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| integer_type_name signed_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between integer type name and value in integer literal."); yynerrs++;}
| integer_type_name binary_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between integer type name and value in integer literal."); yynerrs++;}
| integer_type_name octal_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between integer type name and value in integer literal."); yynerrs++;}
| integer_type_name hex_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between integer type name and value in integer literal."); yynerrs++;}
| integer_type_name '#' error
	{$$ = NULL; 
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for integer literal.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for integer literal."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* NOTE: this construct is used in the definition of integer_literal. However, in order to remove
 *       a reduce/reduce conflict (see NOTE in definition of constant for reason why)
 *       it is not used directly, but rather its expansion is copied there.
 *
 *       If for some reason you need to change the definition of signed_integer, don't forget
 *       to change its expansion in integer_literal too!
*/
signed_integer:
  integer
| '+' integer   {$$ = $2;}
| '-' integer	{$$ = new neg_integer_c($2, locloc(@$));}
;


real_literal:
// signed_real /* We expand the construct signed_integer here, so we can remove one of its constituents */
// real        /* REMOVED! see note in the definition of constant for reason why real is missing here! */
  '+' real	{$$ = $2;}
| '-' real	{$$ = new neg_real_c($2, locloc(@2));}
| real_type_name '#' signed_real
	{$$ = new real_literal_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| real_type_name signed_real
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between real type name and value in real literal."); yynerrs++;}
| real_type_name '#' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for real literal.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for real literal."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* NOTE: this construct is used in the definition of real_literal. However, in order to remove
 *       a reduce/reduce conflict (see NOTE in definition of constant for reason why)
 *       it is not used directly, but rather its expansion is copied there.
 *
 *       If for some reason you need to change the definition of signed_real, don't forget
 *       to change its expansion in real_literal too!
*/
signed_real:
  real
| '+' real	{$$ = $2;}
| '-' real	{$$ = new neg_real_c($2, locloc(@2));}
;


bit_string_literal:
  bit_string_type_name '#' integer  /* i.e. unsigned_integer */
	{$$ = new bit_string_literal_c($1, $3, locloc(@$));}
| bit_string_type_name '#' binary_integer
	{$$ = new bit_string_literal_c($1, $3, locloc(@$));}
| bit_string_type_name '#' octal_integer
	{$$ = new bit_string_literal_c($1, $3, locloc(@$));}
| bit_string_type_name '#' hex_integer
	{$$ = new bit_string_literal_c($1, $3, locloc(@$));}
/* NOTE: see note in the definition of constant for reason
 * why unsigned_integer, binary_integer, octal_integer
 * and hex_integer are missing here!
 */
/* NOTE: see note under the B 1.2.1 section of token
 * and grouping type definition for reason why the use of
 * bit_string_type_name, although seemingly incorrect, is
 * really correct here!
 */
/* ERROR_CHECK_BEGIN */
| bit_string_type_name integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between bit string type name and value in bit string literal."); yynerrs++;}
| bit_string_type_name binary_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between bit string type name and value in bit string literal."); yynerrs++;}
| bit_string_type_name octal_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between bit string type name and value in bit string literal."); yynerrs++;}
| bit_string_type_name hex_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between bit string type name and value in bit string literal."); yynerrs++;}
| bit_string_type_name '#' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for bit string literal.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for bit string literal."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


boolean_literal:
  boolean_true_literal_token
	{$$ = new boolean_literal_c(new bool_type_name_c(locloc(@$)),
				    new boolean_true_c(locloc(@$)),
				    locloc(@$));
	}
| boolean_false_literal_token
	{$$ = new boolean_literal_c(new bool_type_name_c(locloc(@$)),
				    new boolean_false_c(locloc(@$)),
				    locloc(@$));
	}
| safeboolean_true_literal_token
	{$$ = new boolean_literal_c(new safebool_type_name_c(locloc(@$)),
				    new boolean_true_c(locloc(@$)),
				    locloc(@$));
	}
| safeboolean_false_literal_token
	{$$ = new boolean_literal_c(new safebool_type_name_c(locloc(@$)),
				    new boolean_false_c(locloc(@$)),
				    locloc(@$));
	}
| FALSE
	{$$ = new boolean_literal_c(NULL,
				    new boolean_false_c(locloc(@$)),
				    locloc(@$));
	}
| TRUE
	{$$ = new boolean_literal_c(NULL,
				    new boolean_true_c(locloc(@$)),
				    locloc(@$));
	}
/*
|	BOOL '#' '1' {}
|	BOOL '#' '0' {}
*/
/* NOTE: the rules
 * BOOL '#' '1'
 * and
 * BOOL '#' '0'
 * do not work as expected...
 * Consider that we are using 'BOOL' and '#' as tokens
 * that flex hands over to bison (yacc). Because flex would
 * then parse the single '1' or '0' as an integer,
 * the rule in bison would have to be
 * BOOL '#' integer, followed by verifying of the
 * integer has the correct value!
 *
 * We therefore have flex return TRUE whenever it
 * comes across 'TRUE' or 'BOOL#1', and FALSE whenever
 * it comes across 'FALSE' or 'BOOL#0'.
 * Note that this means that flex will parse "BOOL#01"
 * as FALSE followed by an integer ('1').
 * Bison should detect this as an error, so we should
 * be OK.
 *
 * Another option would be to change the rules to accept
 * BOOL '#' integer
 * but then check whether the integer has a correct
 * value! At the moment I feel that the first option
 * is more straight forward.
 */
;



/*******************************/
/* B 1.2.2 - Character Strings */
/*******************************/
/* Transform the tokens given us by flex into leafs */
single_byte_character_string:	single_byte_character_string_token
	{$$ = new single_byte_character_string_c($1, locloc(@$));};

double_byte_character_string:	double_byte_character_string_token
	{$$ = new double_byte_character_string_c($1, locloc(@$));};


character_string:
  single_byte_character_string
| double_byte_character_string
;





/***************************/
/* B 1.2.3 - Time Literals */
/***************************/
time_literal:
  time_of_day
| date
| date_and_time
| duration
;


/************************/
/* B 1.2.3.1 - Duration */
/************************/
duration:
/*  (T | TIME) '#' ['-'] interval */
/* NOTE: since TIME is also a data type, it is a keyword
 *       and may therefore be handled by a token.
 *
 *       Unfortunately T is not a data type, and therefore
 *       not a keyword. This means that we may have variables named T!
 *       Flex cannot return the token TIME when it comes across a single T!
 *
 *       We therefore have flex returning the token T_SHARP
 *       when it comes across 'T#'
 */
  TIME '#' interval
	{$$ = new duration_c(new time_type_name_c(locloc(@1)), NULL, $3, locloc(@$));}
| TIME '#' '-' interval
	{$$ = new duration_c(new time_type_name_c(locloc(@1)), new neg_time_c(locloc(@$)), $4, locloc(@$));}
| T_SHARP interval
	{$$ = new duration_c(new time_type_name_c(locloc(@1)), NULL, $2, locloc(@$));}
| T_SHARP '-' interval
	{$$ = new duration_c(new time_type_name_c(locloc(@1)), new neg_time_c(locloc(@$)), $3, locloc(@$));}
| SAFETIME '#' interval
	{$$ = new duration_c(new safetime_type_name_c(locloc(@1)), NULL, $3, locloc(@$));}
| SAFETIME '#' '-' interval
	{$$ = new duration_c(new safetime_type_name_c(locloc(@1)), new neg_time_c(locloc(@$)), $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| TIME interval
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between 'TIME' and interval in duration."); yynerrs++;}
| TIME '-' interval
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between 'TIME' and interval in duration."); yynerrs++;}
| TIME '#' erroneous_interval_token
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid value for duration."); yynerrs++;}
| T_SHARP erroneous_interval_token
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid value for duration."); yynerrs++;}
| TIME '#' '-' erroneous_interval_token
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid value for duration."); yynerrs++;}
| T_SHARP '-' erroneous_interval_token
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid value for duration."); yynerrs++;}
/* ERROR_CHECK_END */
;

fixed_point:
  integer
| fixed_point_token	{$$ = new fixed_point_c($1, locloc(@$));};


interval:
  days hours minutes seconds milliseconds end_interval_token
	{$$ = new interval_c($1, $2, $3, $4, $5, locloc(@$));};
;


days:   /*  fixed_point ('d') */
  /* empty */		{$$ = NULL;}
| fixed_point_d_token	{$$ = new fixed_point_c($1, locloc(@$));};
| integer_d_token	{$$ = new integer_c($1, locloc(@$));};
;

hours:  /*  fixed_point ('h') */
  /* empty */		{$$ = NULL;}
| fixed_point_h_token	{$$ = new fixed_point_c($1, locloc(@$));};
| integer_h_token	{$$ = new integer_c($1, locloc(@$));};
;

minutes: /*  fixed_point ('m') */
  /* empty */		{$$ = NULL;}
| fixed_point_m_token	{$$ = new fixed_point_c($1, locloc(@$));};
| integer_m_token	{$$ = new integer_c($1, locloc(@$));};
;

seconds: /*  fixed_point ('s') */
  /* empty */		{$$ = NULL;}
| fixed_point_s_token	{$$ = new fixed_point_c($1, locloc(@$));};
| integer_s_token	{$$ = new integer_c($1, locloc(@$));};
;

milliseconds: /*  fixed_point ('ms') */
  /* empty */		{$$ = NULL;}
| fixed_point_ms_token	{$$ = new fixed_point_c($1, locloc(@$));};
| integer_ms_token	{$$ = new integer_c($1, locloc(@$));};
;



/************************************/
/* B 1.2.3.2 - Time of day and Date */
/************************************/
time_of_day:
  TIME_OF_DAY '#' daytime
	{$$ = new time_of_day_c(new tod_type_name_c(locloc(@1)), $3, locloc(@$));}
| SAFETIME_OF_DAY '#' daytime
	{$$ = new time_of_day_c(new safetod_type_name_c(locloc(@1)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| TIME_OF_DAY daytime
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between 'TIME_OF_DAY' and daytime in time of day."); yynerrs++;}
| TIME_OF_DAY '#' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for time of day.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for time of day."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


daytime:
  day_hour ':' day_minute ':' day_second
	{$$ = new daytime_c($1, $3, $5, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| ':' day_minute ':' day_second
  {$$ = NULL; print_err_msg(locf(@1), locl(@4), "no value defined for hours in daytime."); yynerrs++;}
| error ':' day_minute ':' day_second
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid value defined for hours in daytime."); yyerrok;}
| day_hour day_minute ':' day_second
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between hours and minutes in daytime."); yynerrs++;}
| day_hour ':' ':' day_second
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no value defined for minutes in daytime."); yynerrs++;}
| day_hour ':' error ':' day_second
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid value defined for minutes in daytime."); yyerrok;}
| day_hour ':' day_minute day_second
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "':' missing between minutes and seconds in daytime."); yynerrs++;}
| day_hour ':' day_minute ':' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@4), locf(@5), "no value defined for seconds in daytime.");}
	 else {print_err_msg(locf(@5), locl(@5), "invalid value for seconds in daytime."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


day_hour: integer;
day_minute: integer;
day_second: fixed_point;


date:
  DATE '#' date_literal
	{$$ = new date_c(new date_type_name_c(locloc(@1)), $3, locloc(@$));}
| D_SHARP date_literal
	{$$ = new date_c(new date_type_name_c(locloc(@1)), $2, locloc(@$));}
| SAFEDATE '#' date_literal
	{$$ = new date_c(new safedate_type_name_c(locloc(@1)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| DATE date_literal
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between 'DATE' and date literal in date."); yynerrs++;}
| DATE '#' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for date.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for date."); yyclearin;}
	 yyerrok;
	}
| D_SHARP error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no value defined for date.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid value for date."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


date_literal:
  year '-' month '-' day
	{$$ = new date_literal_c($1, $3, $5, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| '-' month '-' day
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no value defined for year in date literal."); yynerrs++;}
| year month '-' day
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "'-' missing between year and month in date literal."); yynerrs++;}
| year '-' '-' day
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no value defined for month in date literal."); yynerrs++;}
| year '-' error '-' day
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid value defined for month in date literal."); yyerrok;}
| year '-' month day
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "'-' missing between month and day in date literal."); yynerrs++;}
| year '-' month '-' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@4), locf(@5), "no value defined for day in date literal.");}
	 else {print_err_msg(locf(@5), locl(@5), "invalid value for day in date literal."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


year: integer;
month: integer;
day: integer;


date_and_time:
  DATE_AND_TIME '#' date_literal '-' daytime
	{$$ = new date_and_time_c(new dt_type_name_c(locloc(@1)), $3, $5, locloc(@$));}
| SAFEDATE_AND_TIME '#' date_literal '-' daytime
	{$$ = new date_and_time_c(new safedt_type_name_c(locloc(@1)), $3, $5, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| DATE_AND_TIME date_literal '-' daytime
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between 'DATE_AND_TIME' and date literal in date and time."); yynerrs++;}
| DATE_AND_TIME '#' '-' daytime
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no value defined for date literal in date and time."); yynerrs++;}
| DATE_AND_TIME '#' error '-' daytime
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid value for date literal in date and time."); yyerrok;}
| DATE_AND_TIME '#' date_literal daytime
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "'-' missing between date literal and daytime in date and time."); yynerrs++;}
| DATE_AND_TIME '#' date_literal '-' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@4), locf(@5), "no value defined for daytime in date and time.");}
	 else {print_err_msg(locf(@5), locl(@5), "invalid value for daytime in date and time."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;






/**********************/
/* B 1.3 - Data Types */
/**********************/
/* Strangely, the following symbol does seem to be required! */
/*
data_type_name:
  non_generic_type_name
| generic_type_name
;
*/

non_generic_type_name:
  elementary_type_name
| derived_type_name
;



/***********************************/
/* B 1.3.1 - Elementary Data Types */
/***********************************/
    /******************************************************/
    /* SAFExxxx Symbols defined in                        */
    /* "Safety Software Technical Specification,          */
    /*  Part 1: Concepts and Function Blocks,             */
    /*  Version 1.0 – Official Release"                   */
    /* by PLCopen - Technical Committee 5 - 2006-01-31    */
    /******************************************************/

elementary_type_name:
  numeric_type_name
| date_type_name
| bit_string_type_name
| elementary_string_type_name
| TIME		{$$ = new time_type_name_c(locloc(@$));}
| BOOL		{$$ = new bool_type_name_c(locloc(@$));}
/* NOTE: see note under the B 1.2.1 section of token
 * and grouping type definition for reason why BOOL
 * was added to this definition.
 */
| SAFETIME	{$$ = new safetime_type_name_c(locloc(@$));}
| SAFEBOOL	{$$ = new safebool_type_name_c(locloc(@$));}
;

numeric_type_name:
  integer_type_name
| real_type_name
;

integer_type_name:
  signed_integer_type_name
| unsigned_integer_type_name
;

signed_integer_type_name:
  SINT		{$$ = new sint_type_name_c(locloc(@$));}
| INT		{$$ = new int_type_name_c(locloc(@$));}
| DINT		{$$ = new dint_type_name_c(locloc(@$));}
| LINT		{$$ = new lint_type_name_c(locloc(@$));}
| SAFESINT	{$$ = new safesint_type_name_c(locloc(@$));}
| SAFEINT	{$$ = new safeint_type_name_c(locloc(@$));}
| SAFEDINT	{$$ = new safedint_type_name_c(locloc(@$));}
| SAFELINT	{$$ = new safelint_type_name_c(locloc(@$));}
;

unsigned_integer_type_name:
  USINT		{$$ = new usint_type_name_c(locloc(@$));}
| UINT		{$$ = new uint_type_name_c(locloc(@$));}
| UDINT		{$$ = new udint_type_name_c(locloc(@$));}
| ULINT		{$$ = new ulint_type_name_c(locloc(@$));}
| SAFEUSINT	{$$ = new safeusint_type_name_c(locloc(@$));}
| SAFEUINT	{$$ = new safeuint_type_name_c(locloc(@$));}
| SAFEUDINT	{$$ = new safeudint_type_name_c(locloc(@$));}
| SAFEULINT	{$$ = new safeulint_type_name_c(locloc(@$));}
;

real_type_name:
  REAL		{$$ = new real_type_name_c(locloc(@$));}
| LREAL		{$$ = new lreal_type_name_c(locloc(@$));}
| SAFEREAL	{$$ = new safereal_type_name_c(locloc(@$));}
| SAFELREAL	{$$ = new safelreal_type_name_c(locloc(@$));}
;

date_type_name:
  DATE			{$$ = new date_type_name_c(locloc(@$));}
| TIME_OF_DAY		{$$ = new tod_type_name_c(locloc(@$));}
| TOD			{$$ = new tod_type_name_c(locloc(@$));}
| DATE_AND_TIME		{$$ = new dt_type_name_c(locloc(@$));}
| DT			{$$ = new dt_type_name_c(locloc(@$));}
| SAFEDATE		{$$ = new safedate_type_name_c(locloc(@$));}
| SAFETIME_OF_DAY	{$$ = new safetod_type_name_c(locloc(@$));}
| SAFETOD		{$$ = new safetod_type_name_c(locloc(@$));}
| SAFEDATE_AND_TIME	{$$ = new safedt_type_name_c(locloc(@$));}
| SAFEDT		{$$ = new safedt_type_name_c(locloc(@$));}
;


bit_string_type_name:
  BYTE		{$$ = new byte_type_name_c(locloc(@$));}
| WORD		{$$ = new word_type_name_c(locloc(@$));}
| DWORD		{$$ = new dword_type_name_c(locloc(@$));}
| LWORD		{$$ = new lword_type_name_c(locloc(@$));}
| SAFEBYTE	{$$ = new safebyte_type_name_c(locloc(@$));}
| SAFEWORD	{$$ = new safeword_type_name_c(locloc(@$));}
| SAFEDWORD	{$$ = new safedword_type_name_c(locloc(@$));}
| SAFELWORD	{$$ = new safelword_type_name_c(locloc(@$));}
/* NOTE: see note under the B 1.2.1 section of token
 * and grouping type definition for reason why the BOOL
 * was omitted from this definition.
 */
;


/* Helper symbol to concentrate the instantiation
 * of STRING and WSTRING into a single location.
 *
 * These two elements show up in several other rules,
 * but we want to create the equivalent abstract syntax
 * in a single location of this file, in order to make
 * possible future changes easier to edit...
 */
elementary_string_type_name:
  STRING	{$$ = new string_type_name_c(locloc(@$));}
| WSTRING	{$$ = new wstring_type_name_c(locloc(@$));}
| SAFESTRING	{$$ = new safestring_type_name_c(locloc(@$));}
| SAFEWSTRING	{$$ = new safewstring_type_name_c(locloc(@$));}
;



/********************************/
/* B 1.3.2 - Generic data types */
/********************************/
/* Strangely, the following symbol does not seem to be required! */
/*
generic_type_name:
  ANY
| ANY_DERIVED
| ANY_ELEMENTARY
| ANY_MAGNITUDE
| ANY_NUM
| ANY_REAL
| ANY_INT
| ANY_BIT
| ANY_STRING
| ANY_DATE
;
*/


/********************************/
/* B 1.3.3 - Derived data types */
/********************************/

derived_type_name:
  single_element_type_name
| prev_declared_array_type_name
| prev_declared_structure_type_name
| prev_declared_string_type_name
| prev_declared_ref_type_name  /* as defined in IEC 61131-3 v3 */
;

single_element_type_name:
  prev_declared_simple_type_name
/* Include the following if arrays of function blocks are to be allowed!
 * Since the standard does not allow them,
 * we leave it commented out for the time being...
 */
//| prev_declared_derived_function_block_name
| prev_declared_subrange_type_name
| prev_declared_enumerated_type_name
;

/* NOTE: in order to remove a reduce/reduce conflict,
 *       all occurences of simple_type_name, etc...
 *       have been replaced with identifier!
 */
/*
simple_type_name: identifier;
subrange_type_name: identifier;
enumerated_type_name: identifier;
array_type_name: identifier;
structure_type_name: identifier;
*/

data_type_declaration:
  TYPE type_declaration_list END_TYPE
	{$$ = new data_type_declaration_c($2, locloc(@$)); }
/* ERROR_CHECK_BEGIN */
| TYPE END_TYPE
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no data type declared in data type(s) declaration."); yynerrs++;}
| TYPE error type_declaration_list END_TYPE
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'TYPE' in data type(s) declaration."); yyerrok;}
| TYPE type_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed data type(s) declaration."); yyerrok;}
| TYPE error END_TYPE
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in data type(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for data_type_declaration */
type_declaration_list:
  type_declaration ';'
	{$$ = new type_declaration_list_c(locloc(@$)); $$->add_element($1);}
| type_declaration_list type_declaration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new type_declaration_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid data type declaration."); yyerrok;}
| type_declaration error
	{$$ = new type_declaration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of data type declaration."); yyerrok;}
| type_declaration_list type_declaration error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of data type declaration."); yyerrok;}
| type_declaration_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid data type declaration."); yyerrok;}
| type_declaration_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after data type declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;

type_declaration:
  single_element_type_declaration
| array_type_declaration
| structure_type_declaration
| string_type_declaration
;

single_element_type_declaration:
  simple_type_declaration
| subrange_type_declaration
| enumerated_type_declaration
| ref_type_decl  /* defined in IEC 61131-3 v3 */
;

simple_type_declaration:
/*  simple_type_name ':' simple_spec_init */
/* To understand why simple_spec_init was brocken up into its consituent components in the following rules, please see note in the definition of 'enumerated_type_declaration'. */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' simple_specification           {library_element_symtable.insert($1, prev_declared_simple_type_name_token);}
	{if (!get_preparse_state()) $$ = new simple_type_declaration_c($1, $3, locloc(@$));}
| identifier ':' elementary_type_name           {library_element_symtable.insert($1, prev_declared_simple_type_name_token);} ASSIGN constant
	{if (!get_preparse_state()) $$ = new simple_type_declaration_c($1, new simple_spec_init_c($3, $6, locf(@3), locl(@5)), locloc(@$));}
| identifier ':' prev_declared_simple_type_name {library_element_symtable.insert($1, prev_declared_simple_type_name_token);} ASSIGN constant
	{if (!get_preparse_state()) $$ = new simple_type_declaration_c($1, new simple_spec_init_c($3, $6, locf(@3), locl(@5)), locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_simple_type_name ':' simple_spec_init
	{$$ = new simple_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
/* These three rules can now be safely replaced by the original rule abvoe!! */
/*
| prev_declared_simple_type_name ':' simple_specification
	{$$ = new simple_type_declaration_c($1, $3, locloc(@$));}
| prev_declared_simple_type_name ':' elementary_type_name           ASSIGN constant
	{$$ = new simple_type_declaration_c($1, new simple_spec_init_c($3, $5, locf(@3), locl(@5)), locloc(@$));}
| prev_declared_simple_type_name ':' prev_declared_simple_type_name ASSIGN constant
	{$$ = new simple_type_declaration_c($1, new simple_spec_init_c($3, $5, locf(@3), locl(@5)), locloc(@$));}
*/
/* ERROR_CHECK_BEGIN */
| error ':' simple_spec_init
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid name defined for data type declaration.");yyerrok;}
| identifier simple_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between data type name and specification in simple type declaration."); yynerrs++;}
| identifier ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in data type declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in data type declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


simple_spec_init:
  simple_specification
  /* The following commented line was changed to the 
   * next two lines so that we wouldn't
   * have the first element of a simple_spec_init_c()
   * pointing to another simple_spec_init_c!
   */
/*
| simple_specification ASSIGN constant
	{$$ = new simple_spec_init_c($1, $3);}
*/
| elementary_type_name ASSIGN constant
	{$$ = new simple_spec_init_c($1, $3, locloc(@$));}
| prev_declared_simple_type_name ASSIGN constant
	{$$ = new simple_spec_init_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| elementary_type_name constant
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in specification with initialization."); yynerrs++;}
| prev_declared_simple_type_name constant
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in specification with initialization."); yynerrs++;}
| elementary_type_name ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in specification with initialization."); yyclearin;}
	 yyerrok;
	}
| prev_declared_simple_type_name ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in specification with initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* When converting to C/C++, we need to know whether
 * the elementary_type_name is being used in a variable
 * declaration or elsewhere (ex. declaration of a derived
 * type), so the abstract syntax has the elementary_type_name
 * wrapped inside a simple_spec_init_c.
 * The exact same thing occurs with prev_declared_simple_type_name.
 *
 * This is why in the definition of simple_spec_init,
 * simple_specification was brocken up into its
 * constituent components...
 */
simple_specification:
// elementary_type_name | simple_type_name
  elementary_type_name
	{$$ = new simple_spec_init_c($1, NULL, locloc(@$));}
| prev_declared_simple_type_name
	{$$ = new simple_spec_init_c($1, NULL, locloc(@$));}
;


subrange_type_declaration:
/*  subrange_type_name ':' subrange_spec_init */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' subrange_spec_init	{library_element_symtable.insert($1, prev_declared_subrange_type_name_token);}
	{if (!get_preparse_state()) $$ = new subrange_type_declaration_c($1, $3, locloc(@$));}  
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_subrange_type_name ':' subrange_spec_init
	{$$ = new subrange_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
/* ERROR_CHECK_BEGIN */
| error ':' subrange_spec_init
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid name defined for subrange type declaration."); yyerrok;}
| identifier subrange_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between data type name and specification in subrange type declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;

subrange_spec_init:
  subrange_specification
	{$$ = new subrange_spec_init_c($1, NULL, locloc(@$));}
| subrange_specification ASSIGN signed_integer
	{$$ = new subrange_spec_init_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| subrange_specification signed_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in subrange specification with initialization."); yynerrs++;}
| subrange_specification ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in subrange specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in subrange specification with initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

subrange_specification:
  integer_type_name '(' subrange ')'
	{$$ = new subrange_specification_c($1, $3, locloc(@$));}
| prev_declared_subrange_type_name
  {$$ = new subrange_specification_c($1, NULL, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| integer_type_name '(' ')'
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no subrange defined in subrange specification."); yynerrs++;}
| integer_type_name '(' error ')'
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid subrange defined in subrange specification."); yyerrok;}
| integer_type_name '(' subrange error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing after subrange defined in subrange specification."); yyerrok;}
/* ERROR_CHECK_END */
;


/* a non standard construct, used to allow the declaration of array subranges using a variable */
subrange_with_var:
  signed_integer DOTDOT signed_integer
	{$$ = new subrange_c($1, $3, locloc(@$));}
| any_identifier DOTDOT signed_integer
	{$$ = new subrange_c(new symbolic_constant_c($1, locloc(@1)), $3, locloc(@$));
	 if (!runtime_options.nonliteral_in_array_size) {
	   print_err_msg(locf(@1), locl(@1), "Use of variables in array size limits is not allowed in IEC 61131-3 (use -a option to activate support for this non-standard feature)."); 
	   yynerrs++;
	 }
	}
| signed_integer DOTDOT any_identifier
	{$$ = new subrange_c($1, new symbolic_constant_c($3, locloc(@3)), locloc(@$));
	 if (!runtime_options.nonliteral_in_array_size) {
	   print_err_msg(locf(@3), locl(@3), "Use of variables in array size limits is not allowed in IEC 61131-3 (use -a option to activate support for this non-standard feature)."); 
	   yynerrs++;
	 }
	}
| any_identifier DOTDOT any_identifier
	{$$ = new subrange_c(new symbolic_constant_c($1, locloc(@1)), new symbolic_constant_c($3, locloc(@3)), locloc(@$));
	 if (!runtime_options.nonliteral_in_array_size) {
	   print_err_msg(locf(@$), locl(@$), "Use of variables in array size limits is not allowed in IEC 61131-3 (use -a option to activate support for this non-standard feature)."); 
	   yynerrs++;
	 }
	}
/* ERROR_CHECK_BEGIN */
| signed_integer signed_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'..' missing between bounds in subrange definition."); yynerrs++;}
| signed_integer DOTDOT error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for upper bound in subrange definition.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for upper bound in subrange definition."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


subrange:
  signed_integer DOTDOT signed_integer
	{$$ = new subrange_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| signed_integer signed_integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'..' missing between bounds in subrange definition."); yynerrs++;}
| signed_integer DOTDOT error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for upper bound in subrange definition.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for upper bound in subrange definition."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


enumerated_type_declaration:
/*  enumerated_type_name ':' enumerated_spec_init */
/* NOTE: The 'identifier' used for the name of the new enumerated type is inserted early into the library_element_symtable so it may be used
 *       in defining the default initial value of this type, using the fully qualified enumerated constant syntax: type_name#enum_value
 *       In other words, this allows us to correclty parse the following IEC 61131-3 code:
 *           TYPE enum_t : (x1, x2, x3) := enum_t#x3; END_TYPE
 *                                         ^^^^^^^
 *
 *       However, we can only introduce it after we are sure we are parsing an enumerated_spec. For this reason, instead of using the
 *       symbol enumerated_spec_init in this rule, we decompose it here instead!
 *       
 *       If it were not for the above, we could use the rule
 *           identifier ':' enumerated_spec_init
 *       and include the library_element_symtable.insert(...) code in the rule actions!
 */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' enumerated_specification {library_element_symtable.insert($1, prev_declared_enumerated_type_name_token);}
	{if (!get_preparse_state()) $$ = new enumerated_type_declaration_c($1, new enumerated_spec_init_c($3, NULL, locloc(@3)), locloc(@$));}
| identifier ':' enumerated_specification {library_element_symtable.insert($1, prev_declared_enumerated_type_name_token);} ASSIGN enumerated_value
	{if (!get_preparse_state()) $$ = new enumerated_type_declaration_c($1, new enumerated_spec_init_c($3, $6, locf(@3), locl(@6)), locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
/* Since the enumerated type name is placed in the library_element_symtable during preparsing, we can now safely use the single rule: */
| prev_declared_enumerated_type_name ':' enumerated_spec_init 
	{$$ = new enumerated_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
  /* These two rules are equivalent to the above rule */
/*
| prev_declared_enumerated_type_name ':' enumerated_specification {library_element_symtable.insert($1, prev_declared_enumerated_type_name_token);}
	{$$ = new enumerated_type_declaration_c($1, new enumerated_spec_init_c($3, NULL, locloc(@3)), locloc(@$));}
| prev_declared_enumerated_type_name ':' enumerated_specification {library_element_symtable.insert($1, prev_declared_enumerated_type_name_token);} ASSIGN enumerated_value
	{$$ = new enumerated_type_declaration_c($1, new enumerated_spec_init_c($3, $6, locf(@3), locl(@6)), locloc(@$));}
*/
/* ERROR_CHECK_BEGIN */
| error ':' enumerated_spec_init
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid name defined for enumerated type declaration."); yyerrok;}
| identifier enumerated_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between data type name and specification in enumerated type declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


enumerated_spec_init:
  enumerated_specification
	{$$ = new enumerated_spec_init_c($1, NULL, locloc(@$));}
| enumerated_specification ASSIGN enumerated_value
	{$$ = new enumerated_spec_init_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| enumerated_specification enumerated_value
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in enumerated specification with initialization."); yynerrs++;}
| enumerated_specification ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined in enumerated specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value in enumerated specification with initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

enumerated_specification:
  '(' enumerated_value_list ')'
	{$$ = $2;}
| prev_declared_enumerated_type_name
/* ERROR_CHECK_BEGIN */
| '(' ')'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no enumerated value list defined in enumerated specification."); yynerrs++;}
| '(' error ')'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid enumerated value list defined in enumerated specification.");yyerrok;}
| '(' enumerated_value_list error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing at the end of enumerated specification."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for enumerated_specification */
enumerated_value_list:
  enumerated_value
	{$$ = new enumerated_value_list_c(locloc(@$)); $$->add_element($1);}
| enumerated_value_list ',' enumerated_value
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| enumerated_value_list enumerated_value
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in enumerated value list.");}
| enumerated_value_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined in enumerated value list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value in enumerated value list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


enumerated_value:
  identifier 
  {$$ = new enumerated_value_c(NULL, $1, locloc(@$));}
| prev_declared_enumerated_type_name '#' any_identifier
	{$$ = new enumerated_value_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| prev_declared_enumerated_type_name any_identifier
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'#' missing between enumerated type name and value in enumerated literal."); yynerrs++;}
| prev_declared_enumerated_type_name '#' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for enumerated literal.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for enumerated literal."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/*
enumerated_value_without_identifier:
  prev_declared_enumerated_type_name '#' any_identifier
	{$$ = new enumerated_value_c($1, $3, locloc(@$));}
;
*/


array_type_declaration:
/*  array_type_name ':' array_spec_init */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' array_spec_init   {library_element_symtable.insert($1, prev_declared_array_type_name_token);}
	{if (!get_preparse_state()) $$ = new array_type_declaration_c($1, $3, locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_array_type_name ':' array_spec_init
	{$$ = new array_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
/* ERROR_CHECK_BEGIN */
| identifier array_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between data type name and specification in array type declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;

array_spec_init:
  array_specification
	{$$ = new array_spec_init_c($1, NULL, locloc(@$));}
| array_specification ASSIGN array_initialization
	{$$ = new array_spec_init_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| array_specification array_initialization
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in array specification with initialization."); yynerrs++;}
| array_specification ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in array specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in array specification with initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


array_specification:
  prev_declared_array_type_name
| ARRAY '[' array_subrange_list ']' OF non_generic_type_name
	{$$ = new array_specification_c($3, $6, locloc(@$));}
| ARRAY '[' array_subrange_list ']' OF ref_spec_non_recursive
	/* non standard extension: Allow use of arrays storing REF_TO datatypes that are declared as 'ARRAY [1..3] OF REF_TO INT' */
	/*                                                                                                            ^^^^^^      */
	/* NOTE: We use ref_spec and not ref_spec_init as for the moment I do not want to allow direct specification of initial value.
	 *       I (MJS) am not too sure whether this is currently supported in code generation, so leave it out for now.
	 *       It also does not seem to be a very good idea to allow initial value specification when declaring the array,
	 *       since the standard syntax does not allow it either for any other datatype!
	 * NOTE: We use ref_spec_non_recursive instead of ref_spec in order to remove a reduce/reduce conflict.
	 *       Note that non_generic_type_name that is used in the previous rule already include the prev_declared_ref_type_name.
	 *       which leads to the reduce/reduce conflict, as it is also included in ref_spec.
	 */
	{$$ = new array_specification_c($3, $6, locloc(@$));
	 if (!allow_ref_to_in_derived_datatypes) {
	   print_err_msg(locf(@$), locl(@$), "REF_TO may not be used in an ARRAY specification (use -R option to activate support for this non-standard syntax)."); 
	   yynerrs++;
	 }
	}
/* ERROR_CHECK_BEGIN */
| ARRAY array_subrange_list ']' OF non_generic_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'[' missing before subrange list in array specification."); yynerrs++;}
| ARRAY '[' ']' OF non_generic_type_name
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no subrange list defined in array specification."); yynerrs++;}
| ARRAY '[' error ']' OF non_generic_type_name
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid subrange list defined in array specification."); yyerrok;}
| ARRAY OF non_generic_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no subrange list defined in array specification."); yynerrs++;}
| ARRAY error OF non_generic_type_name
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid subrange list defined in array specification."); yyerrok;}
| ARRAY '[' array_subrange_list OF non_generic_type_name
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "']' missing after subrange list in array specification."); yynerrs++;}
| ARRAY '[' array_subrange_list ']' non_generic_type_name
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "'OF' missing between subrange list and item type name in array specification."); yynerrs++;}
| ARRAY '[' array_subrange_list ']' OF error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no item data type defined in array specification.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid item data type in array specification."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* helper symbol for array_specification */
array_subrange_list:
/* the construct 'subrange' has been replaced with 'subrange_with_var' in order to support the declaration of array ranges using a varable: e.g. ARRAY [2..max] OF INT */
  subrange_with_var
	{$$ = new array_subrange_list_c(locloc(@$)); $$->add_element($1);}
| array_subrange_list ',' subrange_with_var
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| array_subrange_list subrange
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in subrange list."); yynerrs++;}
| array_subrange_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no subrange defined in subrange list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid subrange in subrange list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


array_initialization:
  '[' array_initial_elements_list ']'
	{$$ = $2;}
/* ERROR_CHECK_BEGIN */
| '[' ']'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no initial values list defined in array initialization."); yynerrs++;}
| '[' error ']'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid initial values list defined in array initialization."); yyerrok;}
| '[' array_initial_elements_list error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "']' missing at the end of array initialization."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for array_initialization */
array_initial_elements_list:
  array_initial_elements
	{$$ = new array_initial_elements_list_c(locloc(@$)); $$->add_element($1);}
| array_initial_elements_list ',' array_initial_elements
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
/* The following error checking rules have been commented out. Why? Was it a typo? 
 * Lets keep them commented out for now...
 */
/*
| array_initial_elements_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no array initial value in array initial values list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid array initial value in array initial values list."); yyclearin;}
	 yyerrok;
	}
*/
/* ERROR_CHECK_END */
;


array_initial_elements:
  array_initial_element
| integer '(' ')'
	{$$ = new array_initial_elements_c($1, NULL, locloc(@$));}
| integer '(' array_initial_element ')'
	{$$ = new array_initial_elements_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| integer '(' error ')'
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid array initial value in array initial values list."); yyerrok;}
| integer '(' array_initial_element error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing at the end of array initial value in array initial values list."); yyerrok;}
/* ERROR_CHECK_END */
;


array_initial_element:
  constant
| enumerated_value
| structure_initialization
| array_initialization
;



structure_type_declaration:
/*  structure_type_name ':' structure_specification */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' structure_specification  {library_element_symtable.insert($1, prev_declared_structure_type_name_token);}
	{if (!get_preparse_state()) $$ = new structure_type_declaration_c($1, $3, locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_structure_type_name ':' structure_specification
	{$$ = new structure_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
/* ERROR_CHECK_BEGIN */
| identifier structure_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between data type name and specification in structure type declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


structure_specification:
  structure_declaration
| initialized_structure
;


initialized_structure:
  prev_declared_structure_type_name
	{$$ = new initialized_structure_c($1, NULL, locloc(@$));}
| prev_declared_structure_type_name ASSIGN structure_initialization
	{$$ = new initialized_structure_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| prev_declared_structure_type_name structure_initialization
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in structure specification with initialization."); yynerrs++;}
| prev_declared_structure_type_name ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined in structure specification with initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value in structure specification with initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


structure_declaration:
  STRUCT structure_element_declaration_list END_STRUCT
	{$$ = $2;}
/* ERROR_CHECK_BEGIN */
| STRUCT END_STRUCT
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no structure element declared in structure type declaration."); yynerrs++;}
| STRUCT error structure_element_declaration_list END_STRUCT
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'STRUCT' in structure type declaration."); yyerrok;}
| STRUCT structure_element_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed structure type declaration."); yyerrok;}
| STRUCT error END_STRUCT
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in structure type declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for structure_declaration */
structure_element_declaration_list:
  structure_element_declaration ';'
	{$$ = new structure_element_declaration_list_c(locloc(@$)); $$->add_element($1);}
| structure_element_declaration_list structure_element_declaration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new structure_element_declaration_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid structure element declaration."); yyerrok;}
| structure_element_declaration error
	{$$ = new structure_element_declaration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of structure element declaration."); yyerrok;}
| structure_element_declaration_list structure_element_declaration error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of structure element declaration."); yyerrok;}
| structure_element_declaration_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid structure element declaration."); yyerrok;}
| structure_element_declaration_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after structure element declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


structure_element_declaration:
  structure_element_name ':' simple_spec_init
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
| structure_element_name ':' subrange_spec_init
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
| structure_element_name ':' enumerated_spec_init
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
| structure_element_name ':' array_spec_init
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
| structure_element_name ':' initialized_structure
	{$$ = new structure_element_declaration_c($1, $3, locloc(@$)); $$->token = $1->token;}
| structure_element_name ':' ref_spec_init                              /* non standard extension: Allow use of struct elements storing REF_TO datatypes (either using REF_TO or a previosuly declared ref type) */
	{ $$ = new structure_element_declaration_c($1, $3, locloc(@$));
	  if (!allow_ref_to_in_derived_datatypes) {
	    print_err_msg(locf(@$), locl(@$), "REF_TO and reference datatypes may not be used in a STRUCT element (use -R option to activate support for this non-standard syntax)."); 
	    yynerrs++;
	  }
	}
/* ERROR_CHECK_BEGIN */
| structure_element_name simple_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and simple specification."); yynerrs++;}
| structure_element_name subrange_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and subrange specification."); yynerrs++;}
| structure_element_name enumerated_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and enumerated specification."); yynerrs++;}
| structure_element_name array_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and array specification."); yynerrs++;}
| structure_element_name initialized_structure
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between structure element name and structure specification."); yynerrs++;}
| structure_element_name ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in structure element declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in structure element declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


structure_element_name: any_identifier;


structure_initialization:
  '(' structure_element_initialization_list ')'
	{$$ = $2;}
/* ERROR_CHECK_BEGIN */
| '(' error ')'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid structure element initialization list in structure initialization."); yyerrok;}
| '(' structure_element_initialization_list error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "expecting ')' at the end of structure element initialization list in structure initialization."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for structure_initialization */
structure_element_initialization_list:
  structure_element_initialization
	{$$ = new structure_element_initialization_list_c(locloc(@$)); $$->add_element($1);}
| structure_element_initialization_list ',' structure_element_initialization
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
/* The following error checking rules have been commented out. Why? Was it a typo? 
 * Lets keep them commented out for now...
 */
/*
| structure_element_initialization_list structure_element_initialization
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in structure element initialization list in structure initialization."); yynerrs++;}
| structure_element_initialization_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no structure element initialization defined in structure initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid structure element initialization in structure initialization."); yyclearin;}
	 yyerrok;
	}
*/
/* ERROR_CHECK_END */
;


structure_element_initialization:
  structure_element_name ASSIGN constant
	{$$ = new structure_element_initialization_c($1, $3, locloc(@$));}
| structure_element_name ASSIGN enumerated_value
	{$$ = new structure_element_initialization_c($1, $3, locloc(@$));}
| structure_element_name ASSIGN array_initialization
	{$$ = new structure_element_initialization_c($1, $3, locloc(@$));}
| structure_element_name ASSIGN structure_initialization
	{$$ = new structure_element_initialization_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| structure_element_name constant
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in structure element initialization."); yynerrs++;}
| structure_element_name enumerated_value
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in enumerated structure element initialization."); yynerrs++;}
| structure_element_name array_initialization
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in array structure element initialization."); yynerrs++;}
| structure_element_name structure_initialization
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing in structured structure element initialization."); yynerrs++;}
| structure_element_name ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in structured structure element initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in structured structure element initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* NOTE: in order to remove a reduce/reduce conflict,
 *       all occurences of string_type_name
 *       have been replaced with identifier!
 */
/*
string_type_name: identifier;
*/

string_type_declaration:
/*  string_type_name ':' elementary_string_type_name string_type_declaration_size string_type_declaration_init */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' elementary_string_type_name string_type_declaration_size string_type_declaration_init	{library_element_symtable.insert($1, prev_declared_string_type_name_token);}
	{if (!get_preparse_state()) $$ = new string_type_declaration_c($1, $3, $4, $5, locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_string_type_name ':' elementary_string_type_name string_type_declaration_size string_type_declaration_init
	{$$ = new string_type_declaration_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, $4, $5, locloc(@$));} // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
;


/* helper symbol for string_type_declaration */
string_type_declaration_size:
  '[' integer ']'
	{$$ = $2;}
/* REMOVED !! */
//|  /* empty */
//	{$$ = NULL;}
;
/* The syntax contains a reduce/reduce conflict.
 * The optional '[' <size> ']'
 * has been changed to become mandatory to remove the conflict.
 *
 * The conflict arises because
 *  new_str_type : STRING := "hello!"
 * may be reduced to a string_type_declaration OR
 * a simple_type_declaration.
 *
 * Our change forces it to be reduced to a
 * simple_type_declaration!
 * We chose this option because changing the definition
 * of simple_spec_init would force us to change all the other
 * rules in which it appears. The change we made has no
 * side-effects!
 */

/* helper symbol for string_type_declaration */
string_type_declaration_init:
  /* empty */
	{$$ = NULL;}
| ASSIGN character_string
	{$$ = $2;}
;


/* Taken fron IEC 61131-3 v3
 * // Table 14 - Reference operations
 * Ref_Type_Decl  : Ref_Type_Name ':' Ref_Spec_Init ;
 * Ref_Spec_Init  : Ref_Spec ( ':=' Ref_Value )? ;
 * Ref_Spec       : 'REF_TO' Non_Gen_Type_Name ;
 * Ref_Type_Name  : Identifier ;
 * Ref_Name       : Identifier ;
 * Ref_Value      : Ref_Addr | 'NULL' ;
 * Ref_Addr       : 'REF' '(' (Symbolic_Variable | FB_Name | Class_Instance_Name ) ')' ;
 * Ref_Assign     : Ref_Name ':=' (Ref_Name | Ref_Deref | Ref_Value ) ;
 * Ref_Deref      : 'DREF' '(' Ref_Name ')' ;
 */

/* NOTE: in IEC 61131-3 v3, the formal syntax definition does not define non_generic_type_name to include FB type names.
 *       However, in section "6.3.4.10 References", example 4 includes a  REF_TO a FB type!
 *       We have therefore explicitly added the "REF_TO function_block_type_name" to this rule!
 * NOTE: the REF_TO ANY is a non-standard extension to the standard. This is basically equivalent to a (void *)
 */
ref_spec_non_recursive: /* helper symbol, used to remove a reduce/reduce conflict in a non-standard syntax I (Mario) have added!! */
  REF_TO non_generic_type_name
	{$$ = new ref_spec_c($2, locloc(@$));}
| REF_TO function_block_type_name
	{$$ = new ref_spec_c($2, locloc(@$));}
| REF_TO ANY
	{$$ = new ref_spec_c(new generic_type_any_c(locloc(@2)), locloc(@$));
	 if (!allow_ref_to_any) {
	   print_err_msg(locf(@$), locl(@$), "REF_TO ANY datatypes are not allowed (use -R option to activate support for this non-standard syntax)."); 
	   yynerrs++;
	 }
	}
;

ref_spec: /* defined in IEC 61131-3 v3 */
  ref_spec_non_recursive
| prev_declared_ref_type_name 
;


/* The IEC 61131-3 v3 standard actually only defines the following syntax:
 * 
 *  Ref_Type_Decl: Ref_Type_Name ':' Ref_Spec_Init;
 *  Ref_Spec_Init: Ref_Spec ( ':=' Ref_Value )?;
 *  Ref_Spec     : 'REF_TO' + Data_Type_Access;
 *
 * Note that the above syntax it is not possible to define a REF_TO datatype as 
 * an alias to an already previously declared REF_TO datatype.
 *
 * I (Mario) believe that this is probably a bug in the IEC 61131-3 syntax, and I have therefore
 * changed that standard definition to...
 *
 *  Ref_Type_Decl: Ref_Type_Name ':' Ref_Spec_Init;
 *  Ref_Spec_Init: Ref_Spec ( ':=' Ref_Value )?;
 *  Ref_Spec     : ('REF_TO' + Data_Type_Access) | Ref_Type_Name;
 *  
 * For example:
 *       TYPE
 *          ref1_t: REF_TO INT;
 *          ref2_t: ref1_t;    <-- without the above changes, this would not be allowed!!
 *       END_TYPE
 *
 * This change also makes it possible to declare variables using a previously declared REF_TO datatype
 *  For example:
 *     VAR  refvar: ref1_t; END_VAR
 *
 * This change also makes it possible to declare arrays containing a previously declared ref type.
 *  For example:
 *     VAR  refvar: ARRAY [1..3] OF ref1_t;     END_VAR   <--- becomes OK
 *     VAR  refvar: ARRAY [1..3] OF REF_TO INT; END_VAR   <--- still not OK. (Only becomes OK with other non-standard rules in another location of this file!)
 *
 * Interestingly, this change does NOT make it possible to declare structure elements of a previously declared ref type.
 *  For example:
 *     TYPE struct_t: STRUCT elem1: ref1_t;     END_STRUCT; END_TYPE;    <--- still not OK. (Only becomes OK with other non-standard rules in another location of this file!)
 *     TYPE struct_t: STRUCT elem1: REF_TO INT; END_STRUCT; END_TYPE;    <--- still not OK. (Only becomes OK with other non-standard rules in another location of this file!)
 */



ref_spec_init: /* defined in IEC 61131-3 v3 */
  ref_spec
	{$$ = new ref_spec_init_c($1, NULL, locloc(@$));}
/*  For the moment, we do not support initialising reference data types...
| ref_spec ASSIGN ... 
	{$$ = new ref_spec_init_c($1, $3, locloc(@$));}
*/
;

ref_type_decl:  /* defined in IEC 61131-3 v3 */
/* PRE_PARSING or SINGLE_PHASE_PARSING */
/*  The following rules will be run either by:
 *      - the pre_parsing phase of two phase parsing (when preparsing command line option is chosen).
 *      - the standard single phase parser (when preparsing command line option is not chosen).
 */
  identifier ':' ref_spec_init  {library_element_symtable.insert($1, prev_declared_ref_type_name_token);}
	{if (!get_preparse_state()) $$ = new ref_type_decl_c($1, $3, locloc(@$));}
/* POST_PARSING */
/*  These rules will be run after the preparser phase of two phase parsing has finished (only gets to execute if preparsing command line option is chosen). */
| prev_declared_ref_type_name ':' ref_spec_init
	{$$ = new ref_type_decl_c(new identifier_c(((token_c *)$1)->value, locloc(@1)), $3, locloc(@$));}  // change the derived_datatype_identifier_c into an identifier_c, as it will be taking the place of an identifier!
;






/*********************/
/* B 1.4 - Variables */
/*********************/
/* NOTE: The standard is erroneous in it's definition of 'variable' because:
 *         - The standard considers 'ENO' as a keyword...
 *         - ...=> which means that it may never be parsed as an 'identifier'...
 *         - ...=> and therefore may never be used as the name of a variable inside an expression.
 *         - However, a function/FB must be able to assign the ENO parameter
 *           it's value, doing it in an assignment statement, and therefore using the 'ENO'
 *           character sequence as an identifier!
 *        The obvious solution is to also allow the ENO keyword to be 
 *         used as the name of a variable. Note that this variable may be used
 *         even though it is not explicitly declared as a function/FB variable,
 *         as the standard requires us to define it implicitly in this case!
 *        There are three ways of achieving this:
 *          (i) simply not define EN and ENO as keywords in flex (lexical analyser)
 *              and let them be considered 'identifiers'. Aditionally, add some code
 *              so that if they are not explicitly declared, we add them automatically to
 *              the declaration of each Functions and FB, where they would then be parsed
 *              as a previously_declared_variable.
 *              This approach has the advantage the EN and ENO would automatically be valid
 *              in every location where it needs to be valid, namely in the explicit declaration 
 *              of these same variables, or when they are used within expressions.
 *              However, this approach has the drawback that 
 *              EN and ENO could then also be used anywhere a standard identifier is allowed,
 *              including in the naming of Functions, FBs, Programs, Configurations, Resources, 
 *              SFC Actions, SFC Steps, etc...
 *              This would mean that we would then have to add a lexical analysis check
 *              within the bison code (syntax analyser) to all the above constructs to make sure
 *              that the identifier being used is not EN or ENO.
 *         (ii) The other approach is to define EN and ENO as keywords / tokens in flex
 *              (lexical analyser) and then change the syntax in bison to acomodate 
 *              these tokens wherever they could correctly appear.
 *              This has the drawback that we need to do some changes to the synax defintion.
 *        (iii) Yet a another option is to mix the above two methods.
 *              Define EN and ENO as tokens in flex, but change (only) the syntax for
 *              variable declaration to allow these tokens to also be used in declaring variables.
 *              From this point onwards these tokens are then considered a previously_declared_variable,
 *              since flex will first check for this before even checking for tokens.
 *
 *              I (Mario) cuurretnly (2011) believe the cleanest method of achieving this goal
 *              is to use option (iii)
 *              However, considering that:
 *                - I have already previously implemented option (ii);
 *                - option (iii) requires that flex parse the previously_declared_variable
 *                   before parsing any token. We already support this (remeber that this is 
 *                   used mainly to allow some IL operators as well as PRIORITY, etc. tokens
 *                   to be used as identifiers, since the standard does not define them as keywords),
 *                   but this part of the code in flex is often commented out as usually people do not expect
 *                   us to follow the standard in the strict sense, but rather consider those
 *                   tokens as keywords;
 *                considering the above, we currently carry on using option (ii).
 */
variable:
  symbolic_variable
| prev_declared_direct_variable
| eno_identifier
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
;


symbolic_variable:
/* NOTE: To be entirely correct, variable_name must be replacemed by
 *         prev_declared_variable_name | prev_declared_fb_name | prev_declared_global_var_name
 */
  prev_declared_fb_name
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
| prev_declared_global_var_name
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
| prev_declared_variable_name
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
| multi_element_variable
/*
| identifier
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
*/
| symbolic_variable '^'     
	/* Dereferencing operator defined in IEC 61131-3 v3. However, implemented here differently then how it is defined in the standard! See following note for explanation! */
	{$$ = new deref_operator_c($1, locloc(@$));
	 if (!allow_ref_dereferencing) {
	   print_err_msg(locf(@$), locl(@$), "Derefencing REF_TO datatypes with '^' is not allowed (use -r option to activate support for this IEC 61131-3 v3 feature)."); 
	   yynerrs++;
	 }
}
;
/*
 * NOTE: The syntax defined in the v3 standard for the dereferencing operator '^' seems to me to be un-intentionally
 *       limited. For example
 *         ref_to_bool_var := REF(        array_of_bool [1] );   <---     Allowed!
 *         ref_to_bool_var := REF( ref_to_array_of_bool^[1] );   <---     Allowed!
 *         bool_var        := array_of_ref_to_bool[1]^;          <--- NOT Allowed!
 *         ref_to_array_of_bool^[1] := FALSE;                    <---     Allowed!
 *       I consider this a bug in the v3 standard!!
 *       I have therefore opted to implement this by simply adding a rule to symbolic_variable 
 *         symbolic_variable: 
 *                ...
 *           | symbolic_variable '^'
 *       This simple rule should be able to cover all the needed dereferencing syntax!
 *       I have also added a dereferencing expression for the DREF() operator.
 *       Since both of them do the exact same operation, they will both be translated to the exact same
 *       entry type in the abstract syntax tree (an deref_expression_c)
 */


/* NOTE: in section B 1.7, when configuring a program, symbolic_variable
 *       is used. Nevertheless, during the parsing of a configuration,
 *       the variables in question are out of scope, so we should
 *       be allowing any_identifier instead of prev_declared_variable_name!
 *
 *       We therefore need a new any_symbolic_variable construct that
 *       allows the use of any_identifier instead of previously declared
 *       variables, function blocks, etc...
 */
any_symbolic_variable:
// variable_name -> replaced by any_identifier
  any_identifier
	{$$ = new symbolic_variable_c($1, locloc(@$)); $$->token = $1->token;}
| any_multi_element_variable
;


/* for yet undeclared variable names ! */
variable_name: identifier;





/********************************************/
/* B.1.4.1   Directly Represented Variables */
/********************************************/
prev_declared_direct_variable: prev_declared_direct_variable_token	{$$ = new direct_variable_c($1, locloc(@$));};




/*************************************/
/* B.1.4.2   Multi-element Variables */
/*************************************/
multi_element_variable:
  array_variable
| structured_variable
;

/* please see note above any_symbolic_variable */
any_multi_element_variable:
  any_array_variable
| any_structured_variable
;


array_variable:
  subscripted_variable '[' subscript_list ']'
	{$$ = new array_variable_c($1, $3, locloc(@$));}
;

/* please see note above any_symbolic_variable */
any_array_variable:
  any_subscripted_variable '[' subscript_list ']'
	{$$ = new array_variable_c($1, $3, locloc(@$));}
;


subscripted_variable:
  symbolic_variable
;


/* please see note above any_symbolic_variable */
any_subscripted_variable:
  any_symbolic_variable
;


subscript_list:
  subscript
	{$$ = new subscript_list_c(locloc(@$)); $$->add_element($1);}
| subscript_list ',' subscript
	{$$ = $1; $$->add_element($3);}
;


subscript:  expression;


structured_variable:
  record_variable '.' field_selector
	{$$ = new structured_variable_c($1, $3, locloc(@$));}
| record_variable '.' il_simple_operator_clash3
    {$$ = new structured_variable_c($1, il_operator_c_2_identifier_c($3), locloc(@$));}
;


/* please see note above any_symbolic_variable */
any_structured_variable:
  any_record_variable '.' field_selector
	{$$ = new structured_variable_c($1, $3, locloc(@$));}
| any_record_variable '.' il_simple_operator_clash3
	{$$ = new structured_variable_c($1, $3, locloc(@$));}
;



record_variable:
  symbolic_variable
;


/* please see note above any_symbolic_variable */
any_record_variable:
  any_symbolic_variable
;


field_selector: 
  any_identifier
| eno_identifier
;






/******************************************/
/* B 1.4.3 - Declaration & Initialisation */
/******************************************/
input_declarations:
  VAR_INPUT            input_declaration_list END_VAR
	{$$ = new input_declarations_c(NULL, $2, new explicit_definition_c(), locloc(@$));}
| VAR_INPUT RETAIN     input_declaration_list END_VAR
	{$$ = new input_declarations_c(new retain_option_c(locloc(@2)), $3, new explicit_definition_c(), locloc(@$));}
| VAR_INPUT NON_RETAIN input_declaration_list END_VAR
	{$$ = new input_declarations_c(new non_retain_option_c(locloc(@2)), $3, new explicit_definition_c(), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_INPUT END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in input variable(s) declaration."); yynerrs++;}
| VAR_INPUT RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in retentive input variable(s) declaration."); yynerrs++;}
| VAR_INPUT NON_RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in non-retentive input variable(s) declaration."); yynerrs++;}
| VAR_INPUT error input_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_INPUT' in input variable(s) declaration."); yyerrok;}
| VAR_INPUT RETAIN error input_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive input variable(s) declaration."); yyerrok;}
| VAR_INPUT NON_RETAIN error input_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive input variable(s) declaration."); yyerrok;}
| VAR_INPUT input_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed input variable(s) declaration."); yyerrok;}
| VAR_INPUT RETAIN input_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed retentive input variable(s) declaration."); yyerrok;}
| VAR_INPUT NON_RETAIN input_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed non-retentive input variable(s) declaration."); yyerrok;}
| VAR_INPUT error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in input variable(s) declaration."); yyerrok;}
| VAR_INPUT RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in retentive input variable(s) declaration."); yyerrok;}
| VAR_INPUT NON_RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in non-retentive input variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for input_declarations */
input_declaration_list:
  input_declaration ';'
	{$$ = new input_declaration_list_c(locloc(@$)); $$->add_element($1);}
| input_declaration_list input_declaration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new input_declaration_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid input variable(s) declaration."); yyerrok;}
| input_declaration error
	{$$ = new input_declaration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of input variable(s) declaration."); yyerrok;}
| input_declaration_list input_declaration error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of input variable(s) declaration."); yyerrok;}
| input_declaration_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid input variable(s) declaration."); yyerrok;}
| input_declaration_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after input variable(s) declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


/* NOTE: The formal definition of 'input_declaration' as defined in the standard is erroneous,
 *       as it does not allow a user defined 'EN' input parameter. However,
 *       The semantic description of the languages clearly states that this is allowed.
 *       We have added the 'en_param_declaration' clause to cover for this.
 */
input_declaration:
  var_init_decl
| edge_declaration
| en_param_declaration
;


edge_declaration:
  var1_list ':' BOOL R_EDGE
	{$$ = new edge_declaration_c(new raising_edge_option_c(locloc(@3)), $1, locloc(@$));}
| var1_list ':' BOOL F_EDGE
	{$$ = new edge_declaration_c(new falling_edge_option_c(locloc(@3)), $1, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list BOOL R_EDGE
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and specification in edge declaration."); yynerrs++;}
| var1_list BOOL F_EDGE
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and specification in edge declaration."); yynerrs++;}
| var1_list ':' BOOL R_EDGE F_EDGE
	{$$ = NULL; print_err_msg(locl(@5), locf(@5), "'R_EDGE' and 'F_EDGE' can't be present at the same time in edge declaration."); yynerrs++;}
| var1_list ':' BOOL F_EDGE R_EDGE
	{$$ = NULL; print_err_msg(locl(@5), locf(@5), "'R_EDGE' and 'F_EDGE' can't be present at the same time in edge declaration."); yynerrs++;}
| var1_list ':' R_EDGE
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "'BOOL' missing in edge declaration."); yynerrs++;}
| var1_list ':' F_EDGE
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "'BOOL' missing in edge declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


/* NOTE: The formal definition of the standard is erroneous, as it simply does not
 *       consider the EN and ENO keywords!
 *       The semantic description of the languages clearly states that these may be
 *       used in several ways. One of them is to declare an EN input parameter.
 *       We have added the 'en_param_declaration' clause to cover for this.
 *
 *       Please read the comment above the definition of 'variable' in section B1.4 for details.
 */
en_param_declaration:
  en_identifier ':' BOOL ASSIGN boolean_literal
  {$$ = new en_param_declaration_c($1, new simple_spec_init_c(new bool_type_name_c(locloc(@3)), $5, locf(@3), locl(@5)), new explicit_definition_c(), locloc(@$));}
| en_identifier ':' BOOL ASSIGN integer
  {$$ = new en_param_declaration_c($1, new simple_spec_init_c(new bool_type_name_c(locloc(@3)), $5, locf(@3), locl(@5)), new explicit_definition_c(), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| en_identifier BOOL ASSIGN boolean_literal
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and specification in EN declaration."); yynerrs++;}
| en_identifier BOOL ASSIGN integer
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and specification in EN declaration."); yynerrs++;}
| en_identifier ':' ASSIGN boolean_literal
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "'BOOL' missing in EN declaration."); yynerrs++;}
| en_identifier ':' ASSIGN integer
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "'BOOL' missing in EN declaration."); yynerrs++;}
| en_identifier ':' BOOL ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in EN declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in EN declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

var_init_decl:
  var1_init_decl
| array_var_init_decl
| structured_var_init_decl
| fb_name_decl
| string_var_declaration
;




var1_init_decl:
  var1_list ':' simple_spec_init
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' subrange_spec_init
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' enumerated_spec_init
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' ref_spec_init   /* defined in IEC 61131-3 v3   (REF_TO ...)*/
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list simple_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and simple specification."); yynerrs++;}
| var1_list subrange_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and subrange specification."); yynerrs++;}
| var1_list enumerated_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and enumerated specification."); yynerrs++;}
| var1_list ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/* NOTE: 
 * The syntax 
 *    variable_name DOTDOT 
 * is an extension to the standard!!! 
 *
 * In order to be able to handle extensible standard functions
 * (i.e. standard functions that may have a variable number of
 * input parameters, such as AND(word#33, word#44, word#55, word#66),
 * we have extended the acceptable syntax to allow var_name '..'
 * in an input variable declaration.
 *
 * This allows us to parse the declaration of standard
 * extensible functions and load their interface definition
 * into the abstract syntax tree just like we do to other 
 * user defined functions.
 * This has the advantage that we can later do semantic
 * checking of calls to functions (be it a standard or user defined
 * function) in (almost) exactly the same way.
 *
 * Of course, we have a flag that disables this syntax when parsing user
 * written code, so we only allow this extra syntax while parsing the 
 * 'header' file that declares all the standard IEC 61131-3 functions.
 */
var1_list:
  variable_name
	{$$ = new var1_list_c(locloc(@$)); $$->add_element($1);
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| variable_name integer DOTDOT
	{$$ = new var1_list_c(locloc(@$)); $$->add_element(new extensible_input_parameter_c($1, $2, locloc(@$)));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	 if (!allow_extensible_function_parameters) print_err_msg(locf(@1), locl(@2), "invalid syntax in variable name declaration.");
	}
 | var1_list ',' variable_name
	{$$ = $1; $$->add_element($3);
	 variable_name_symtable.insert($3, prev_declared_variable_name_token);
	}
 | var1_list ',' variable_name integer DOTDOT
	{$$ = $1; $$->add_element(new extensible_input_parameter_c($3, $4, locloc(@$)));
	 variable_name_symtable.insert($3, prev_declared_variable_name_token);
	 if (!allow_extensible_function_parameters) print_err_msg(locf(@1), locl(@2), "invalid syntax in variable name declaration.");
	}
/* ERROR_CHECK_BEGIN */
| var1_list variable_name
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in variable list."); yynerrs++;}
| var1_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no variable name defined in variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid variable name in variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



array_var_init_decl:
 var1_list ':' array_spec_init
	{$$ = new array_var_init_decl_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list array_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and array specification."); yynerrs++;}
/* ERROR_CHECK_END */
;


structured_var_init_decl:
  var1_list ':' initialized_structure
	{$$ = new structured_var_init_decl_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list initialized_structure
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and structured specification."); yynerrs++;}
/* ERROR_CHECK_END */
;


/* NOTE: see notes above fb_name_list and var1_list
 *       for reason why ':' was removed from this rule!
 *       In essence, to remove a shift/reduce conflict,
 *       the ':' was moved to var1_list and fb_name_list!
 */
fb_name_decl:
/*  fb_name_list ':' function_block_type_name */
  fb_name_list_with_colon function_block_type_name
	{$$ = new fb_name_decl_c($1, new fb_spec_init_c($2, NULL,locloc(@2)), locloc(@$));}
/*| fb_name_list ':' function_block_type_name ASSIGN structure_initialization */
| fb_name_list_with_colon function_block_type_name ASSIGN structure_initialization
	{$$ = new fb_name_decl_c($1, new fb_spec_init_c($2, $4, locf(@2), locl(@4)), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| fb_name_list_with_colon ASSIGN structure_initialization
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block type name defined in function block declaration with initialization."); yynerrs++;}
| fb_name_list_with_colon function_block_type_name structure_initialization
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "':=' missing in function block declaration with initialization."); yynerrs++;}
| fb_name_list_with_colon function_block_type_name ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@3), locf(@4), "no initialization defined in function block declaration.");}
	 else {print_err_msg(locf(@4), locl(@4), "invalid initialization in function block declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



/* NOTE: In order to remove a reduce/reduce conflict between
 *       var1_list and fb_name_list, which are identical to each
 *       other, fb_name_list has been redefined to be a var1_list.
 *
 *        In order to remove a further shift/reduce conflict, var1_list
 *        is imediately transfomred into var1_list_with_colon
 *        (i.e. it includes the ':' following the list), which
 *        means that fb_name_list is built from a
 *        var1_list_with_colon after all!
 */
/*
fb_name_list:
 (*  fb_name *)
  identifier
	{$$ = new fb_name_list_c($1);
	 variable_name_symtable.insert($1, prev_declared_fb_name_token);
	}
(* | fb_name_list ',' fb_name *)
| fb_name_list ',' identifier
	{$$ = $1; $$->add_element($3);
	 variable_name_symtable.insert($3, prev_declared_fb_name_token);
	}
;
*/

fb_name_list_with_colon:
  var1_list_with_colon
	{$$ = new fb_name_list_c(locloc(@$));
	 /* fill up the new fb_name_list_c object with the references
	  * contained in the var1_list_c object.
	  */
	 FOR_EACH_ELEMENT(elem, $1, {$$->add_element(elem);});
	 delete $1;
	 /* change the tokens associated with the symbols stored in
	  * the variable name symbol table from prev_declared_variable_name_token
	  * to prev_declared_fb_name_token
	  */
	 FOR_EACH_ELEMENT(elem, $$, {variable_name_symtable.set(elem, prev_declared_fb_name_token);});
	}
;

/* helper symbol for fb_name_list_with_colon */
var1_list_with_colon:
  var1_list ':'
;


// fb_name: identifier;



output_declarations:
  VAR_OUTPUT var_output_init_decl_list END_VAR
	{$$ = new output_declarations_c(NULL, $2, new explicit_definition_c(), locloc(@$));}
| VAR_OUTPUT RETAIN var_output_init_decl_list END_VAR
	{$$ = new output_declarations_c(new retain_option_c(locloc(@2)), $3, new explicit_definition_c(), locloc(@$));}
| VAR_OUTPUT NON_RETAIN var_output_init_decl_list END_VAR
	{$$ = new output_declarations_c(new non_retain_option_c(locloc(@2)), $3, new explicit_definition_c(), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_OUTPUT END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in output variable(s) declaration."); yynerrs++;}
| VAR_OUTPUT RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in retentive output variable(s) declaration."); yynerrs++;}
| VAR_OUTPUT NON_RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in non-retentive output variable(s) declaration."); yynerrs++;}
| VAR_OUTPUT error var_output_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_OUPUT' in output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT RETAIN error var_output_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT NON_RETAIN error var_output_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT var_output_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT RETAIN var_output_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed retentive output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT NON_RETAIN var_output_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed non-retentive output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in retentive output variable(s) declaration."); yyerrok;}
| VAR_OUTPUT NON_RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in non-retentive output variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* NOTE: The formal definition of 'var_output_init_decl' as defined in the standard is erroneous,
 *       as it does not allow a user defined 'ENO' output parameter. However,
 *       The semantic description of the languages clearly states that this is allowed.
 *       We have added the 'eno_param_declaration' clause to cover for this.
 *
 *       Please read the comment above the definition of 'variable' in section B1.4 for details.
 */
var_output_init_decl:
  var_init_decl
| eno_param_declaration
;

var_output_init_decl_list:
  var_output_init_decl ';'
	{$$ = new var_init_decl_list_c(locloc(@$)); $$->add_element($1);}
| var_output_init_decl_list var_output_init_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| var_output_init_decl_list var_output_init_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of variable(s) declaration."); yyerrok;}
| var_output_init_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* NOTE: The formal definition of the standard is erroneous, as it simply does not
 *       consider the EN and ENO keywords!
 *       The semantic description of the languages clearly states that these may be
 *       used in several ways. One of them is to declare an ENO output parameter.
 *       We have added the 'eno_param_declaration' clause to cover for this.
 *
 *       Please read the comment above the definition of 'variable' in section B1.4 for details.
 */
eno_param_declaration:
  eno_identifier ':' BOOL
  /* NOTE We do _NOT_ include this variable in the previously_declared_variable symbol table!
   *      Please read the comment above the definition of 'variable' for the reason for this.
   */
  {$$ = new eno_param_declaration_c($1, new bool_type_name_c(locloc(@$)), new explicit_definition_c(), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| eno_identifier BOOL
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and specification in ENO declaration."); yynerrs++;}
| eno_identifier ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in ENO declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in ENO declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


input_output_declarations:
  VAR_IN_OUT var_declaration_list END_VAR
	{$$ = new input_output_declarations_c($2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_IN_OUT END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in in_out variable(s) declaration."); yynerrs++;}
| VAR_IN_OUT error var_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_IN_OUT' in in_out variable(s) declaration."); yyerrok;}
| VAR_IN_OUT var_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed in_out variable(s) declaration."); yyerrok;}
| VAR_IN_OUT error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in in_out variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;



/* helper symbol for input_output_declarations */
var_declaration_list:
  var_declaration ';'
	{$$ = new var_declaration_list_c(locloc(@$)); $$->add_element($1);}
| var_declaration_list var_declaration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new var_declaration_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid variable(s) declaration."); yyerrok;}
| var_declaration error
	{$$ = new var_declaration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of variable(s) declaration."); yyerrok;}
| var_declaration_list var_declaration error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of variable(s) declaration."); yyerrok;}
| var_declaration_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid variable(s) declaration."); yyerrok;}
| var_declaration_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after variable(s) declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


var_declaration:
  temp_var_decl
| fb_name_decl
;


temp_var_decl:
  var1_declaration
| array_var_declaration
| structured_var_declaration
| string_var_declaration
;

var1_declaration:
  var1_list ':' simple_specification
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' subrange_specification
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' enumerated_specification
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
| var1_list ':' ref_spec   /* defined in IEC 61131-3 v3   (REF_TO ...)*/
	{$$ = new var1_init_decl_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list simple_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and simple specification."); yynerrs++;}
| var1_list subrange_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and subrange specification."); yynerrs++;}
| var1_list enumerated_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and enumerated specification."); yynerrs++;}
/* ERROR_CHECK_END */
;



array_var_declaration:
  var1_list ':' array_specification
	{$$ = new array_var_declaration_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list array_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and array specification."); yynerrs++;}
/* ERROR_CHECK_END */
;

structured_var_declaration:
  var1_list ':' prev_declared_structure_type_name
	{$$ = new structured_var_declaration_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list prev_declared_structure_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and structured specification."); yynerrs++;}
/* ERROR_CHECK_END */
;


var_declarations:
  VAR var_init_decl_list END_VAR
	{$$ = new var_declarations_c(NULL, $2, locloc(@$));}
| VAR CONSTANT var_init_decl_list END_VAR
	{$$ = new var_declarations_c(new constant_option_c(locloc(@2)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in variable(s) declaration."); yynerrs++;}
| VAR CONSTANT END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in constant variable(s) declaration."); yynerrs++;}
| VAR error var_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@3), "unexpected token after 'VAR' in variable(s) declaration."); yyerrok;}
| VAR CONSTANT error var_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'CONSTANT' in constant variable(s) declaration."); yyerrok;}
| VAR var_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed variable(s) declaration."); yyerrok;}
| VAR CONSTANT var_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed constant variable(s) declaration."); yyerrok;}
| VAR error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in variable(s) declaration."); yyerrok;}
| VAR CONSTANT error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in constant variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


retentive_var_declarations:
  VAR RETAIN var_init_decl_list END_VAR
	{$$ = new retentive_var_declarations_c($3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in retentive variable(s) declaration."); yynerrs++;}
| VAR RETAIN error var_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive variable(s) declaration."); yyerrok;}
| VAR RETAIN var_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed retentive variable(s) declaration."); yyerrok;}
| VAR RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in retentive variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


located_var_declarations:
  VAR located_var_decl_list END_VAR
	{$$ = new located_var_declarations_c(NULL, $2, locloc(@$));}
| VAR CONSTANT located_var_decl_list END_VAR
	{$$ = new located_var_declarations_c(new constant_option_c(locloc(@2)), $3, locloc(@$));}
| VAR RETAIN located_var_decl_list END_VAR
	{$$ = new located_var_declarations_c(new retain_option_c(locloc(@2)), $3, locloc(@$));}
| VAR NON_RETAIN located_var_decl_list END_VAR
	{$$ = new located_var_declarations_c(new non_retain_option_c(locloc(@2)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR NON_RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in non-retentive located variable(s) declaration."); yynerrs++;}
| VAR error located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR' in located variable(s) declaration."); yyerrok;}
| VAR CONSTANT error located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'CONSTANT' in constant located variable(s) declaration."); yyerrok;}
| VAR RETAIN error located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive located variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN error located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive located variable(s) declaration."); yyerrok;}
| VAR located_var_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed located variable(s) declaration."); yyerrok;}
| VAR CONSTANT located_var_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed constant located variable(s) declaration."); yyerrok;}
| VAR RETAIN located_var_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed retentive located variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN located_var_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed non-retentive located variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in non retentive variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for located_var_declarations */
located_var_decl_list:
  located_var_decl ';'
	{$$ = new located_var_decl_list_c(locloc(@$)); $$->add_element($1);}
| located_var_decl_list located_var_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new located_var_decl_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid located variable declaration."); yyerrok;}
| located_var_decl error
	{$$ = new located_var_decl_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of located variable declaration."); yyerrok;}
| located_var_decl_list located_var_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of located variable declaration."); yyerrok;}
| located_var_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid located variable declaration."); yyerrok;}
| located_var_decl_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after located variable declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


located_var_decl:
  variable_name location ':' located_var_spec_init
	{$$ = new located_var_decl_c($1, $2, $4, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| location ':' located_var_spec_init
	{$$ = new located_var_decl_c(NULL, $1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| variable_name location located_var_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between located variable location and specification."); yynerrs++;}
| location located_var_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between located variable location and specification."); yynerrs++;}
| variable_name location ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in located variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in located variable declaration."); yyclearin;}
	 yyerrok;
	}
| location ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in located variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in located variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;




external_var_declarations:
  VAR_EXTERNAL external_declaration_list END_VAR
	{$$ = new external_var_declarations_c(NULL, $2, locloc(@$));}
| VAR_EXTERNAL CONSTANT external_declaration_list END_VAR
	{$$ = new external_var_declarations_c(new constant_option_c(locloc(@2)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_EXTERNAL END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in external variable(s) declaration."); yynerrs++;}
| VAR_EXTERNAL CONSTANT END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in constant external variable(s) declaration."); yynerrs++;}
| VAR_EXTERNAL error external_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_EXTERNAL' in external variable(s) declaration."); yyerrok;}
| VAR_EXTERNAL CONSTANT error external_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'CONSTANT' in constant external variable(s) declaration."); yyerrok;}
| VAR_EXTERNAL external_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed external variable(s) declaration."); yyerrok;}
| VAR_EXTERNAL CONSTANT external_declaration_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed constant external variable(s) declaration."); yyerrok;}
| VAR_EXTERNAL error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in external variable(s) declaration."); yyerrok;}
| VAR_EXTERNAL CONSTANT error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in constant external variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for external_var_declarations */
external_declaration_list:
  external_declaration ';'
	{$$ = new external_declaration_list_c(locloc(@$)); $$->add_element($1);}
| external_declaration_list external_declaration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new external_declaration_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid external variable declaration."); yyerrok;}
| external_declaration error
	{$$ = new external_declaration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of external variable declaration."); yyerrok;}
| external_declaration_list external_declaration error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of external variable declaration."); yyerrok;}
| external_declaration_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid external variable declaration."); yyerrok;}
| external_declaration_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after external variable declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;



/* Warning: When handling VAR_EXTERNAL declarations, the constant folding algorithm may (depending on the command line parameters) 
 *          set the symbol_c->const_value annotations on both the external_var_name as well as on its VAR_EXTERNAL datatype specification symbol.
 *          Setting the const_value on the datatype specification symbol of a VAR_EXTERNAL declaration is only possible if the declaration of 
 *          several external variables in a list is not allowed (as each variable could have a potentially distinct initial value).
 *           VAR_EXTERNAL
 *             a, b, c, d: INT;  (* incorrect syntax! *)
 *           END_VAR
 *          
 *          If anybody considers extending this standard syntax to allow the above syntax (several variables in a list), then be sure to go
 *          and fix the constant folding algorithm (more precisely, the constant_folding_c::handle_var_extern_global_pair() function.
 */
external_declaration:
  global_var_name ':' simple_specification
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| global_var_name ':' subrange_specification
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| global_var_name ':' enumerated_specification
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| global_var_name ':' array_specification
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| global_var_name ':' prev_declared_structure_type_name
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_variable_name_token);
	}
| global_var_name ':' function_block_type_name
	{$$ = new external_declaration_c($1, new fb_spec_init_c($3, NULL, locloc(@3)), locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_fb_name_token);
	}
| global_var_name ':' ref_spec /* defined in IEC 61131-3 v3   (REF_TO ...)*/
	{$$ = new external_declaration_c($1, $3, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_fb_name_token);
	}
/* ERROR_CHECK_BEGIN */
| global_var_name simple_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and simple specification."); yynerrs++;}
| global_var_name subrange_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and subrange specification."); yynerrs++;}
| global_var_name enumerated_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and enumerated specification."); yynerrs++;}
| global_var_name array_specification
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and array specification."); yynerrs++;}
| global_var_name prev_declared_structure_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and structured specification."); yynerrs++;}
| global_var_name function_block_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between external variable name and function block type specification."); yynerrs++;}
| global_var_name ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in external variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in external variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


global_var_name: identifier;


global_var_declarations:
  VAR_GLOBAL global_var_decl_list END_VAR
	{$$ = new global_var_declarations_c(NULL, $2, locloc(@$));}
| VAR_GLOBAL CONSTANT global_var_decl_list END_VAR
	{$$ = new global_var_declarations_c(new constant_option_c(locloc(@2)), $3, locloc(@$));}
| VAR_GLOBAL RETAIN global_var_decl_list END_VAR
	{$$ = new global_var_declarations_c(new retain_option_c(locloc(@2)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_GLOBAL END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in global variable(s) declaration."); yynerrs++;}
| VAR_GLOBAL CONSTANT END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in constant global variable(s) declaration."); yynerrs++;}
| VAR_GLOBAL RETAIN END_VAR
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable declared in retentive global variable(s) declaration."); yynerrs++;}
| VAR_GLOBAL error global_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_GLOBAL' in global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL CONSTANT error global_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'CONSTANT' in constant global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL RETAIN error global_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL global_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL CONSTANT global_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed constant global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL RETAIN global_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed retentive global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL CONSTANT error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in constant global variable(s) declaration."); yyerrok;}
| VAR_GLOBAL RETAIN error END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unknown error in constant global variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for global_var_declarations */
global_var_decl_list:
  global_var_decl ';'
	{$$ = new global_var_decl_list_c(locloc(@$)); $$->add_element($1);}
| global_var_decl_list global_var_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new global_var_decl_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid global variable(s) declaration."); yyerrok;}
| global_var_decl error
	{$$ = new global_var_decl_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of global variable(s) declaration."); yyerrok;}
| global_var_decl_list global_var_decl error
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "';' missing at end of global variable(s) declaration."); yyerrok;}
| global_var_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid global variable(s) declaration."); yyerrok;}
| global_var_decl_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after global variable(s) declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


global_var_decl:
/* NOTE : This possibility defined in standard has no sense and generate a conflict (disabled)
  global_var_spec ':'
	{$$ = new global_var_decl_c($1, NULL, locloc(@$));}
*/
  global_var_spec ':' located_var_spec_init
	{$$ = new global_var_decl_c($1, $3, locloc(@$));}
| global_var_spec ':' function_block_type_name
	{$$ = new global_var_decl_c($1, new fb_spec_init_c($3, NULL, locloc(@3)), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| global_var_list located_var_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between global variable list and type specification."); yynerrs++;}
| global_var_name location located_var_spec_init
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between global variable specification and type specification."); yynerrs++;}
| global_var_spec function_block_type_name
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between global variable specification and function block type specification."); yynerrs++;}
| global_var_spec ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in global variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in global variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


global_var_spec:
  global_var_list	{$$ = $1;}
| location
	{$$ = new global_var_spec_c(NULL, $1, locloc(@$));}
| global_var_name location
	{$$ = new global_var_spec_c($1, $2, locloc(@$));
	 variable_name_symtable.insert($1, prev_declared_global_var_name_token);
	}
;


located_var_spec_init:
  simple_spec_init
| subrange_spec_init
| enumerated_spec_init
| array_spec_init
| initialized_structure
| single_byte_string_spec
| double_byte_string_spec
| ref_spec_init /* defined in IEC 61131-3 v3 (REF_TO ...) */
;


location:
  AT direct_variable_token
	{$$ = new location_c(new direct_variable_c($2, locloc(@$)), locloc(@$));
	 direct_variable_symtable.insert($2, prev_declared_direct_variable_token);
	}
/* ERROR_CHECK_BEGIN */
| AT error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no location defined in location declaration.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid location in global location declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



global_var_list:
  global_var_name
	{$$ = new global_var_list_c(locloc(@$)); $$->add_element($1);
	 variable_name_symtable.insert($1, prev_declared_global_var_name_token);
	}
| global_var_list ',' global_var_name
	{$$ = $1; $$->add_element($3);
	 variable_name_symtable.insert($3, prev_declared_global_var_name_token);
	}
/* ERROR_CHECK_BEGIN */
| global_var_list global_var_name
	{$$ = new global_var_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "',' missing in global variable list."); yynerrs++;}
| global_var_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no variable name defined in global variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid variable name in global variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



string_var_declaration:
  single_byte_string_var_declaration
| double_byte_string_var_declaration
;

single_byte_string_var_declaration:
  var1_list ':' single_byte_string_spec
	{$$ = new single_byte_string_var_declaration_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list single_byte_string_spec
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and string type specification."); yynerrs++;}
/* ERROR_CHECK_END */
;

/* NOTE: The constructs
 *
 *       [W]STRING
 *       and
 *       [W]STRING ASSIGN single_byte_character_string
 *
 *       were removed as they are already contained
 *       within a other constructs.
 *
 *       single_byte_string_spec is used in:
 *        - single_byte_string_var_declaration ->
 *           -> string_var_declaration ---> var_init_decl
 *                                     |--> temp_var_decl
 *                                     |--> var2_init_decl
 *        - located_var_spec_init
 *
 *       STRING [ASSIGN string_constant] -> elementary_string_type_name ->
 *        -> simple_spec -> simple_specification -> simple_spec_init ->
 *        -> located_var_spec_init
 *
 *       STRING [ASSIGN string_constant] -> elementary_string_type_name ->
 *        -> simple_spec -> simple_specification -> simple_spec_init ->
 *        -> var1_init_decl -> var_init_decl
 *
 *       STRING [ASSIGN string_constant] -> elementary_string_type_name ->
 *        -> simple_spec -> simple_specification -> simple_spec_init ->
 *        -> var1_init_decl -> var2_init_decl
 *
 *       STRING [ASSIGN string_constant] -> elementary_string_type_name ->
 *        -> simple_spec -> simple_specification ->
 *        -> var1_declaration -> temp_var_decl
 */
single_byte_string_spec:
/*  STRING
	{$$ = new single_byte_string_spec_c(NULL, NULL);}
*/
  STRING '[' integer ']'
	{$$ = new single_byte_string_spec_c(new single_byte_limited_len_string_spec_c(new string_type_name_c(locloc(@1)), $3, locloc(@$)), NULL, locloc(@$));}
/*
| STRING ASSIGN single_byte_character_string
	{$$ = new single_byte_string_spec_c($1, NULL, $3, locloc(@$));}
*/
| STRING '[' integer ']' ASSIGN single_byte_character_string
	{$$ = new single_byte_string_spec_c(new single_byte_limited_len_string_spec_c(new string_type_name_c(locloc(@1)), $3, locloc(@$)), $6, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| STRING '[' error ']'
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid length value for limited string type specification."); yyerrok;}
| STRING '[' error ']' ASSIGN single_byte_character_string
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid length value for limited string type specification."); yyerrok;}
| STRING '[' ']'
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "missing length value for limited string type specification."); yynerrs++;}
| STRING '[' ']' ASSIGN single_byte_character_string
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "missing length value for limited string type specification."); yynerrs++;}
| STRING '[' integer error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "expecting ']' after length definition for limited string type specification."); yyerrok;}
| STRING '[' integer ']' single_byte_character_string
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "':=' missing before limited string type initialization."); yynerrs++;}
| STRING '[' integer ']' ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@5), locf(@6), "no initial value defined in limited string type initialization.");}
	 else {print_err_msg(locf(@6), locl(@6), "invalid initial value in limited string type initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


double_byte_string_var_declaration:
  var1_list ':' double_byte_string_spec
	{$$ = new double_byte_string_var_declaration_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| var1_list double_byte_string_spec
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between variable list and double byte string type specification."); yynerrs++;}
/* ERROR_CHECK_END */
;

double_byte_string_spec:
/*  WSTRING
	{$$ = new double_byte_string_spec_c($1, NULL, NULL, locloc(@$));}
*/
  WSTRING '[' integer ']'
	{$$ = new double_byte_string_spec_c(new double_byte_limited_len_string_spec_c(new wstring_type_name_c(locloc(@1)), $3, locloc(@$)), NULL, locloc(@$));}

/*
| WSTRING ASSIGN double_byte_character_string
	{$$ = new double_byte_string_spec_c($1, NULL, $3, locloc(@$));}
*/
| WSTRING '[' integer ']' ASSIGN double_byte_character_string
	{$$ = new double_byte_string_spec_c(new double_byte_limited_len_string_spec_c(new wstring_type_name_c(locloc(@1)), $3, locloc(@$)), $6, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| WSTRING '[' error ']'
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid length value for limited double byte string type specification."); yyerrok;}
| WSTRING '[' error ']' ASSIGN single_byte_character_string
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid length value for limited double byte string type specification."); yyerrok;}
| WSTRING '[' ']'
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "missing length value for limited double byte string type specification."); yynerrs++;}
| WSTRING '[' ']' ASSIGN single_byte_character_string
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "missing length value for limited double byte string type specification."); yynerrs++;}
| WSTRING '[' integer error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "expecting ']' after length definition for limited double byte string type specification."); yyerrok;}
| WSTRING '[' integer ']' single_byte_character_string
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "':=' missing before limited double byte string type initialization."); yynerrs++;}
| WSTRING '[' integer ']' ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@5), locf(@6), "no initial value defined double byte in limited string type initialization.");}
	 else {print_err_msg(locf(@6), locl(@6), "invalid initial value in limited double byte string type initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



incompl_located_var_declarations:
  VAR            incompl_located_var_decl_list END_VAR
	{$$ = new incompl_located_var_declarations_c(NULL, $2, locloc(@$));}
| VAR     RETAIN incompl_located_var_decl_list END_VAR
	{$$ = new incompl_located_var_declarations_c(new retain_option_c(locloc(@2)), $3, locloc(@$));}
| VAR NON_RETAIN incompl_located_var_decl_list END_VAR
	{$$ = new incompl_located_var_declarations_c(new non_retain_option_c(locloc(@2)), $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR incompl_located_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed incomplete located variable(s) declaration."); yyerrok;}
| VAR RETAIN incompl_located_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed incomplete retentive located variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN incompl_located_var_decl_list error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed incomplete non-retentive located variable(s) declaration."); yyerrok;}
| VAR error incompl_located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR' in incomplete located variable(s) declaration."); yyerrok;}
| VAR RETAIN error incompl_located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive located variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN error incompl_located_var_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive located variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for incompl_located_var_declarations */
incompl_located_var_decl_list:
  incompl_located_var_decl ';'
	{$$ = new incompl_located_var_decl_list_c(locloc(@$)); $$->add_element($1);}
| incompl_located_var_decl_list incompl_located_var_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| incompl_located_var_decl error
	{$$ = new incompl_located_var_decl_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of incomplete located variable declaration."); yyerrok;}
| incompl_located_var_decl_list incompl_located_var_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of incomplete located variable declaration."); yyerrok;}
| incompl_located_var_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid incomplete located variable declaration."); yyerrok;}
| incompl_located_var_decl_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after incomplete located variable declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


incompl_located_var_decl:
  variable_name incompl_location ':' var_spec
	{$$ = new incompl_located_var_decl_c($1, $2, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| variable_name incompl_location var_spec
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing between incomplete located variable and type specification."); yynerrs++;
	}
| variable_name incompl_location ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no specification defined in incomplete located variable declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid specification in incomplete located variable declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


incompl_location:
  AT incompl_location_token
	{$$ = new incompl_location_c($2, locloc(@$));}
;


var_spec:
  simple_specification
| subrange_specification
| enumerated_specification
| array_specification
| prev_declared_structure_type_name
| string_spec
;


/* helper symbol for var_spec */
string_spec:
/*  STRING
	{$$ = new single_byte_limited_len_string_spec_c($1, NULL, locloc(@$));}
*/
  STRING '[' integer ']'
	{$$ = new single_byte_limited_len_string_spec_c(new string_type_name_c(locloc(@1)), $3, locloc(@$));}
/*
| WSTRING
	{$$ = new double_byte_limited_len_string_spec_c($1, NULL, locloc(@$));}
*/
| WSTRING '[' integer ']'
	{$$ = new double_byte_limited_len_string_spec_c(new wstring_type_name_c(locloc(@1)), $3, locloc(@$));}
;




/* intermediate helper symbol for:
 *  - non_retentive_var_decls
 *  - var_declarations
 */
var_init_decl_list:
  var_init_decl ';'
	{$$ = new var_init_decl_list_c(locloc(@$)); $$->add_element($1);}
| var_init_decl_list var_init_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| var_init_decl_list var_init_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of variable(s) declaration."); yyerrok;}
| var_init_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;




/***********************/
/* B 1.5.1 - Functions */
/***********************/
/*
function_name:
  prev_declared_derived_function_name
| standard_function_name 
;
*/

/* The following rules should be set such as:
 * function_name: function_name_no_clashes | function_name_simpleop_clashes | function_name_expression_clashes
 * function_name: function_name_no_NOT_clashes | function_name_NOT_clashes;
 */

function_name_no_clashes: prev_declared_derived_function_name | standard_function_name_no_clashes;
function_name_simpleop_clashes: standard_function_name_simpleop_clashes;
//function_name_expression_clashes: standard_function_name_expression_clashes;

function_name_no_NOT_clashes: prev_declared_derived_function_name | standard_function_name_no_NOT_clashes;
//function_name_NOT_clashes: standard_function_name_NOT_clashes;


/* NOTE: The list of standard function names
 *       includes the standard functions MOD(), NOT()
 *
 *       Strangely enough, MOD and NOT are reserved keywords,
 *       so shouldn't be used for function names.
 *
 *       The specification contradicts itself!
 *       Our workaround  is to treat MOD as a token,
 *       but to include this token as a
 *       standard_function_name.
 *
 *       The names of all other standard functions get
 *       preloaded into the library_element_symbol_table
 *       with the token value of
 *       standard_function_name_token
 *       Actually, simply for completeness, MOD is also
 *       loaded into the library_element_symbol_table, but
 *       it is irrelevant since flex will catch MOD as a
 *       token, before it interprets it as an identifier,
 *       and looks in the library_element_symbol_table to check
 *       whether it has been previously declared.
 *
 * NOTE: The same as the above also occurs with the IL
 *       operators NOT AND OR XOR ADD SUB MUL DIV MOD
 *       GT GE EQ LT LE NE.
 *       Note that MOD is once again in the list!
 *       Anyway, we give these the same treatement as
 *       MOD, since we are writing a parser for ST and
 *       IL simultaneously. If this were not the case,
 *       the ST parser would not need the tokens NOT AND ...
 *
 * NOTE: Note that 'NOT' is special, as it conflicts
 *       with two operators: the  IL 'NOT' operator, and
 *       the unary operator 'NOT' in ST!!
 *
 * NOTE: The IL language is ambiguous, since using NOT, AND, ...
 *       may be interpreted as either an IL operator, or
 *       as a standard function call!
 *       I (Mario) opted to interpret it as an IL operator.
 *       This requires changing the syntax for IL language
 *       function   calling, to exclude all function with
 *       names that clash with IL operators. I therefore
 *       created the constructs
 *       function_name_without_clashes
 *       standard_function_name_without_clashes
 *       to include all function names, except those that clash
 *       with IL operators. These constructs are only used
 *       within the IL language!
 */
/* The following rules should be set such as:
 * standard_function_name: standard_function_name_no_clashes | standard_function_name_simpleop_clashes | standard_function_name_expression_clashes
 * standard_function_name: standard_function_name_no_NOT_clashes | standard_function_name_NOT_clashes;
 */

/*
standard_function_name:
  standard_function_name_no_clashes
| standard_function_name_expression_clashes
| standard_function_name_NOT_clashes
//| standard_function_name_simpleop_only_clashes
;
*/

standard_function_name_no_NOT_clashes:
  standard_function_name_no_clashes
| standard_function_name_expression_clashes
//| standard_function_name_simpleop_only_clashes
;

/* standard_function_name_no_clashes is only used in function invocations, so we use the poutype_identifier_c class! */
standard_function_name_no_clashes:
  standard_function_name_token
	{$$ = new poutype_identifier_c($1, locloc(@$));}
;


standard_function_name_simpleop_clashes:
  standard_function_name_NOT_clashes
//| standard_function_name_simpleop_only_clashes
;

/* standard_function_name_NOT_clashes is only used in function invocations, so we use the poutype_identifier_c class! */
standard_function_name_NOT_clashes:
  NOT
	{$$ = new poutype_identifier_c(creat_strcopy("NOT"), locloc(@$));}
;

/* Add here any other IL simple operators that collide
 * with standard function names!
 * Don't forget to uncomment the equivalent lines in
 *   - standard_function_name_simpleop_clashes
 *   - standard_function_name
 *   - standard_function_name_no_NOT_clashes
 */
/*
standard_function_name_simpleop_only_clashes:
;
*/

/* standard_function_name_expression_clashes is only used in function invocations, so we use the poutype_identifier_c class! */
standard_function_name_expression_clashes:
  AND	{$$ = new poutype_identifier_c(creat_strcopy("AND"), locloc(@$));}
| OR	{$$ = new poutype_identifier_c(creat_strcopy("OR"), locloc(@$));}
| XOR	{$$ = new poutype_identifier_c(creat_strcopy("XOR"), locloc(@$));}
| ADD	{$$ = new poutype_identifier_c(creat_strcopy("ADD"), locloc(@$));}
| SUB	{$$ = new poutype_identifier_c(creat_strcopy("SUB"), locloc(@$));}
| MUL	{$$ = new poutype_identifier_c(creat_strcopy("MUL"), locloc(@$));}
| DIV	{$$ = new poutype_identifier_c(creat_strcopy("DIV"), locloc(@$));}
| MOD	{$$ = new poutype_identifier_c(creat_strcopy("MOD"), locloc(@$));}
| GT	{$$ = new poutype_identifier_c(creat_strcopy("GT"), locloc(@$));}
| GE	{$$ = new poutype_identifier_c(creat_strcopy("GE"), locloc(@$));}
| EQ	{$$ = new poutype_identifier_c(creat_strcopy("EQ"), locloc(@$));}
| LT	{$$ = new poutype_identifier_c(creat_strcopy("LT"), locloc(@$));}
| LE	{$$ = new poutype_identifier_c(creat_strcopy("LE"), locloc(@$));}
| NE	{$$ = new poutype_identifier_c(creat_strcopy("NE"), locloc(@$));}
/*
  AND_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
//NOTE: AND2 (corresponding to the source code string '&') does not clash
//      with a standard function name, so should be commented out!
//| AND2_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| OR_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| XOR_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| ADD_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| SUB_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| MUL_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| DIV_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| MOD_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| GT_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| GE_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| EQ_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| LT_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| LE_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
| NE_operator	{$$ = il_operator_c_2_poutype_identifier_c($1);}
*/
;


derived_function_name:
  identifier  /* will never occur during normal parsing, only needed for preparsing to change it to a prev_declared_derived_function_name! */
| prev_declared_derived_function_name
	{$$ = new identifier_c(((token_c *)$1)->value, locloc(@$)); // transform the poutype_identifier_c into an identifier_c
	 if (get_preparse_state() && !allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
| AND
	{$$ = new identifier_c("AND", locloc(@$));
	 if (!allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
| OR
	{$$ = new identifier_c("OR", locloc(@$));
	 if (!allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
| XOR
	{$$ = new identifier_c("XOR", locloc(@$));
	 if (!allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
| NOT
	{$$ = new identifier_c("NOT", locloc(@$));
	 if (!allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
| MOD
	{$$ = new identifier_c("MOD", locloc(@$));
	 if (!allow_function_overloading) {print_err_msg(locloc(@$), "Function overloading not allowed. Invalid identifier.\n"); yynerrs++;}
	}
;


function_declaration:
/*  FUNCTION derived_function_name ':' elementary_type_name io_OR_function_var_declarations_list function_body END_FUNCTION */
/* PRE_PARSING: The rules expected to be applied by the preparser. */
  FUNCTION derived_function_name END_FUNCTION   /* rule that is only expected to be used during preparse state => MUST print an error if used outside preparse() state!! */
	{$$ = NULL; 
	 if (get_preparse_state())    {library_element_symtable.insert($2, prev_declared_derived_function_name_token);}
	 else                         {print_err_msg(locl(@1), locf(@3), "FUNCTION with no variable declarations and no body."); yynerrs++;}
	 }
/* POST_PARSING and STANDARD_PARSING: The rules expected to be applied after the preparser has finished. */
| function_name_declaration ':' elementary_type_name io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = new function_declaration_c($1, $3, $4, $5, locloc(@$));
	 if (!runtime_options.disable_implicit_en_eno) add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already there */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 library_element_symtable.insert($1, prev_declared_derived_function_name_token);
	}
/* | FUNCTION derived_function_name ':' derived_type_name io_OR_function_var_declarations_list function_body END_FUNCTION */
| function_name_declaration ':' derived_type_name io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = new function_declaration_c($1, $3, $4, $5, locloc(@$));
	 if (!runtime_options.disable_implicit_en_eno) add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already there */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 library_element_symtable.insert($1, prev_declared_derived_function_name_token);
	}
/* | FUNCTION derived_function_name ':' VOID io_OR_function_var_declarations_list function_body END_FUNCTION */
| function_name_declaration ':' VOID io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = new function_declaration_c($1, new void_type_name_c(locloc(@3)), $4, $5, locloc(@$));
	 if (!runtime_options.disable_implicit_en_eno) add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already there */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 library_element_symtable.insert($1, prev_declared_derived_function_name_token);
	}
/* ERROR_CHECK_BEGIN */
| function_name_declaration elementary_type_name io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing after function name in function declaration."); yynerrs++;}
| function_name_declaration derived_type_name io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing after function name in function declaration."); yynerrs++;}
| function_name_declaration ':' io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no return type defined in function declaration."); yynerrs++;}
| function_name_declaration ':' error io_OR_function_var_declarations_list function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid return type defined in function declaration."); yyerrok;}
| function_name_declaration ':' elementary_type_name function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no variable(s) declared in function declaration."); yynerrs++;}
| function_name_declaration ':' derived_type_name function_body END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no variable(s) declared in function declaration."); yynerrs++;}
| function_name_declaration ':' elementary_type_name io_OR_function_var_declarations_list END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "no body defined in function declaration."); yynerrs++;}
| function_name_declaration ':' derived_type_name io_OR_function_var_declarations_list END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "no body defined in function declaration."); yynerrs++;}
| function_name_declaration ':' elementary_type_name END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no variable(s) declared and body defined in function declaration."); yynerrs++;}
| function_name_declaration ':' derived_type_name END_FUNCTION
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no variable(s) declared and body defined in function declaration."); yynerrs++;}
| function_name_declaration ':' elementary_type_name io_OR_function_var_declarations_list function_body END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locf(@3), "unclosed function declaration."); yynerrs++;}
| function_name_declaration ':' derived_type_name io_OR_function_var_declarations_list function_body END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed function declaration."); yynerrs++;}
| function_name_declaration error END_FUNCTION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in function declaration."); yyerrok;}
/* ERROR_CHECK_END */
;



/* helper symbol for function_declaration */
/* NOTE: due to reduce/reduce conflicts between identifiers
 *       being reduced to either a variable or an enumerator value,
 *       we were forced to keep a symbol table of the names
 *       of all declared variables. Variables are no longer
 *       created from simple identifier_token, but from
 *       prev_declared_variable_name_token.
 *
 *       BUT, in functions the function name itself may be used as
 *       a variable! In order to be able to parse this correctly,
 *       the token parser (flex) must return a prev_declared_variable_name_token
 *       when it comes across the function name, while parsing
 *       the function itself.
 *       We do this by inserting the function name into the variable
 *       symbol table, and having flex return a prev_declared_variable_name_token
 *       whenever it comes across it.
 *       When we finish parsing the function the variable name
 *       symbol table is cleared of all entries, and the function
 *       name is inserted into the library element symbol table. This
 *       means that from then onwards flex will return a
 *       derived_function_name_token whenever it comes across the
 *       function name.
 *
 *       In order to insert the function name into the variable_name
 *       symbol table BEFORE the function body gets parsed, we
 *       need the parser to reduce a construct that contains the
 *       the function name. That is why we created this extra
 *       construct (function_name_declaration), i.e. to force
 *       the parser to reduce it, before parsing the function body!
 */
function_name_declaration:
  /* FUNCTION derived_function_name */
  FUNCTION derived_function_name
	{$$ = $2;
	 /* the function name functions as a
	  * variable within the function itself!
	  *
	  * Remember that the variable_name_symtable
	  * is cleared once the end of the function
	  * is parsed.
	  */
	 variable_name_symtable.insert($2, prev_declared_variable_name_token);
	}
/* ERROR_CHECK_BEGIN */
| FUNCTION error 
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no function name defined in function declaration.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid function name in function declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



/* intermediate helper symbol for function_declaration */
io_OR_function_var_declarations_list:
  io_var_declarations
  {$$ = new var_declarations_list_c(locloc(@1));$$->add_element($1);}
| function_var_decls
	{$$ = new var_declarations_list_c(locloc(@1));$$->add_element($1);}
| io_OR_function_var_declarations_list io_var_declarations
	{$$ = $1; $$->add_element($2);}
| io_OR_function_var_declarations_list function_var_decls
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| io_OR_function_var_declarations_list retentive_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected retentive variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list located_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected located variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list external_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected external variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list global_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected global variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list incompl_located_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected incomplete located variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list temp_var_decls
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected temporary located variable(s) declaration in function declaration."); yynerrs++;}
| io_OR_function_var_declarations_list non_retentive_var_decls
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected non-retentive variable(s) declaration in function declaration."); yynerrs++;}
/*| io_OR_function_var_declarations_list access_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected access variable(s) declaration in function declaration."); yynerrs++;}*/
| io_OR_function_var_declarations_list instance_specific_initializations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected instance specific initialization(s) in function declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


io_var_declarations:
  input_declarations
| output_declarations
| input_output_declarations
;


function_var_decls:
  VAR CONSTANT var2_init_decl_list END_VAR
	{$$ = new function_var_decls_c(new constant_option_c(locloc(@2)), $3, locloc(@$));}
| VAR var2_init_decl_list END_VAR
	{$$ = new function_var_decls_c(NULL, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR error var2_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR' in function variable(s) declaration."); yyerrok;}
| VAR CONSTANT error var2_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'CONSTANT' in constant function variable(s) declaration."); yyerrok;}
| VAR var2_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed function variable(s) declaration."); yyerrok;}
| VAR CONSTANT var2_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed constant function variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* intermediate helper symbol for function_var_decls */
var2_init_decl_list:
  var2_init_decl ';'
	{$$ = new var2_init_decl_list_c(locloc(@$)); $$->add_element($1);}
| var2_init_decl_list var2_init_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| var2_init_decl error
	{$$ = new var2_init_decl_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of function variable(s) declaration."); yyerrok;}
| var2_init_decl_list var2_init_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of function variable(s) declaration."); yyerrok;}
| var2_init_decl_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid function variable(s) declaration."); yyerrok;}
| var2_init_decl_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after function variable(s) declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


function_body:
  start_ST_body_token statement_list	{$$ = $2;}
| start_IL_body_token instruction_list	{$$ = $2;}
/*
| ladder_diagram
| function_block_diagram
*/
;


var2_init_decl:
  var1_init_decl
| array_var_init_decl
| structured_var_init_decl
| string_var_declaration
;



/*****************************/
/* B 1.5.2 - Function Blocks */
/*****************************/
function_block_type_name:
  prev_declared_derived_function_block_name
| standard_function_block_name
;


standard_function_block_name: standard_function_block_name_token {$$ = new identifier_c($1, locloc(@$));};

derived_function_block_name: identifier;


function_block_declaration:
/* PRE_PARSING: The rules expected to be applied by the preparser. Will only run if pre-parsing command line option is ON. */
  FUNCTION_BLOCK derived_function_block_name END_FUNCTION_BLOCK   /* rule that is only expected to be used during preparse state => MUST print an error if used outside preparse() state!! */
	{$$ = NULL; 
	 if (get_preparse_state())    {library_element_symtable.insert($2, prev_declared_derived_function_block_name_token);}
	 else                         {print_err_msg(locl(@1), locf(@3), "FUNCTION_BLOCK with no variable declarations and no body."); yynerrs++;}
	 }
/* POST_PARSING: The rules expected to be applied after the preparser runs. Will only run if pre-parsing command line option is ON. */
| FUNCTION_BLOCK prev_declared_derived_function_block_name io_OR_other_var_declarations_list function_block_body END_FUNCTION_BLOCK
	{$$ = new function_block_declaration_c($2, $3, $4, locloc(@$));
	 if (!runtime_options.disable_implicit_en_eno) add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already there */
	 /* Clear the variable_name_symtable. Since we have finished parsing the function block,
	  * the variable names are now out of scope, so are no longer valid!
	  */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	}
/* STANDARD_PARSING: The rules expected to be applied in single-phase parsing. Will only run if pre-parsing command line option is OFF. */
| FUNCTION_BLOCK derived_function_block_name io_OR_other_var_declarations_list function_block_body END_FUNCTION_BLOCK
	{$$ = new function_block_declaration_c($2, $3, $4, locloc(@$));
	 library_element_symtable.insert($2, prev_declared_derived_function_block_name_token);
	 if (!runtime_options.disable_implicit_en_eno) add_en_eno_param_decl_c::add_to($$); /* add EN and ENO declarations, if not already there */
	 /* Clear the variable_name_symtable. Since we have finished parsing the function block,
	  * the variable names are now out of scope, so are no longer valid!
	  */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	}
/* ERROR_CHECK_BEGIN */
| FUNCTION_BLOCK io_OR_other_var_declarations_list function_block_body END_FUNCTION_BLOCK
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block name defined in function block declaration."); yynerrs++;}
| FUNCTION_BLOCK error io_OR_other_var_declarations_list function_block_body END_FUNCTION_BLOCK
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid function block name in function block declaration."); yyerrok;}
| FUNCTION_BLOCK derived_function_block_name function_block_body END_FUNCTION_BLOCK
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable(s) declared in function declaration."); yynerrs++;}
| FUNCTION_BLOCK derived_function_block_name io_OR_other_var_declarations_list END_FUNCTION_BLOCK
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no body defined in function block declaration."); yynerrs++;}
/*  Rule already covered by the rule to handle the preparse state!
| FUNCTION_BLOCK derived_function_block_name END_FUNCTION_BLOCK
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable(s) declared and body defined in function block declaration."); yynerrs++;}
*/
| FUNCTION_BLOCK derived_function_block_name io_OR_other_var_declarations_list function_block_body END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "expecting END_FUNCTION_BLOCK before end of file."); yynerrs++;}	
| FUNCTION_BLOCK error END_FUNCTION_BLOCK
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in function block declaration."); yyerrok;}
/* ERROR_CHECK_END */
;



/* intermediate helper symbol for function_declaration */
/*  { io_var_declarations | other_var_declarations }   */
/*
 * NOTE: we re-use the var_declarations_list_c
 */
io_OR_other_var_declarations_list:
  io_var_declarations
  {$$ = new var_declarations_list_c(locloc(@$));$$->add_element($1);}
| other_var_declarations
  {$$ = new var_declarations_list_c(locloc(@$));$$->add_element($1);}
| io_OR_other_var_declarations_list io_var_declarations
	{$$ = $1; $$->add_element($2);}
| io_OR_other_var_declarations_list other_var_declarations
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| io_OR_other_var_declarations_list located_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected located variable(s) declaration in function block declaration."); yynerrs++;}
| io_OR_other_var_declarations_list global_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected global variable(s) declaration in function block declaration."); yynerrs++;}
/*| io_OR_other_var_declarations_list access_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected access variable(s) declaration in function block declaration."); yynerrs++;}*/
| io_OR_other_var_declarations_list instance_specific_initializations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected instance specific initialization(s) in function block declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;

/* NOTE:
 *  The IEC specification gives the following definition:
 *  other_var_declarations ::=
 *     external_var_declarations
 *   | var_declarations
 *   | retentive_var_declarations
 *   | non_retentive_var_declarations
 *   | temp_var_decls
 *   | incompl_located_var_declarations
 *
 *  Nvertheless, the symbol non_retentive_var_declarations
 *  is not defined in the spec. This seems to me (Mario)
 *  to be a typo, so non_retentive_var_declarations
 *  has been replaced with non_retentive_var_decls
 *  in the following rule!
 */
other_var_declarations:
  temp_var_decls
| non_retentive_var_decls
| external_var_declarations
| var_declarations
| retentive_var_declarations
| incompl_located_var_declarations
;


temp_var_decls:
  VAR_TEMP temp_var_decls_list END_VAR
	{$$ = new temp_var_decls_c($2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_TEMP END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in temporary variable(s) declaration."); yynerrs++;}
| VAR_TEMP temp_var_decls_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "unclosed temporary variable(s) declaration."); yyerrok;}
| VAR_TEMP error temp_var_decls_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_TEMP' in function variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* intermediate helper symbol for temp_var_decls */
temp_var_decls_list:
  temp_var_decl ';'
	{$$ = new temp_var_decls_list_c(locloc(@$)); $$->add_element($1);}
| temp_var_decls_list temp_var_decl ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
	{$$ = new temp_var_decls_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid temporary variable(s) declaration."); yyerrok;}
| temp_var_decl error
	{$$ = new temp_var_decls_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at end of temporary variable(s) declaration."); yyerrok;}
| temp_var_decls_list temp_var_decl error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of temporary variable(s) declaration."); yyerrok;}
| temp_var_decls_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid temporary variable(s) declaration."); yyerrok;}
| temp_var_decls_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after temporary variable(s) declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


non_retentive_var_decls:
  VAR NON_RETAIN var_init_decl_list END_VAR
	{$$ = new non_retentive_var_decls_c($3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR NON_RETAIN var_init_decl_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unclosed non-retentive temporary variable(s) declaration."); yyerrok;}
| VAR NON_RETAIN error var_init_decl_list END_VAR
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive temporary variable(s) declaration."); yyerrok;}
/* ERROR_CHECK_END */
;



function_block_body:
  /* NOTE: start_ST_body_token is a dummy token generated by flex when it determines it is starting to parse a POU body in ST
   *       start_IL_body_token is a dummy token generated by flex when it determines it is starting to parse a POU body in IL
   *     These tokens help remove a reduce/reduce conflict in bison, between a formal function invocation in IL, and a
   *     function invocation used as a statement (a non-standard extension added to matiec) 
   *       e.g: FUNCTION_BLOCK foo
   *            VAR ... END_VAR
   *              func_returning_void(in1 := 3        
   *                                 );               --> only the presence or absence of ';' will determine whether this is a IL or ST 
   *                                                      function invocation. (In standard ST this would be ilegal, in matiec we allow it 
   *                                                      when activated by a command line option)
   *            END_FUNCTION
   */
  start_ST_body_token statement_list	{$$ = $2;}  
| start_IL_body_token instruction_list	{$$ = $2;}
| sequential_function_chart		{$$ = $1;}
/*
| ladder_diagram
| function_block_diagram
| <other languages>
*/
;




/**********************/
/* B 1.5.3 - Programs */
/**********************/
program_type_name: identifier;


program_declaration:
/* PRE_PARSING: The rules expected to be applied by the preparser. Will only run if pre-parsing command line option is ON. */
  PROGRAM program_type_name END_PROGRAM   /* rule that is only expected to be used during preparse state => MUST print an error if used outside preparse() state!! */
	{$$ = NULL; 
	 if (get_preparse_state())    {library_element_symtable.insert($2, prev_declared_program_type_name_token);}
	 else                         {print_err_msg(locl(@1), locf(@3), "PROGRAM with no variable declarations and no body."); yynerrs++;}
	 }
/* POST_PARSING: The rules expected to be applied after the preparser runs. Will only run if pre-parsing command line option is ON. */
| PROGRAM prev_declared_program_type_name program_var_declarations_list function_block_body END_PROGRAM
	{$$ = new program_declaration_c($2, $3, $4, locloc(@$));
	 /* Clear the variable_name_symtable. Since we have finished parsing the program declaration,
	  * the variable names are now out of scope, so are no longer valid!
	  */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	}
/* STANDARD_PARSING: The rules expected to be applied in single-phase parsing. Will only run if pre-parsing command line option is OFF. */
| PROGRAM program_type_name {library_element_symtable.insert($2, prev_declared_program_type_name_token);} program_var_declarations_list function_block_body END_PROGRAM
	{$$ = new program_declaration_c($2, $4, $5, locloc(@$));
	 /* Clear the variable_name_symtable. Since we have finished parsing the program declaration,
	  * the variable names are now out of scope, so are no longer valid!
	  */
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	}
/* ERROR_CHECK_BEGIN */
| PROGRAM program_var_declarations_list function_block_body END_PROGRAM
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no program name defined in program declaration.");}
| PROGRAM error program_var_declarations_list function_block_body END_PROGRAM
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid program name in program declaration."); yyerrok;}
| PROGRAM prev_declared_program_type_name function_block_body END_PROGRAM
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable(s) declared in program declaration."); yynerrs++;}
| PROGRAM prev_declared_program_type_name program_var_declarations_list END_PROGRAM
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no body defined in program declaration."); yynerrs++;}
/*  Rule already covered by the rule to handle the preparse state!
| PROGRAM prev_declared_program_type_name END_PROGRAM 
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no variable(s) declared and body defined in program declaration."); yynerrs++;}
*/
| PROGRAM prev_declared_program_type_name program_var_declarations_list function_block_body END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed program declaration."); yynerrs++;}
| PROGRAM error END_PROGRAM
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in program declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for program_declaration */
/*
 * NOTE: we re-use the var_declarations_list_c
 */
program_var_declarations_list:
  io_var_declarations
	{$$ = new var_declarations_list_c(locloc(@$)); $$->add_element($1);}
| other_var_declarations
	{$$ = new var_declarations_list_c(locloc(@$)); $$->add_element($1);}
| located_var_declarations
	{$$ = new var_declarations_list_c(locloc(@$)); $$->add_element($1);}
| program_var_declarations_list io_var_declarations
	{$$ = $1; $$->add_element($2);}
| program_var_declarations_list other_var_declarations
	{$$ = $1; $$->add_element($2);}
| program_var_declarations_list located_var_declarations
	{$$ = $1; $$->add_element($2);}
/*
| program_var_declarations_list program_access_decls
	{$$ = $1; $$->add_element($2);}
*/
/* ERROR_CHECK_BEGIN */
| program_var_declarations_list global_var_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected global variable(s) declaration in function block declaration."); yynerrs++;}
/*| program_var_declarations_list access_declarations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected access variable(s) declaration in function block declaration."); yynerrs++;}*/
| program_var_declarations_list instance_specific_initializations
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected instance specific initialization(s) in function block declaration."); yynerrs++;
	}
/* ERROR_CHECK_END */
;


/* TODO ... */
/*
program_access_decls:
  VAR_ACCESS program_access_decl_list END_VAR
;
*/

/* helper symbol for program_access_decls */
/*
program_access_decl_list:
  program_access_decl ';'
| program_access_decl_list program_access_decl ';'
;
*/

/*
program_access_decl:
  access_name ':' symbolic_variable ':' non_generic_type_name
| access_name ':' symbolic_variable ':' non_generic_type_name direction
;
*/



/********************************************/
/* B 1.6 Sequential Function Chart elements *
/********************************************/

sequential_function_chart:
  sfc_network
	{$$ = new sequential_function_chart_c(locloc(@$)); $$->add_element($1);}
| sequential_function_chart sfc_network
	{$$ = $1; $$->add_element($2);}
;

sfc_network:
  initial_step
	{$$ = new sfc_network_c(locloc(@$)); $$->add_element($1);}
| sfc_network step
	{$$ = $1; $$->add_element($2);}
| sfc_network transition
	{$$ = $1; $$->add_element($2);}
| sfc_network action
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| sfc_network error 
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "unexpected token after SFC network in sequencial function chart."); yyerrok;}
/* ERROR_CHECK_END */
;

initial_step:
  INITIAL_STEP step_name ':' action_association_list END_STEP
//  INITIAL_STEP identifier ':' action_association_list END_STEP
	{$$ = new initial_step_c($2, $4, locloc(@$));
	 variable_name_symtable.insert($2, prev_declared_variable_name_token); // A step name may later be used as a structured variable!!
	}
/* ERROR_CHECK_BEGIN */
| INITIAL_STEP ':' action_association_list END_STEP
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "no step name defined in initial step declaration."); yynerrs++;}
| INITIAL_STEP error ':' action_association_list END_STEP
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid step name defined in initial step declaration."); yyerrok;}
| INITIAL_STEP step_name action_association_list END_STEP
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "':' missing after step name in initial step declaration."); yynerrs++;}
| INITIAL_STEP step_name ':' error END_STEP
	{$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid action association list in initial step declaration."); yyerrok;}
| INITIAL_STEP step_name ':' action_association_list END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed initial step declaration."); yynerrs++;}
| INITIAL_STEP error END_STEP
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in initial step declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

step:
  STEP step_name ':' action_association_list END_STEP
//  STEP identifier ':' action_association_list END_STEP
	{$$ = new step_c($2, $4, locloc(@$));
	 variable_name_symtable.insert($2, prev_declared_variable_name_token); // A step name may later be used as a structured variable!!
	}
/* ERROR_CHECK_BEGIN */
| STEP ':' action_association_list END_STEP
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no step name defined in step declaration."); yynerrs++;}
| STEP error ':' action_association_list END_STEP
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid step name defined in step declaration."); yyerrok;}
| STEP step_name action_association_list END_STEP
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "':' missing after step name in step declaration."); yynerrs++;}
| STEP step_name ':' error END_STEP
	{$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid action association list in step declaration."); yyerrok;}
| STEP step_name ':' action_association_list END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@3), "invalid action association list in step declaration."); yynerrs++;}
| STEP error END_STEP
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in step declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for:
 *  - initial_step
 *  - step
 */
action_association_list:
  /* empty */
	{$$ = new action_association_list_c(locloc(@$));}
| action_association_list action_association ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| action_association_list action_association error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at end of action association declaration."); yyerrok;}
| action_association_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after action association declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


// step_name: identifier;
step_name: any_identifier;

action_association:
  action_name '(' {cmd_goto_sfc_qualifier_state();} action_qualifier {cmd_pop_state();} indicator_name_list ')'
	{$$ = new action_association_c($1, $4, $6, locloc(@$));}
/* ERROR_CHECK_BEGIN */
/*| action_name '(' error ')'
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid qualifier defined in action association."); yyerrok;}*/
/* ERROR_CHECK_END */
;

/* helper symbol for action_association */
indicator_name_list:
  /* empty */
	{$$ = new indicator_name_list_c(locloc(@$));}
| indicator_name_list ',' indicator_name
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| indicator_name_list indicator_name
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing at end of action association declaration."); yynerrs++;}
| indicator_name_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no indicator defined in indicator list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid indicator in indicator list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

// action_name: identifier;
action_name: any_identifier;

action_qualifier:
  /* empty */
	{$$ = NULL;}
| qualifier
	{$$ = new action_qualifier_c($1, NULL, locloc(@$));}
| timed_qualifier ',' action_time
	{$$ = new action_qualifier_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| timed_qualifier action_time
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "',' missing between timed qualifier and action time in action qualifier."); yynerrs++;}
| timed_qualifier ',' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no action time defined in action qualifier.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid action time in action qualifier."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

qualifier:
  N		{$$ = new qualifier_c(creat_strcopy("N"), locloc(@$));}
| R		{$$ = new qualifier_c(creat_strcopy("R"), locloc(@$));}
| S		{$$ = new qualifier_c(creat_strcopy("S"), locloc(@$));}
| P		{$$ = new qualifier_c(creat_strcopy("P"), locloc(@$));}
| P0	{$$ = new qualifier_c(creat_strcopy("P0"), locloc(@$));}
| P1	{$$ = new qualifier_c(creat_strcopy("P1"), locloc(@$));}
;

timed_qualifier:
  L		{$$ = new timed_qualifier_c(creat_strcopy("L"), locloc(@$));}
| D		{$$ = new timed_qualifier_c(creat_strcopy("D"), locloc(@$));}
| SD		{$$ = new timed_qualifier_c(creat_strcopy("SD"), locloc(@$));}
| DS		{$$ = new timed_qualifier_c(creat_strcopy("DS"), locloc(@$));}
| SL		{$$ = new timed_qualifier_c(creat_strcopy("SL"), locloc(@$));}
;

/* NOTE: A step_name may be used as a structured vaqriable, in order to access the status bit (e.g. Step1.X) 
 *       or the time it has been active (e.g. Step1.T). 
 *       In order to allow the step name to be used as a variable inside ST expressions (only ST expressions ??)
 *       when defining transitions, we need to add the step_name to the list of previously declared variables.
 *       This allows the step name to be used as a variable inside all transition expressions, as the user
 *       can clearly define the transition _after_ the step itself has been defined/declared, so the 
 *       'variable' is previously 'declared'.
 *
 *       However, when defining/declaring a step, a variable name can also be used to define a timed
 *       action association. In this case, we may have a circular reference:
 *        e.g.
 *            ...
 *             STEP step1:
 *                action1 (D,t#100ms);
 *             end_step
 *
 *             STEP step2:
 *                action1 (D,step3.T);  <---- forward reference to step3.T !!!!!!
 *             end_step
 *
 *             STEP step3:
 *                action1 (D,step2.T);  <---- back reference to step2.T
 *             end_step
 *
 *
 *         There is no way the user can always use the step3.T variable only after it has
 *         been 'declared'. So adding the steps to the list of previously declared variables 
 *         when the steps are declared is not a solution to the above situation.
 *
 *         Fortunately, the standard does not allow ST expressions in the above syntax
 *         (i.e. when defining the delay of a timed actions), but only either a 
 *         Time literal, or a variable.
 *         This is why we change the definition of action_time from
 *         action_time:
 *           duration
 *         | variable
 *         ;
 *
 *         to:
 *         action_time:
 *           duration
 *         | any_symbolic_variable
 *         ;
 *
 *       NOTE that this same problem does not occur with the 'indicator_name': it does not
 *       make sense to set/indicate a step1.X variable, as these variables are read-only!
 */     
    
action_time:
  duration
//| variable
  | any_symbolic_variable
;

indicator_name: variable;

// transition_name: identifier;
transition_name: any_identifier;


steps:
  step_name
	{$$ = new steps_c($1, NULL, locloc(@$));}
| '(' step_name_list ')'
	{$$ = new steps_c(NULL, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| '(' step_name_list error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "expecting ')' at the end of step list in transition declaration."); yyerrok;}
| '(' error ')'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid step list in transition declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

step_name_list:
  step_name ',' step_name
	{$$ = new step_name_list_c(locloc(@$)); $$->add_element($1); $$->add_element($3);}
| step_name_list ',' step_name
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| step_name_list step_name
	{$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in step list."); yynerrs++;}
| step_name_list ',' error
	{$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no step name defined in step list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid step name in step list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/* NOTE: flex will automatically pop() out of body_state to previous state.
 *       We do not need to give a command from bison to return to previous flex state,
 *       after forcing flex to go to body_state.
 */
transition:
  TRANSITION transition_priority
    FROM steps TO steps 
    {cmd_goto_body_state();} transition_condition 
  END_TRANSITION 
	{$$ = new transition_c(NULL, $2, $4, $6, $8, locloc(@$));}
//| TRANSITION identifier FROM steps TO steps ... 
| TRANSITION transition_name transition_priority
    FROM steps TO steps 
    {cmd_goto_body_state();} transition_condition 
  END_TRANSITION 
	{$$ = new transition_c($2, $3, $5, $7, $9, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| TRANSITION error transition_priority FROM steps TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid transition name defined in transition declaration."); yyerrok;}
| TRANSITION transition_name error FROM steps TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid transition priority defined in transition declaration."); yyerrok;}
| TRANSITION transition_priority FROM TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "no origin step(s) defined in transition declaration."); yynerrs++;}
| TRANSITION transition_name transition_priority FROM TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "no origin step(s) defined in transition declaration."); yynerrs++;}
| TRANSITION transition_priority FROM error TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid origin step(s) defined in transition declaration."); yyerrok;}
| TRANSITION transition_name transition_priority FROM error TO steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@5), locl(@5), "invalid origin step(s) defined in transition declaration."); yyerrok;}
| TRANSITION transition_priority FROM steps steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@4), locf(@5), "'TO' missing between origin step(s) and destination step(s) in transition declaration."); yynerrs++;}
| TRANSITION transition_name transition_priority FROM steps steps {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@5), locf(@6), "'TO' missing between origin step(s) and destination step(s) in transition declaration."); yynerrs++;}
| TRANSITION transition_priority FROM steps TO {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@5), locf(@7), "no destination step(s) defined in transition declaration."); yynerrs++;}
| TRANSITION transition_name transition_priority FROM steps TO {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@6), locf(@8), "no destination step(s) defined in transition declaration."); yynerrs++;}
| TRANSITION transition_priority FROM steps TO error {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@6), locl(@6), "invalid destination step(s) defined in transition declaration."); yyerrok;}
| TRANSITION transition_name transition_priority FROM steps TO error {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@7), locl(@7), "invalid destination step(s) defined in transition declaration."); yyerrok;}
| TRANSITION transition_priority {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@2), locf(@4), "no origin and destination step(s) defined in transition declaration."); yynerrs++;}
| TRANSITION transition_name transition_priority {cmd_goto_body_state();} transition_condition END_TRANSITION
	{$$ = NULL; print_err_msg(locl(@3), locf(@5), "no origin and destination step(s) defined in transition declaration."); yynerrs++;}
/*| TRANSITION transition_priority FROM steps TO steps {cmd_goto_body_state();} transition_condition error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@6), "unclosed transition declaration."); yyerrok;}
| TRANSITION transition_name transition_priority FROM steps TO steps {cmd_goto_body_state();} transition_condition error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@7), "unclosed transition declaration."); yyerrok;}*/
| TRANSITION error END_TRANSITION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in transition declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

transition_priority:
  /* empty */
  {$$ = NULL;}
| '(' {cmd_goto_sfc_priority_state();} PRIORITY {cmd_pop_state();} ASSIGN integer ')'
	{$$ = $6;}
/* ERROR_CHECK_BEGIN */
/* The following error checking rules have been intentionally commented out. */
/*
| '(' ASSIGN integer ')'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'PRIORITY' missing between '(' and ':=' in transition declaration with priority."); yynerrs++;}
| '(' error ASSIGN integer ')'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "expecting 'PRIORITY' between '(' and ':=' in transition declaration with priority."); yyerrok;}
*/
/* ERROR_CHECK_END */
;


transition_condition:
 start_IL_body_token ':' eol_list simple_instr_list
	{$$ = new transition_condition_c($4, NULL, locloc(@$));}
| ASSIGN expression ';'
	{$$ = new transition_condition_c(NULL, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| start_IL_body_token eol_list simple_instr_list
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "':' missing before IL condition in transition declaration."); yynerrs++;}
| start_IL_body_token ':' eol_list error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@3), locf(@4), "no instructions defined in IL condition of transition declaration.");}
	 else {print_err_msg(locf(@4), locl(@4), "invalid instructions in IL condition of transition declaration."); yyclearin;}
	 yyerrok;
	}
| ASSIGN ';'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no expression defined in ST condition of transition declaration."); yynerrs++;}
| ASSIGN error ';'
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid expression defined in ST condition of transition declaration."); yyerrok;}
| ASSIGN expression error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "expecting ';' after expression defined in ST condition of transition declaration."); yyerrok;}
/* ERROR_CHECK_END */
;



action:
//  ACTION identifier ':' ... 
  ACTION action_name {cmd_goto_body_state();} action_body END_ACTION
	{$$ = new action_c($2, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| ACTION {cmd_goto_body_state();} action_body END_ACTION
  {$$ = NULL; print_err_msg(locl(@1), locf(@3), "no action name defined in action declaration."); yynerrs++;}
| ACTION error {cmd_goto_body_state();} action_body END_ACTION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid action name defined in action declaration."); yyerrok;}
| ACTION action_name {cmd_goto_body_state();} function_block_body END_ACTION
	{$$ = NULL; print_err_msg(locl(@2), locf(@4), "':' missing after action name in action declaration."); yynerrs++;}
/*| ACTION action_name {cmd_goto_body_state();} action_body END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed action declaration."); yyerrok;}*/
| ACTION error END_ACTION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in action declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

action_body:
  ':' function_block_body
  {$$ = $2;}
/* ERROR_CHECK_BEGIN */
| ':' error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no body defined in action declaration.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid body defined in action declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/********************************/
/* B 1.7 Configuration elements */
/********************************/
/* NOTE:
 * It is not clear from reading the specification to which namespace
 * the names of resources, tasks and programs belong to.
 *
 * The following syntax assumes that resource and program names belong to the
 * same namespace as the variables defined within
 * the resource/configuration (i.e. VAR_GLOBAL).
 * Task names belong to a namespace all of their own, since they don't
 * produce conflicts in the syntax parser, so we might just as well
 * leave them be! ;-)
 * The above decision was made taking into
 * account that inside a VAR_CONFIG declaration global variables
 * may be referenced starting off from the resource name as:
 *   resource_name.program_name.variable_name
 * Notice how resource names and program names are used in a very similar
 * manner as are variable names.
 * Using a single namespace for all the above mentioned names
 * also makes it easier to write the syntax parser!! ;-) Using a private
 * namespace for each of the name types (resource names, program names,
 * global varaiable names), i.e. letting the names be re-used across
 * each of the groups (resource, program, global variables), produces
 * reduce/reduce conflicts in the syntax parser. Actually, it is only
 * the resource names that need to be distinguished into a 
 * prev_declared_resource_name so as not to conflict with [gloabl] variable
 * names in the 'data' construct.
 * The program names are only tracked to make sure that two programs do not
 * get the same name.
 *
 * Using a single namespace does have the drawback that the user will
 * not be able to re-use names for resources or programs if these
 * have already been used to name a variable!
 *
 * If it ever becomes necessary to change this interpretation of
 * the syntax, then this section of the syntax parser must be updated!
 */
prev_declared_global_var_name:    prev_declared_global_var_name_token    {$$ = new identifier_c($1, locloc(@$));};
prev_declared_resource_name:      prev_declared_resource_name_token      {$$ = new identifier_c($1, locloc(@$));};
prev_declared_program_name:       prev_declared_program_name_token       {$$ = new identifier_c($1, locloc(@$));};
prev_declared_configuration_name: prev_declared_configuration_name_token {$$ = new identifier_c($1, locloc(@$));};
// prev_declared_task_name:       prev_declared_task_name_token          {$$ = new identifier_c($1, locloc(@$));};






configuration_name: identifier;

/* NOTE: The specification states that valid resource type names
 *       are implementation defined, i.e. each implementaion will define
 *       what resource types it supports.
 *       We are implementing this syntax parser to be used by any
 *       implementation, so at the moment we accept any identifier
 *       as a resource type name.
 *       This implementation should probably be changed in the future. We
 *       should probably have a resource_type_name_token, and let the
 *       implementation load the global symbol library with the
 *       accepted resource type names before parsing the code.
 *
 */
resource_type_name: any_identifier;

configuration_declaration:
/* PRE_PARSING: The rules expected to be applied by the preparser. Will only run if pre-parsing command line option is ON. */
  CONFIGURATION configuration_name END_CONFIGURATION   /* rule that is only expected to be used during preparse state */
	{$$ = NULL; 
	 if (get_preparse_state())    {library_element_symtable.insert($2, prev_declared_configuration_name_token);}
	 else                         {print_err_msg(locl(@1), locf(@3), "no resource(s) nor program(s) defined in configuration declaration."); yynerrs++;}
	 }
/* POST_PARSING: The rules expected to be applied after the preparser runs. Will only run if pre-parsing command line option is ON. */
| CONFIGURATION prev_declared_configuration_name
   global_var_declarations_list
   single_resource_declaration
   {variable_name_symtable.pop();
    direct_variable_symtable.pop();}
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
	{$$ = new configuration_declaration_c($2, $3, $4, $6, $7, locloc(@$));
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	}
| CONFIGURATION prev_declared_configuration_name
   global_var_declarations_list
   resource_declaration_list
   optional_access_declarations
   optional_instance_specific_initializations
 END_CONFIGURATION
	{$$ = new configuration_declaration_c($2, $3, $4, $5, $6, locloc(@$));
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
}
/* STANDARD_PARSING: The rules expected to be applied in single-phase parsing. Will only run if pre-parsing command line option is OFF. */
| CONFIGURATION configuration_name
   global_var_declarations_list
   single_resource_declaration
   {variable_name_symtable.pop();
    direct_variable_symtable.pop();}
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
	{$$ = new configuration_declaration_c($2, $3, $4, $6, $7, locloc(@$));
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 library_element_symtable.insert($2, prev_declared_configuration_name_token);
	}
| CONFIGURATION configuration_name
   global_var_declarations_list
   resource_declaration_list
   optional_access_declarations
   optional_instance_specific_initializations
 END_CONFIGURATION
	{$$ = new configuration_declaration_c($2, $3, $4, $5, $6, locloc(@$));
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 library_element_symtable.insert($2, prev_declared_configuration_name_token);
}
/* ERROR_CHECK_BEGIN */
| CONFIGURATION 
   global_var_declarations_list
   single_resource_declaration
   {variable_name_symtable.pop();
    direct_variable_symtable.pop();}
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no configuration name defined in configuration declaration."); yynerrs++;}
| CONFIGURATION
   global_var_declarations_list
   resource_declaration_list
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no configuration name defined in configuration declaration."); yynerrs++;}
| CONFIGURATION error
   global_var_declarations_list
   single_resource_declaration
   {variable_name_symtable.pop();
    direct_variable_symtable.pop();}
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid configuration name defined in configuration declaration."); yyerrok;}
| CONFIGURATION error
   global_var_declarations_list
   resource_declaration_list
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid configuration name defined in configuration declaration."); yyerrok;}
/*  Rule already covered by the rule to handle the preparse state!
| CONFIGURATION configuration_name
   global_var_declarations_list
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no resource(s) defined in configuration declaration."); yynerrs++;}
*/
| CONFIGURATION configuration_name
   global_var_declarations_list
   error
   optional_access_declarations
   optional_instance_specific_initializations
  END_CONFIGURATION
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid resource(s) defined in configuration declaration."); yyerrok;}
/*| CONFIGURATION configuration_name
   global_var_declarations_list
   single_resource_declaration
   {variable_name_symtable.pop();
    direct_variable_symtable.pop();}
   optional_access_declarations
   optional_instance_specific_initializations
  END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed configuration declaration."); yyerrok;}*/
| CONFIGURATION configuration_name
   global_var_declarations_list
   resource_declaration_list
   optional_access_declarations
   optional_instance_specific_initializations
  END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed configuration declaration."); yyerrok;}
| CONFIGURATION error END_CONFIGURATION
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in configuration declaration."); yyerrok;}
/* ERROR_CHECK_END */
;

// helper symbol for
//  - configuration_declaration
//  - resource_declaration
//
/* NOTE: The IEC 61131-3 v2 standard defines this list as being: [global_var_declarations]
 *        e.g.:
 *          'CONFIGURATION' configuration_name  [global_var_declarations] ...
 *
 *       However, this means that a single VAR_GLOBAL ... END_VAR construct is allowed
 *       in each CONFIGURATION or RESOURCE declaration. If the user wishes to have global
 *       variables with distinct properties (e.g. some with RETAIN, others with CONSTANT,
 *       and yet other variables with none of these qualifiers), the syntax defined in the 
 *       standard does not allow this.
 *       Amazingly, IEC 61131-3 v3 also does not seem to allow it either!!
 *       Since this is most likely a bug in the standard, we are changing the syntax slightly
 *       to become:
 *          'CONFIGURATION' configuration_name  {global_var_declarations} ...
 *
 *       Remember that:
 *          {S}, closure, meaning zero or more concatenations of S.
 *          [S], option, meaning zero or one occurrence of S.
 */
global_var_declarations_list:
  // empty
	{$$ = new global_var_declarations_list_c(locloc(@$));}
| global_var_declarations_list global_var_declarations
	{$$ = $1; $$->add_element($2);}
;

// helper symbol for configuration_declaration //
optional_access_declarations:
  // empty
	{$$ = NULL;}
//| access_declarations
;

// helper symbol for configuration_declaration //
optional_instance_specific_initializations:
  // empty
	{$$ = NULL;}
| instance_specific_initializations
;

// helper symbol for configuration_declaration //
resource_declaration_list:
  resource_declaration
	{$$ = new resource_declaration_list_c(locloc(@$)); $$->add_element($1);}
| resource_declaration_list resource_declaration
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| resource_declaration_list error
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected token after resource declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


resource_declaration:
  RESOURCE {variable_name_symtable.push();direct_variable_symtable.push();} resource_name {variable_name_symtable.insert($3, prev_declared_resource_name_token);} ON resource_type_name
   global_var_declarations_list
   single_resource_declaration
  END_RESOURCE
	{$$ = new resource_declaration_c($3, $6, $7, $8, locloc(@$));
	 variable_name_symtable.pop();
	 direct_variable_symtable.pop();
	 variable_name_symtable.insert($3, prev_declared_resource_name_token);
	}
/* ERROR_CHECK_BEGIN */
| RESOURCE {variable_name_symtable.push();direct_variable_symtable.push();} ON resource_type_name
   global_var_declarations_list
   single_resource_declaration
  END_RESOURCE
  {$$ = NULL; print_err_msg(locl(@1), locf(@3), "no resource name defined in resource declaration."); yynerrs++;}
/*|	RESOURCE {variable_name_symtable.push();direct_variable_symtable.push();} resource_name ON resource_type_name
   global_var_declarations_list
   single_resource_declaration
  END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@5), "unclosed resource declaration."); yyerrok;}*/
| RESOURCE error END_RESOURCE
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in resource declaration."); yyerrok;}
/* ERROR_CHECK_END */
;


single_resource_declaration:
 task_configuration_list program_configuration_list
	{$$ = new single_resource_declaration_c($1, $2, locloc(@$));}
;


// helper symbol for single_resource_declaration //
task_configuration_list:
  // empty
	{$$ = new task_configuration_list_c(locloc(@$));}
| task_configuration_list task_configuration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| task_configuration_list task_configuration error
  {$$ = $1; print_err_msg(locl(@1), locf(@2), "';' missing at the end of task configuration in resource declaration."); yyerrok;}
| task_configuration_list ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after task configuration in resource declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


// helper symbol for single_resource_declaration //
program_configuration_list:
  program_configuration ';'
	{$$ = new program_configuration_list_c(locloc(@$)); $$->add_element($1);}
| program_configuration_list program_configuration ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| program_configuration error
  {$$ = new program_configuration_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at the end of program configuration in resource declaration."); yyerrok;}
| program_configuration_list program_configuration error
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at the end of program configuration in resource declaration."); yyerrok;}
| program_configuration_list error ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid program configuration in resource declaration."); yyerrok;}
| program_configuration_list ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after program configuration in resource declaration."); yynerrs++;}
/* ERROR_CHECK_END */
;


resource_name: identifier;

/*
access_declarations:
 VAR_ACCESS access_declaration_list END_VAR
	{$$ = NULL;}
// ERROR_CHECK_BEGIN //
| VAR_ACCESS END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in access variable(s) declaration."); yynerrs++;}
| VAR_ACCESS error access_declaration_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_ACCESS' in access variable(s) declaration."); yyerrok;}
| VAR_ACCESS access_declaration_list error END_VAR
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed access variable(s) declaration."); yyerrok;}
| VAR_ACCESS error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in access variable(s) declaration."); yyerrok;}
// ERROR_CHECK_END //
;

// helper symbol for access_declarations //
access_declaration_list:
  access_declaration ';'
| access_declaration_list access_declaration ';'
// ERROR_CHECK_BEGIN //
| error ';'
  {$$ = // create a new list //;
	 print_err_msg(locf(@1), locl(@1), "invalid access variable declaration."); yyerrok;}
| access_declaration error
  {$$ = // create a new list //;
	 print_err_msg(locl(@1), locf(@2), "';' missing at the end of access variable declaration."); yyerrok;}
| access_declaration_list access_declaration error
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at the end of access variable declaration."); yyerrok;}
| access_declaration_list error ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid access variable declaration."); yyerrok;}
| access_declaration_list ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after access variable declaration."); yynerrs++;}
// ERROR_CHECK_END //
;


access_declaration:
  access_name ':' access_path ':' non_generic_type_name
| access_name ':' access_path ':' non_generic_type_name direction
;


access_path:
  prev_declared_direct_variable
| prev_declared_resource_name '.' prev_declared_direct_variable
| any_fb_name_list symbolic_variable
| prev_declared_resource_name '.' any_fb_name_list symbolic_variable
| prev_declared_program_name '.'  any_fb_name_list symbolic_variable
| prev_declared_resource_name '.' prev_declared_program_name '.' any_fb_name_list symbolic_variable
;
*/

// helper symbol for
//  - access_path
//  - instance_specific_init
//
/* NOTE: The fb_name_list refers to funtion block variables
 *       that have been declared in a scope outside the one we are
 *       currently parsing, so we must accept them to be any_identifier!
 *
 *       Beware that other locations of this syntax parser also require
 *       a fb_name_list. In those locations the function blocks are being declared,
 *       so only currently un-used identifiers (i.e. identifier) may be accepted.
 *
 *       In order to distinguish the two, here we use any_fb_name_list, while
 *       in the the locations we simply use fb_name_list!
 */
any_fb_name_list:
  // empty
	{$$ = new any_fb_name_list_c(locloc(@$));}
//| fb_name_list fb_name '.'
| any_fb_name_list any_identifier '.'
	{$$ = $1; $$->add_element($2);}
;



global_var_reference:
//  [resource_name '.'] global_var_name ['.' structure_element_name] //
                                  prev_declared_global_var_name
	{$$ = new global_var_reference_c(NULL, $1, NULL, locloc(@$));}
|                                 prev_declared_global_var_name '.' structure_element_name
	{$$ = new global_var_reference_c(NULL, $1, $3, locloc(@$));}
| prev_declared_resource_name '.' prev_declared_global_var_name
	{$$ = new global_var_reference_c($1, $3, NULL, locloc(@$));}
| prev_declared_resource_name '.' prev_declared_global_var_name '.' structure_element_name
	{$$ = new global_var_reference_c($1, $3, $5, locloc(@$));}
;


//access_name: identifier;


program_output_reference:
/* NOTE:
 * program_output_reference is merely used within data_source.
 * data_source is merely used within task_initialization
 * task_initialization appears in a configuration declaration
 * _before_ the programs are declared, so we cannot use
 * prev_declared_program_name, as what might seem correct at first.
 *
 * The semantic checker must later check whether the identifier
 * used really refers to a program declared after the task
 * initialization!
 */
//  prev_declared_program_name '.' symbolic_variable
  program_name '.' symbolic_variable
	{$$ = new program_output_reference_c($1, $3, locloc(@$));}
;

program_name: identifier;

/*
direction:
  READ_WRITE
	{$$ = NULL;}
| READ_ONLY
	{$$ = NULL;}
;
*/

task_configuration:
  TASK task_name task_initialization
	{$$ = new task_configuration_c($2, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| TASK task_initialization
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no task name defined in task declaration."); yynerrs++;}
| TASK error task_initialization
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid task name defined in task declaration."); yyerrok;}
| TASK task_name error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no task initialization defined in task declaration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid task initialization in task declaration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* NOTE: The specification does not mention the namespace to which task names
 *       should belong to. Unlike resource and program names, for the moment we
 *       let the task names belong to their own private namespace, as they do not
 *       produce any conflicts in the syntax parser.
 *       If in the future our interpretation of the spec. turns out to be incorrect,
 *       the definition of task_name may have to be changed!
 */
task_name: any_identifier;


task_initialization:
//  '(' [SINGLE ASSIGN data_source ','] [INTERVAL ASSIGN data_source ','] PRIORITY ASSIGN integer ')' //
  '(' {cmd_goto_task_init_state();} task_initialization_single task_initialization_interval task_initialization_priority ')'
	{$$ = new task_initialization_c($3, $4, $5, locloc(@$));}
;


task_initialization_single:
// [SINGLE ASSIGN data_source ',']
  /* empty */
	{$$ = NULL;}
| SINGLE ASSIGN {cmd_pop_state();} data_source ',' {cmd_goto_task_init_state();} 
	{$$ = $4;}
/* ERROR_CHECK_BEGIN */
| SINGLE {cmd_pop_state();} data_source ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locl(@1), locf(@3), "':=' missing after 'SINGLE' in task initialization."); yynerrs++;}
| SINGLE ASSIGN {cmd_pop_state();} ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locl(@2), locf(@4), "no data source defined in 'SINGLE' statement of task initialization."); yynerrs++;}
| SINGLE ASSIGN {cmd_pop_state();} error ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid data source defined in 'SINGLE' statement of task initialization."); yyerrok;}
/* ERROR_CHECK_END */
;


task_initialization_interval:
// [INTERVAL ASSIGN data_source ','] 
  /* empty */
	{$$ = NULL;}
| INTERVAL ASSIGN {cmd_pop_state();} data_source ',' {cmd_goto_task_init_state();}
	{$$ = $4;}
/* ERROR_CHECK_BEGIN */
| INTERVAL {cmd_pop_state();} data_source ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locl(@1), locf(@3), "':=' missing after 'INTERVAL' in task initialization.");}
| INTERVAL ASSIGN {cmd_pop_state();} ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locl(@2), locf(@4), "no data source defined in 'INTERVAL' statement of task initialization."); yynerrs++;}
| INTERVAL ASSIGN {cmd_pop_state();} error ',' {cmd_goto_task_init_state();}
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid data source defined in 'INTERVAL' statement of task initialization."); yyerrok;}
/* ERROR_CHECK_END */
;



task_initialization_priority:
// PRIORITY ASSIGN integer
  PRIORITY ASSIGN {cmd_pop_state();} integer 
	{$$ = $4;}
/* ERROR_CHECK_BEGIN */
| PRIORITY {cmd_pop_state();} integer
  {$$ = NULL; print_err_msg(locl(@1), locf(@3), "':=' missing after 'PRIORITY' in task initialization."); yynerrs++;}
| PRIORITY ASSIGN {cmd_pop_state();} error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@4), "no priority number defined in 'PRIORITY' statement of task initialization.");}
	 else {print_err_msg(locf(@4), locl(@4), "invalid priority number in 'PRIORITY' statement of task initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



data_source:
  constant
| global_var_reference
| program_output_reference
| prev_declared_direct_variable
;

program_configuration:
//  PROGRAM [RETAIN | NON_RETAIN] program_name [WITH task_name] ':' program_type_name ['(' prog_conf_elements ')'] //
  PROGRAM program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
	{$$ = new program_configuration_c(NULL, $2, $3, $5, $6, locloc(@$));
	 variable_name_symtable.insert($2, prev_declared_program_name_token);
	}
| PROGRAM RETAIN program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
	{$$ = new program_configuration_c(new retain_option_c(locloc(@2)), $3, $4, $6, $7, locloc(@$));
	 variable_name_symtable.insert($3, prev_declared_program_name_token);
	}
| PROGRAM NON_RETAIN program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
	{$$ = new program_configuration_c(new non_retain_option_c(locloc(@2)), $3, $4, $6, $7, locloc(@$));
	 variable_name_symtable.insert($3, prev_declared_program_name_token);
	}
/* ERROR_CHECK_BEGIN */
| PROGRAM program_name optional_task_name ':' identifier optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@5), locl(@5), "invalid program type name after ':' in program configuration."); yynerrs++;}
| PROGRAM RETAIN program_name optional_task_name ':' identifier optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@6), locl(@6), "invalid program type name after ':' in program configuration."); yynerrs++;}
| PROGRAM NON_RETAIN program_name optional_task_name ':' identifier optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@6), locl(@6), "invalid program type name after ':' in program configuration."); yynerrs++;}
| PROGRAM error program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'PROGRAM' in program configuration."); yyerrok;}
| PROGRAM RETAIN error program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'RETAIN' in retentive program configuration."); yyerrok;}
| PROGRAM NON_RETAIN error program_name optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "unexpected token after 'NON_RETAIN' in non-retentive program configuration."); yyerrok;}
| PROGRAM optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no program name defined in program configuration."); yynerrs++;}
| PROGRAM RETAIN optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "no program name defined in retentive program configuration."); yynerrs++;}
| PROGRAM NON_RETAIN optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "no program name defined in non-retentive program configuration."); yynerrs++;}
| PROGRAM error optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid program name defined in program configuration."); yyerrok;}
| PROGRAM RETAIN error optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid program name defined in retentive program configuration."); yyerrok;}
| PROGRAM NON_RETAIN error optional_task_name ':' prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid program name defined in non-retentive program configuration."); yyerrok;}
| PROGRAM program_name optional_task_name prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "':' missing after program name or optional task name in program configuration."); yynerrs++;}
| PROGRAM RETAIN program_name optional_task_name prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "':' missing after program name or optional task name in retentive program configuration."); yynerrs++;}
| PROGRAM NON_RETAIN program_name optional_task_name prev_declared_program_type_name optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "':' missing after program name or optional task name in non-retentive program configuration."); yynerrs++;}
| PROGRAM program_name optional_task_name ':' optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "no program type defined in program configuration."); yynerrs++;}
| PROGRAM RETAIN program_name optional_task_name ':' optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@5), locf(@6), "no program type defined in retentive program configuration."); yynerrs++;}
| PROGRAM NON_RETAIN program_name optional_task_name ':' optional_prog_conf_elements
  {$$ = NULL; print_err_msg(locl(@5), locf(@6), "no program type defined in non-retentive program configuration."); yynerrs++;}
/* ERROR_CHECK_END */
;

// helper symbol for program_configuration //
optional_task_name:
  // empty //
	{$$ = NULL;}
| WITH task_name
	{$$ = $2;}
/* ERROR_CHECK_BEGIN */
| WITH error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no task name defined in optional task name of program configuration.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid task name in optional task name of program configuration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

// helper symbol for program_configuration //
optional_prog_conf_elements:
  // empty //
	{$$ = NULL;}
| '(' prog_conf_elements ')'
	{$$ = $2;}
/* ERROR_CHECK_BEGIN */
| '(' error ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid program configuration elements in program configuration."); yyerrok;}
| '(' prog_conf_elements error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing at the end of program configuration elements in program configuration."); yyerrok;}
/* ERROR_CHECK_END */
;


prog_conf_elements:
  prog_conf_element
	{$$ = new prog_conf_elements_c(locloc(@$)); $$->add_element($1);}
| prog_conf_elements ',' prog_conf_element
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| prog_conf_elements prog_conf_element
  {$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in program configuration elements list."); yynerrs++;}
| prog_conf_elements ',' error
  {$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value defined for program configuration element in program configuration list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value for program configuration element in program configuration list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


prog_conf_element:
  fb_task
| prog_cnxn
;


fb_task:
  // fb_name WITH task_name
/* NOTE: The fb_name refers to funtion block variables
 *       that have been declared in a scope outside the one we are
 *       currently parsing, so we must accept them to be any_identifier!
 */
  any_identifier WITH task_name
	{$$ = new fb_task_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| any_identifier WITH error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no task name defined in function block configuration.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid task name in function block configuration."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/* NOTE:
 *  The semantics of configuring a program are rather confusing, so here is
 *  my (Mario) understanding on the issue...
 *
 *  A function/program may have as its input variables a simple variable
 *  (BYTE, WORD, etc...), an array (ARRAY [1 .. 3] OF BYTE, ...) , or a structure.
 *  Nevertheless, when calling this function from within a st or il language statement
 *  it is not possible to allocate a value to a single element of the array or structure
 *  typed input variable, as the accepted syntax is simply '(' variable_name ':=' variable ')'
 *  Notice how the variable_name does not include things such as 'a.elem1' or 'a[1]'!
 *
 *  Nevertheless, when configuring a program from within a configuration,
 *  it becomes possible to allocate values to individual elements of the
 *  array or structured type input variable, as the syntax is now
 *  '(' symbolic_variable ':=' data_sink|prog_data_source ')'
 *  Notice how the symbolic_variable _does_ include things such as 'a.elem1' or 'a[1]'!
 *
 *  Conclusion: Unlike other locations in the syntax where SENDTO appears,
 *  here it is not valid to replace symbolic_variable with any_identifier!
 *  Nevertheless, it is also not correct to leave symbolic_variable as it is,
 *  as we have defined it to only include previously declared variables,
 *  which is not the case in this situation. Here symbolic_variable is refering
 *  to variables that were defined within the scope of the program that is being
 *  called, and _not_ within the scope of the configuration that is calling the
 *  program, so the variables in question are not declared in the current scope!
 *
 *  We therefore need to define a new symbolic_variable, that accepts any_identifier
 *  instead of previosuly declared variable names, to be used in the definition of
 *  prog_cnxn!
 */
prog_cnxn:
  any_symbolic_variable ASSIGN prog_data_source
	{$$ = new prog_cnxn_assign_c($1, $3, locloc(@$));}
| any_symbolic_variable SENDTO data_sink
	{$$ = new prog_cnxn_sendto_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| any_symbolic_variable constant
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing between parameter and value in program configuration element."); yynerrs++;}
| any_symbolic_variable enumerated_value
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing between parameter and value in program configuration element."); yynerrs++;}
| any_symbolic_variable data_sink
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' or '=>' missing between parameter and variable in program configuration element."); yynerrs++;}
| any_symbolic_variable ASSIGN error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no value or variable defined in program configuration assignment element.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid value or variable in program configuration assignment element."); yyclearin;}
	 yyerrok;
	}
| any_symbolic_variable SENDTO error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no variable defined in program configuration sendto element.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid variable in program configuration sendto element."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

prog_data_source:
  constant
| enumerated_value
| global_var_reference
| prev_declared_direct_variable
;

data_sink:
  global_var_reference
| prev_declared_direct_variable
;

instance_specific_initializations:
 VAR_CONFIG instance_specific_init_list END_VAR
	{$$ = new instance_specific_initializations_c($2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| VAR_CONFIG END_VAR
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "no variable declared in configuration variable(s) initialization."); yynerrs++;}
| VAR_CONFIG error instance_specific_init_list END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unexpected token after 'VAR_CONFIG' in configuration variable(s) initialization."); yyerrok;}
| VAR_CONFIG instance_specific_init_list error END_OF_INPUT
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed configuration variable(s) initialization."); yyerrok;}
| VAR_CONFIG error END_VAR
	{$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in configuration variable(s) initialization."); yyerrok;}
/* ERROR_CHECK_END */
;

// helper symbol for instance_specific_initializations //
instance_specific_init_list:
  instance_specific_init ';'
	{$$ = new instance_specific_init_list_c(locloc(@$)); $$->add_element($1);}
| instance_specific_init_list instance_specific_init ';'
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| error ';'
  {$$ = new instance_specific_init_list_c(locloc(@$)); print_err_msg(locf(@1), locl(@1), "invalid configuration variable initialization."); yyerrok;}
| instance_specific_init error
  {$$ = new instance_specific_init_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at the end of configuration variable initialization."); yyerrok;}
| instance_specific_init_list instance_specific_init error
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at the end of configuration variable initialization."); yyerrok;}
| instance_specific_init_list error ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid configuration variable initialization."); yyerrok;}
| instance_specific_init_list ';'
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after configuration variable initialization."); yynerrs++;}
/* ERROR_CHECK_END */
;


instance_specific_init:
//
//  resource_name '.' program_name '.' {fb_name '.'}
//  ((variable_name [location] ':' located_var_spec_init) | (fb_name ':' function_block_type_name ':=' structure_initialization))
//
//  prev_declared_resource_name '.' prev_declared_program_name '.' any_fb_name_list variable_name ':' located_var_spec_init
/* NOTE: variable_name has been changed to any_identifier (and not simply identifier) because the
 *       variables being referenced have been declared outside the scope currently being parsed!
 */
/* NOTE: program_name has not been changed to prev_declared_program_name because the
 *       programs being referenced have been declared outside the scope currently being parsed!
 *       The programs are only kept inside the scope of the resource in which they are defined.
 */
  prev_declared_resource_name '.' program_name '.' any_fb_name_list any_identifier ':' located_var_spec_init
	{$$ = new instance_specific_init_c($1, $3, $5, $6, NULL, $8, locloc(@$));}
| prev_declared_resource_name '.' program_name '.' any_fb_name_list any_identifier location ':' located_var_spec_init
	{$$ = new instance_specific_init_c($1, $3, $5, $6, $7, $9, locloc(@$));}
| prev_declared_resource_name '.' program_name '.' any_fb_name_list any_identifier ':' fb_initialization
	{$5->add_element($6); $$ = new instance_specific_init_c($1, $3, $5, NULL, NULL, $8, locloc(@$));}
;


/* helper symbol for instance_specific_init */
fb_initialization:
  function_block_type_name ASSIGN structure_initialization
	{$$ = new fb_initialization_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| function_block_type_name structure_initialization
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':=' missing between function block name and initialization in function block initialization."); yynerrs++;}
| function_block_type_name ASSIGN error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no initial value defined in function block initialization.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid initial value in function block initialization."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/***********************************/
/* B 2.1 Instructions and Operands */
/***********************************/
/* helper symbol for many IL instructions, etc... */
/* eat up any extra EOL tokens... */

eol_list:
  EOL
| eol_list EOL
;



instruction_list:
  il_instruction
	{$$ = new instruction_list_c(locloc(@$)); $$->add_element($1);}
| any_pragma eol_list
	{$$ = new instruction_list_c(locloc(@1)); $$->add_element($1);} /* locloc(@1) is not a bug! We ignore trailing EOLs when determining symbol location! */
| instruction_list il_instruction
	{$$ = $1; $$->add_element($2);}
| instruction_list any_pragma
	{$$ = $1; $$->add_element($2);}
;



il_instruction:
  il_incomplete_instruction eol_list
	{$$ = new il_instruction_c(NULL, $1, locloc(@1));} /* locloc(@1) is not a bug! We ignore trailing EOLs when determining symbol location! */
| label ':' il_incomplete_instruction eol_list
	{$$ = new il_instruction_c($1, $3, locf(@1), locl(@3));} /* locf(@1), locl(@3) is not a bug! We ignore trailing EOLs when determining symbol location! */
| label ':' eol_list
	{$$ = new il_instruction_c($1, NULL, locf(@1), locl(@2));} /* locf(@1), locl(@2) is not a bug! We ignore trailing EOLs when determining symbol location! */
/* ERROR_CHECK_BEGIN */
| error eol_list
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid IL instruction."); yyerrok;}
| il_incomplete_instruction error
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "EOL missing at the end of IL instruction."); yyerrok;}
| error ':' il_incomplete_instruction eol_list
	{$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid label in IL instruction."); yyerrok;}
| label il_incomplete_instruction eol_list
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing after label in IL instruction."); yynerrs++;}
| label ':' error eol_list
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid IL instruction."); yyerrok;}
| label ':' il_incomplete_instruction error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "EOL missing at the end of IL instruction."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for il_instruction */
il_incomplete_instruction:
  il_simple_operation
| il_expression
| il_jump_operation
| il_fb_call
| il_formal_funct_call
| il_return_operator
;


label: identifier;



il_simple_operation:
// (il_simple_operator [il_operand]) | (function_name [il_operand_list])
  il_simple_operator
	{$$ = new il_simple_operation_c($1, NULL, locloc(@$));}
/*
 * Note: Bison is getting confused with the following rule,
 *       i.e. it is finding conflicts where there seemingly are really none.
 *       The rule was therefore replaced by the equivalent following
 *       two rules.
 */
/*
| il_simple_operator il_operand
	{$$ = new il_simple_operation_c($1, $2, locloc(@$));}
*/
| il_simple_operator_noclash il_operand
	{$$ = new il_simple_operation_c($1, $2, locloc(@$));}
| il_simple_operator_clash il_operand
	{$$ = new il_simple_operation_c($1, $2, locloc(@$));}
/* NOTE: the line
 *         | il_simple_operator
 *       already contains the 'NOT' operator, as well as all the
 *       expression operators ('MOD', 'AND', etc...), all of which
 *       may also be a function name! This means that these operators/functions,
 *       without any operands, could be reduced to either an operator or a
 *       function call. 
 *
 *       I (Mario) have chosen to reduce it to an operator.
 *       In order to do this, we must remove from the syntax that defines
 *       function calls all the functions whose names clash with the IL operators.
 *
 *       The line
 *         | function_name
 *       has been replaced with the lines
 *         | function_name_no_clashes
 *       in order to include all possible function names except
 *       those whose names coincide with operators !!
 */
| function_name_no_clashes
	{$$ = new il_function_call_c($1, NULL, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
/* NOTE: the line
 *         | il_simple_operator il_operand
 *       already contains the 'NOT', 'MOD', etc. operators, followed by a single il_operand.
 *       However, this same code (MOD x) may also be reduced to a function call to the MOD
 *       function. This means that (MOD, AND,...) could be interpret as a function name
 *       or as an IL operator! This would lead us to a reduce/reduce conflict!
 *
 *       I (Mario) have chosen to reduce it to an operand, rather than a function call.
 *       In order to do this, we must remove from the syntax that defines
 *       function calls all the functions whose names clash with the IL operators.
 *
 *       The line
 *         | function_name il_operand_list
 *       has been replaced with the line
 *         | function_name_no_clashes il_operand_list
 *       in order to include all possible function names except
 *       for the function names which clash with expression and simple operators.
 *
 *       Note that:
 *       this alternative syntax does not cover the possibility of
 *       the function 'NOT', 'MOD', etc... being called with more than one il_operand,
 *       in which case it is always a function call, and not an IL instruction.
 *       We therefore need to include an extra rule where the
 *       function_name_expression_clashes and function_name_simpleop_clashes
 *       are followed by a il_operand_list with __two__ or more il_operands!!
 */
| function_name_no_clashes il_operand_list
	{$$ = new il_function_call_c($1, $2, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
| il_simple_operator_clash il_operand_list2
	{$$ = new il_function_call_c(il_operator_c_2_poutype_identifier_c($1), $2, locloc(@$));}
;



il_expression:
// il_expr_operator '(' [il_operand] EOL {EOL} [simple_instr_list] ')'
/* IMPORTANT NOTE:
 *  When the <il_operand> exists, and to make it easier to handle the <il_operand> as a general case (i.e. without C++ code handling this as a special case), 
 *  we will create an equivalent LD <il_operand> IL instruction, and prepend it into the <simple_instr_list>. 
 *  The remainder of the compiler may from now on assume that the code being compiled does not contain any IL code like
 *     LD 1
 *     ADD ( 2
 *        SUB 3
 *        )
 *
 * but instead, the equivalent code
 *     LD 1
 *     ADD ( 
 *        LD  2
 *        SUB 3
 *        )
 *
 * Note, however, that in the first case, we still store in the il_expression_c a pointer to the <il_operand> (the literal '2' in the above example), in case
 * somewhere further on in the compiler we really want to handle it as a special case. To handle it as a special case, it should be easy to simply delete the first
 * artificial entry in <simple_instr_list> with il_expression->simple_instr_list->remove_element(0)  !!
 */
/*
 * Note: Bison is getting confused with the use of il_expr_operator,
 *       i.e. it is finding conflicts where there seemingly are really none.
 *       il_expr_operator was therefore replaced by the equivalent 
 *       il_expr_operator_noclash | il_expr_operator_clash.
 */
  il_expr_operator_noclash '(' eol_list ')'
	{$$ = new il_expression_c($1, NULL, NULL, locloc(@$));}
| il_expr_operator_noclash '(' il_operand eol_list ')'
	{ simple_instr_list_c *tmp_simple_instr_list = new simple_instr_list_c(locloc(@3));
	  tmp_simple_instr_list ->insert_element(new il_simple_instruction_c(new il_simple_operation_c(new LD_operator_c(locloc(@3)), $3, locloc(@3)), locloc(@3)), 0);
	  $$ = new il_expression_c($1, $3, tmp_simple_instr_list, locloc(@$));
	}
| il_expr_operator_noclash '(' eol_list simple_instr_list ')'
	{$$ = new il_expression_c($1, NULL, $4, locloc(@$));}
| il_expr_operator_noclash '(' il_operand eol_list simple_instr_list ')'
	{ simple_instr_list_c *tmp_simple_instr_list = dynamic_cast <simple_instr_list_c *> $5;
	  tmp_simple_instr_list ->insert_element(new il_simple_instruction_c(new il_simple_operation_c(new LD_operator_c(locloc(@3)), $3, locloc(@3)), locloc(@3)), 0);
	  $$ = new il_expression_c($1, $3, $5, locloc(@$));
	}
| il_expr_operator_clash '(' eol_list ')'
	{$$ = new il_expression_c($1, NULL, NULL, locloc(@$));}
| il_expr_operator_clash '(' il_operand eol_list ')'
	{ simple_instr_list_c *tmp_simple_instr_list = new simple_instr_list_c(locloc(@3));
	  tmp_simple_instr_list ->insert_element(new il_simple_instruction_c(new il_simple_operation_c(new LD_operator_c(locloc(@3)), $3, locloc(@3)), locloc(@3)), 0);
	  $$ = new il_expression_c($1, $3, tmp_simple_instr_list, locloc(@$));
	}
| il_expr_operator_clash '(' il_operand eol_list simple_instr_list ')'
	{ simple_instr_list_c *tmp_simple_instr_list = dynamic_cast <simple_instr_list_c *> $5;
	  tmp_simple_instr_list ->insert_element(new il_simple_instruction_c(new il_simple_operation_c(new LD_operator_c(locloc(@3)), $3, locloc(@3)), locloc(@3)), 0);
	  $$ = new il_expression_c($1, $3, $5, locloc(@$));
	}
| il_expr_operator_clash_eol_list simple_instr_list ')'
	{$$ = new il_expression_c($1, NULL, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| il_expr_operator_noclash '(' eol_list error
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_noclash '(' il_operand eol_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_noclash '(' eol_list simple_instr_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_noclash '(' il_operand eol_list simple_instr_list error
  {$$ = NULL; print_err_msg(locl(@5), locf(@6), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_clash '(' il_operand eol_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_clash '(' il_operand eol_list simple_instr_list error
  {$$ = NULL; print_err_msg(locl(@5), locf(@6), "')' missing at the end of IL expression."); yyerrok;}
| il_expr_operator_clash_eol_list simple_instr_list error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing at the end of IL expression."); yyerrok;}
/* ERROR_CHECK_END */
;


il_jump_operation:
  il_jump_operator label
	{$$ = new il_jump_operation_c($1, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| il_jump_operator error
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid label defined in IL jump operation."); yyerrok;}
/* ERROR_CHECK_END */
;


il_fb_call:
// il_call_operator fb_name ['(' (EOL {EOL} [il_param_list]) | [il_operand_list] ')']
  il_call_operator prev_declared_fb_name
	{$$ = new il_fb_call_c($1, $2, NULL, NULL, locloc(@$));}
| il_call_operator prev_declared_fb_name '(' ')'
	{$$ = new il_fb_call_c($1, $2, NULL, NULL, locloc(@$));}
| il_call_operator prev_declared_fb_name '(' eol_list ')'
	{$$ = new il_fb_call_c($1, $2, NULL, NULL, locloc(@$));}
| il_call_operator prev_declared_fb_name '(' il_operand_list ')'
	{$$ = new il_fb_call_c($1, $2, $4, NULL, locloc(@$));}
| il_call_operator prev_declared_fb_name '(' eol_list il_param_list ')'
	{$$ = new il_fb_call_c($1, $2, NULL, $5, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| il_call_operator error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no function block name defined in IL function block call.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid function block name in IL function block call."); yyclearin;}
	 yyerrok;
	}
| il_call_operator '(' ')'
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block name defined in IL function block call."); yynerrs++;}
| il_call_operator '(' eol_list ')'
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block name defined in IL function block call."); yynerrs++;}
| il_call_operator '(' il_operand_list ')'
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block name defined in IL function block call."); yynerrs++;}
| il_call_operator '(' eol_list il_param_list ')'
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no function block name defined in IL function block call."); yynerrs++;}
| il_call_operator error '(' ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid function block name defined in IL function block call."); yyerrok;}
| il_call_operator error '(' eol_list ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid function block name defined in IL function block call."); yyerrok;}
| il_call_operator error '(' il_operand_list ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid function block name defined in IL function block call."); yyerrok;}
| il_call_operator error '(' eol_list il_param_list ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid function block name defined in IL function block call."); yyerrok;}
| il_call_operator prev_declared_fb_name ')'
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "'(' missing after function block name defined in IL function block call."); yynerrs++;}
| il_call_operator prev_declared_fb_name il_operand_list ')'
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "'(' missing after function block name defined in IL function block call."); yynerrs++;}
| il_call_operator prev_declared_fb_name '(' error
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing at the end of IL function block call."); yyerrok;}
| il_call_operator prev_declared_fb_name '(' eol_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of IL function block call."); yyerrok;}
| il_call_operator prev_declared_fb_name '(' il_operand_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of IL function block call."); yyerrok;}
/* ERROR_CHECK_END */
;


/* NOTE: Please read note above the definition of function_name_without_clashes */
il_formal_funct_call:
// function_name '(' EOL {EOL} [il_param_list] ')'
/*  function_name '(' eol_list ')'  */
/* NOTE: il_formal_funct_call is only used in the definition of
 *         - il_incomplete_instruction
 *         - il_simple_instruction
 *       In both of the above, il_expression also
 *       shows up as another option. This means that the functions whose
 *       names clash with expressions, followed by '(' eol_list ')', are
 *       already included. We must therefore leave them out in this
 *       definition in order to remove reduce/reduce conflicts.
 *
 *       In summary: 'MOD' '(' eol_list ')', and all other functions whose
 *       names clash with expressions may be interpreted by the syntax by
 *       two different routes. I (Mario) chose to interpret them
 *       as operators, rather than as function calls!
 *       (AND MOD OR XOR ADD DIV EQ GT GE LT LE MUL NE SUB)
 */
  function_name_no_clashes '(' eol_list ')'
	{$$ = new il_formal_funct_call_c($1, NULL, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
| function_name_simpleop_clashes '(' eol_list ')'
	{$$ = new il_formal_funct_call_c($1, NULL, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
/* | function_name '(' eol_list il_param_list ')' */
/* For the above syntax, we no longer have two ways of interpreting the
 * same syntax. The above is always a function call!
 * However, some of the functions that we may be calling
 * may have the same name as an IL operator. This means that
 * flex will be parsing them and handing them over to bison as
 * IL operator tokens, and not as function name tokens.
 * (when parsing ST, flex no longer recognizes IL operators,
 * so will always return the correct function name, unless that
 * name also coincides with an operator used in ST -> XOR, OR, MOD, AND, NOT)
 *
 * We must therefore interpret the IL operators as function names!
 */
| function_name_no_clashes '(' eol_list il_param_list ')'
	{$$ = new il_formal_funct_call_c($1, $4, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
| function_name_simpleop_clashes '(' eol_list il_param_list ')'
	{$$ = new il_formal_funct_call_c($1, $4, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
/* The following line should read:
 *
 * | function_name_expression_clashes '(' eol_list il_param_list ')'
 *
 * but the function_name_expression_clashes had to be first reduced to
 * an intermediary symbol in order to remove a reduce/reduce conflict.
 * In essence, the syntax requires more than one look ahead token
 * in order to be parsed. We resolve this by reducing a collection of
 * symbols into a temporary symbol (il_expr_operator_clash_eol_list), that
 * will later be replaced by the correct symbol. The correct symbol will
 * now be determined by a single look ahead token, as all the common
 * symbols have been reduced to the temporary symbol
 * il_expr_operator_clash_eol_list !
 *
 * Unfortunately, this work around results in the wrong symbol
 * being created for the abstract syntax tree.
 * We need to figure out which symbol was created, destroy it,
 * and create the correct symbol for our case.
 * This is a lot of work, so I put it in a function
 * at the end of this file... il_operator_c_2_poutype_identifier_c()
 */
| il_expr_operator_clash_eol_list il_param_list ')'
	{$$ = new il_formal_funct_call_c(il_operator_c_2_poutype_identifier_c($1), $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| function_name_no_clashes '(' eol_list error ')'
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid parameter list defined in IL formal function call."); yyerrok;} 
| function_name_simpleop_clashes '(' eol_list error ')'
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid parameter list defined in IL formal function call."); yyerrok;} 
| il_expr_operator_clash_eol_list error ')'
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid parameter list defined in IL formal function call."); yyerrok;} 
/* ERROR_CHECK_END */
;


il_expr_operator_clash_eol_list:
  il_expr_operator_clash '(' eol_list
	{$$ = $1;}
/* ERROR_CHECK_BEGIN */
| il_expr_operator_clash '(' error
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "EOL missing after '(' in IL instruction."); yyerrok;}
/* ERROR_CHECK_END */
;


il_operand:
  variable
| enumerated_value
| constant
;


il_operand_list:
  il_operand
	{$$ = new il_operand_list_c(locloc(@$)); $$->add_element($1);}
| il_operand_list2
;


/* List with 2 or more il_operands */ 
il_operand_list2:
  il_operand ',' il_operand 
	{$$ = new il_operand_list_c(locloc(@$)); $$->add_element($1); $$->add_element($3);}
| il_operand_list2 ',' il_operand
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| il_operand_list2 il_operand
  {$$ = $1; print_err_msg(locl(@1), locf(@2), "',' missing in IL operand list."); yynerrs++;}
| il_operand ',' error
  {$$ = new il_operand_list_c(locloc(@$));
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no operand defined in IL operand list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid operand name in IL operand list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


simple_instr_list:
  il_simple_instruction
	{$$ = new simple_instr_list_c(locloc(@$)); $$->add_element($1);}
| simple_instr_list il_simple_instruction
	{$$ = $1; $$->add_element($2);}
;


il_simple_instruction:
  il_simple_operation eol_list
	{$$ = new il_simple_instruction_c($1, locloc(@1));} /* locloc(@1) is not a bug! We ignore trailing EOLs when determining symbol location! */
| il_expression eol_list
	{$$ = new il_simple_instruction_c($1, locloc(@1));} /* locloc(@1) is not a bug! We ignore trailing EOLs when determining symbol location! */
| il_formal_funct_call eol_list
	{$$ = new il_simple_instruction_c($1, locloc(@1));} /* locloc(@1) is not a bug! We ignore trailing EOLs when determining symbol location! */
/* ERROR_CHECK_BEGIN */
| il_expression error
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "EOL missing after expression IL instruction."); yyerrok;}
| il_formal_funct_call error
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "EOL missing after formal function call IL instruction."); yyerrok;}
/* ERROR_CHECK_END */
;


/* NOTE: the correct definition of il_param_list is
 * il_param_list ::= {il_param_instruction} il_param_last_instruction
 *
 * where {...} denotes zero or many il_param_instruction's.
 *
 * We could do this by defining the following:
 * il_param_list: il_param_instruction_list il_param_last_instruction;
 * il_param_instruction_list : ** empty ** | il_param_instruction_list il_param_instruction;
 *
 * Unfortunately, the above leads to reduce/reduce conflicts.
 * The chosen alternative (as follows) does not have any conflicts!
 * il_param_list: il_param_last_instruction | il_param_instruction_list il_param_last_instruction;
 * il_param_instruction_list : il_param_instruction_list | il_param_instruction_list il_param_instruction;
 */
il_param_list:
  il_param_instruction_list il_param_last_instruction
	{$$ = $1; $$->add_element($2);}
| il_param_last_instruction
	{$$ = new il_param_list_c(locloc(@$)); $$->add_element($1);}
/* ERROR_CHECK_BEGIN */
| il_param_instruction_list error
  {$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid parameter assignment in parameter assignment list."); yyerrok;}
| il_param_last_instruction il_param_last_instruction
  {$$ = new il_param_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "',' missing at the end of parameter assignment in parameter assignment list."); yynerrs++;}
| il_param_instruction_list il_param_last_instruction il_param_last_instruction
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "',' missing at the end of parameter assignment in parameter assignment list."); yynerrs++;}
/* ERROR_CHECK_END */
;


/* Helper symbol for il_param_list */
il_param_instruction_list:
  il_param_instruction
	{$$ = new il_param_list_c(locloc(@$)); $$->add_element($1);}
| il_param_instruction_list il_param_instruction
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| il_param_last_instruction il_param_instruction
  {$$ = new il_param_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "',' missing at the end of parameter assignment in parameter assignment list."); yynerrs++;}
| il_param_instruction_list il_param_last_instruction il_param_instruction
  {$$ = $1; print_err_msg(locl(@2), locf(@3), "',' missing at the end of parameter assignment in parameter assignment list."); yynerrs++;}
/* ERROR_CHECK_END */
;


il_param_instruction:
  il_param_assignment ',' eol_list 
| il_param_out_assignment ',' eol_list
/* ERROR_CHECK_BEGIN */
| il_param_assignment ',' error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "EOL missing at the end of parameter assignment in parameter assignment list."); yyerrok;}
| il_param_out_assignment ',' error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "EOL missing at the end of parameter out assignment in parameter assignment list."); yyerrok;}
/* ERROR_CHECK_END */
;


il_param_last_instruction:
  il_param_assignment eol_list
| il_param_out_assignment eol_list
/* ERROR_CHECK_BEGIN */
| il_param_assignment error
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "EOL missing at the end of last parameter assignment in parameter assignment list."); yyerrok;}
| il_param_out_assignment error
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "EOL missing at the end of last parameter out assignment in parameter assignment list."); yyerrok;}
/* ERROR_CHECK_END */

;


il_param_assignment:
  il_assign_operator il_operand
	{$$ = new il_param_assignment_c($1, $2, NULL, locloc(@$));}
| il_assign_operator '(' eol_list simple_instr_list ')'
	{$$ = new il_param_assignment_c($1, NULL, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| error il_operand
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid operator in parameter assignment."); yyerrok;}
| error '(' eol_list simple_instr_list ')'
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid operator in parameter assignment."); yyerrok;}
| il_assign_operator error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no operand defined in parameter assignment.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid operand in parameter assignment."); yyclearin;}
	 yyerrok;
	}
| il_assign_operator '(' eol_list ')'
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no instruction list defined in parameter assignment."); yynerrs++;}
| il_assign_operator '(' eol_list error ')'
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid instruction list defined in parameter assignment."); yyerrok;}
| il_assign_operator '(' eol_list simple_instr_list error
  {$$ = NULL; print_err_msg(locl(@4), locf(@5), "')' missing at the end of instruction list defined in parameter assignment."); yyerrok;}
/* ERROR_CHECK_END */
;


il_param_out_assignment:
  il_assign_out_operator variable
	{$$ = new il_param_out_assignment_c($1, $2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| il_assign_out_operator error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no variable defined in IL operand list.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid variable in IL operand list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;



/*******************/
/* B 2.2 Operators */
/*******************/
sendto_identifier: sendto_identifier_token {$$ = new identifier_c($1, locloc(@$));};


/* NOTE:
 *  The spec includes the operator 'EQ '
 * Note that EQ is followed by a space.
 * I am considering this a typo, and defining the operator
 * as 'EQ'
 * (Mario)
 */
LD_operator: 		LD 	{$$ = new LD_operator_c(locloc(@$));};
LDN_operator: 		LDN 	{$$ = new LDN_operator_c(locloc(@$));};
ST_operator: 		ST 	{$$ = new ST_operator_c(locloc(@$));};
STN_operator: 		STN 	{$$ = new STN_operator_c(locloc(@$));};
NOT_operator: 		NOT 	{$$ = new NOT_operator_c(locloc(@$));};
S_operator: 		S 	{$$ = new S_operator_c(locloc(@$));};
R_operator: 		R 	{$$ = new R_operator_c(locloc(@$));};
S1_operator: 		S1 	{$$ = new S1_operator_c(locloc(@$));};
R1_operator: 		R1 	{$$ = new R1_operator_c(locloc(@$));};
CLK_operator: 		CLK 	{$$ = new CLK_operator_c(locloc(@$));};
CU_operator: 		CU 	{$$ = new CU_operator_c(locloc(@$));};
CD_operator: 		CD 	{$$ = new CD_operator_c(locloc(@$));};
PV_operator: 		PV 	{$$ = new PV_operator_c(locloc(@$));};
IN_operator: 		IN 	{$$ = new IN_operator_c(locloc(@$));};
PT_operator: 		PT 	{$$ = new PT_operator_c(locloc(@$));};
AND_operator: 		AND 	{$$ = new AND_operator_c(locloc(@$));};
AND2_operator: 		AND2 	{$$ = new AND_operator_c(locloc(@$));}; /* '&' in the source code! */
OR_operator: 		OR 	{$$ = new OR_operator_c(locloc(@$));};
XOR_operator: 		XOR 	{$$ = new XOR_operator_c(locloc(@$));};
ANDN_operator: 		ANDN 	{$$ = new ANDN_operator_c(locloc(@$));};
ANDN2_operator:		ANDN2 	{$$ = new ANDN_operator_c(locloc(@$));}; /* '&N' in the source code! */
ORN_operator: 		ORN 	{$$ = new ORN_operator_c(locloc(@$));};
XORN_operator: 		XORN 	{$$ = new XORN_operator_c(locloc(@$));};
ADD_operator: 		ADD 	{$$ = new ADD_operator_c(locloc(@$));};
SUB_operator: 		SUB 	{$$ = new SUB_operator_c(locloc(@$));};
MUL_operator: 		MUL 	{$$ = new MUL_operator_c(locloc(@$));};
DIV_operator: 		DIV 	{$$ = new DIV_operator_c(locloc(@$));};
MOD_operator: 		MOD 	{$$ = new MOD_operator_c(locloc(@$));};
GT_operator: 		GT 	{$$ = new GT_operator_c(locloc(@$));};
GE_operator: 		GE 	{$$ = new GE_operator_c(locloc(@$));};
EQ_operator: 		EQ 	{$$ = new EQ_operator_c(locloc(@$));};
LT_operator: 		LT 	{$$ = new LT_operator_c(locloc(@$));};
LE_operator: 		LE 	{$$ = new LE_operator_c(locloc(@$));};
NE_operator: 		NE 	{$$ = new NE_operator_c(locloc(@$));};
CAL_operator: 		CAL 	{$$ = new CAL_operator_c(locloc(@$));};
CALC_operator: 		CALC 	{$$ = new CALC_operator_c(locloc(@$));};
CALCN_operator: 	CALCN 	{$$ = new CALCN_operator_c(locloc(@$));};
RET_operator: 		RET 	{$$ = new RET_operator_c(locloc(@$));};
RETC_operator: 		RETC 	{$$ = new RETC_operator_c(locloc(@$));};
RETCN_operator: 	RETCN 	{$$ = new RETCN_operator_c(locloc(@$));};
JMP_operator: 		JMP 	{$$ = new JMP_operator_c(locloc(@$));};
JMPC_operator: 		JMPC 	{$$ = new JMPC_operator_c(locloc(@$));};
JMPCN_operator: 	JMPCN 	{$$ = new JMPCN_operator_c(locloc(@$));};


il_simple_operator:
  il_simple_operator_clash
| il_simple_operator_noclash
;


il_simple_operator_noclash:
  LDN_operator
| ST_operator
| STN_operator
| il_expr_operator_noclash
;


il_simple_operator_clash:
  il_simple_operator_clash1
| il_simple_operator_clash2
| il_simple_operator_clash3
;

il_simple_operator_clash1:
  NOT_operator
;

il_simple_operator_clash2:
  il_expr_operator_clash
;

il_simple_operator_clash3:
  LD_operator
| S_operator
| R_operator
| S1_operator
| R1_operator
| CLK_operator
| CU_operator
| CD_operator
| PV_operator
| IN_operator
| PT_operator
;

/*
il_expr_operator:
  il_expr_operator_noclash
| il_expr_operator_clash
;
*/

il_expr_operator_clash:
  AND_operator
| OR_operator
| XOR_operator
| ADD_operator
| SUB_operator
| MUL_operator
| DIV_operator
| MOD_operator
| GT_operator
| GE_operator
| EQ_operator
| LT_operator
| LE_operator
| NE_operator
;


il_expr_operator_noclash:
  ANDN_operator
| ANDN2_operator  /* string '&N' in source code! */
| AND2_operator  /* string '&' in source code! */
| ORN_operator
| XORN_operator
;




il_assign_operator:
/*  variable_name ASSIGN */
  any_identifier ASSIGN
	{$$ = new il_assign_operator_c($1, locloc(@$));}
| en_identifier ASSIGN
	{$$ = new il_assign_operator_c($1, locloc(@$));}
| S1_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| R1_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| CLK_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| CU_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| CD_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| PV_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| IN_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
| PT_operator ASSIGN
	{$$ = new il_assign_operator_c(il_operator_c_2_identifier_c($1), locloc(@$));}
/* ERROR_CHECK_BEGIN */
| error ASSIGN
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid parameter defined in parameter assignment."); yyerrok;}
/* ERROR_CHECK_END */
;


il_assign_out_operator:
/*  variable_name SENDTO */
/*  any_identifier SENDTO */
  sendto_identifier SENDTO
	{$$ = new il_assign_out_operator_c(NULL, $1, locloc(@$));}
/* The following is not required, as the sendto_identifier_token returned by flex will 
 * also include the 'ENO' identifier.
 * The resulting abstract syntax tree is identical with or without this following rule,
 * as both the eno_identifier and the sendto_identifier are stored as
 * an identifier_c !!
 *
 * To understand why we must even explicitly consider the use of ENO here,  
 * please read the comment above the definition of 'variable' in section B1.4 for details.
 */
/*
| eno_identifier SENDTO
	{$$ = new il_assign_out_operator_c(NULL, $1, locloc(@$));}
*/
/*| NOT variable_name SENDTO */
| NOT sendto_identifier SENDTO
	{$$ = new il_assign_out_operator_c(new not_paramassign_c(locloc(@1)), $2, locloc(@$));}
/* The following is not required, as the sendto_identifier_token returned by flex will 
 * also include the 'ENO' identifier.
 * The resulting abstract syntax tree is identical with or without this following rule,
 * as both the eno_identifier and the sendto_identifier are stored as
 * an identifier_c !!
 *
 * To understand why we must even explicitly consider the use of ENO here,  
 * please read the comment above the definition of 'variable' in section B1.4 for details.
 *
 * NOTE: Removing the following rule also removes a shift/reduce conflict from the parser.
 *       This conflict is not really an error/ambiguity in the syntax, but rather
 *       due to the fact that more than a single look-ahead token would be required
 *       to correctly parse the syntax, something that bison does not support.
 *
 *       The shift/reduce conflict arises because bison does not know whether
 *       to parse the 'NOT ENO' in the following code
 *         LD 1
 *         funct_name (
 *                      NOT ENO => bool_var,
 *                      EN := TRUE
 *                    )
 *        as either a il_param_assignment (wrong!) or an il_param_out_assignment.(correct).
 *        The '=>' delimiter (known as SEND_TO in this iec.y file) is a dead giveaway that 
 *        it should be parsed as an il_param_out_assignment, but still, bison gets confused!
 *        Bison considers the possibility of reducing the 'NOT ENO' as an NOT_operator with
 *        the 'ENO' operand
 *        (NOT_operator -> il_simple_operator -> il_simple_operation -> il_simple_instruction ->
 *          -> simple_instr_list -> il_param_assignment)
 *        instead of reducing it to an il_param_out_operator.
 *        ( il_param_out_operator -> il_param_out_assignment)
 *
 *        Note that the shift/reduce conflict only manifests itself in the il_formal_funct_call,
 *        where both the il_param_out_assignment and il_param_assignment are used!
 * 
 *          il_param_out_assignment --+--> il_param_instruction -> il_param_instruction_list --+
 *                                    |                                                        |
 *          il_param_assignment     --+                                                        |
 *                                                                                             |
 *                                                     il_formal_funct_call <- il_param_list <-+
 *
 */
/*
| NOT eno_identifier SENDTO
	{$$ = new il_assign_out_operator_c(new not_paramassign_c(locloc(@1)), $2, locloc(@$));}
*/
/* ERROR_CHECK_BEGIN */
| error SENDTO
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid parameter defined in parameter out assignment."); yyerrok;}
| NOT SENDTO
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no parameter defined in parameter out assignment."); yynerrs++;}
| NOT error SENDTO
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid parameter defined in parameter out assignment."); yyerrok;}
/* ERROR_CHECK_END */
;


il_call_operator:
  CAL_operator
| CALC_operator
| CALCN_operator
;


il_return_operator:
  RET_operator
| RETC_operator
| RETCN_operator
;


il_jump_operator:
  JMP_operator
| JMPC_operator
| JMPCN_operator
;


/***********************/
/* B 3.1 - Expressions */
/***********************/
expression:
  xor_expression
| ref_expression    /* an extension to the IEC 61131-3 v2 standard, based on the IEC 61131-3 v3 standard */ 
| deref_expression  /* an extension to the IEC 61131-3 v2 standard, based on the IEC 61131-3 v3 standard */ 
| expression OR xor_expression
	{$$ = new or_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| expression OR error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after 'OR' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after 'OR' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/*  REF(var_name) */
/*  This is an extension to the IEC 61131-3 standard. It is actually defined in the IEC 61131-3 v3 standard */
/*  The REF() operator returns the adrress of the variable. Basically, it returns a pointer to the variable */
ref_expression:
  REF '(' symbolic_variable ')'
	{$$ = new ref_expression_c($3, locloc(@$));}
;

/*  DREF(var_name) */
/*  This is an extension to the IEC 61131-3 standard. It is actually defined in the IEC 61131-3 v3 standard */
/*  The DREF() operator accesses the variable stored in the specified address. Basically, it dereferences a pointer to the variable */
deref_expression:
  DREF '(' symbolic_variable ')'
	{$$ = new deref_expression_c($3, locloc(@$));}
;

xor_expression:
  and_expression
| xor_expression XOR and_expression
	{$$ = new xor_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| xor_expression XOR error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after 'XOR' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after 'XOR' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

and_expression:
  comparison
| and_expression '&' comparison
	{$$ = new and_expression_c($1, $3, locloc(@$));}
| and_expression AND comparison
	{$$ = new and_expression_c($1, $3, locloc(@$));}
/* NOTE: The lexical parser never returns the token '&'.
 *       The '&' string is interpreted by the lexcial parser as the token
 *       AND2!
 *       This means that the first rule with '&' is actually not required,
 *       but we leave it in nevertheless just in case we later decide
 *       to remove the AND2 token...
 */
| and_expression AND2 comparison
	{$$ = new and_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| and_expression '&' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '&' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '&' in ST expression."); yyclearin;}
	 yyerrok;
	}
| and_expression AND error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after 'AND' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after 'AND' in ST expression."); yyclearin;}
	 yyerrok;
	}
| and_expression AND2 error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '&' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '&' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

comparison:
  equ_expression
| comparison '=' equ_expression
	{$$ = new equ_expression_c($1, $3, locloc(@$));}
| comparison OPER_NE equ_expression
	{$$ = new notequ_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| comparison '=' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '=' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '=' in ST expression."); yyclearin;}
	 yyerrok;
	}
| comparison OPER_NE error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '<>' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '<>' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

equ_expression:
  add_expression
| equ_expression '<' add_expression
	{$$ = new lt_expression_c($1, $3, locloc(@$));}
| equ_expression '>' add_expression
	{$$ = new gt_expression_c($1, $3, locloc(@$));}
| equ_expression OPER_LE add_expression
	{$$ = new le_expression_c($1, $3, locloc(@$));}
| equ_expression OPER_GE add_expression
	{$$ = new ge_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| equ_expression '<' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '<' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '<' in ST expression."); yyclearin;}
	 yyerrok;
	}
| equ_expression '>' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '>' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '>' in ST expression."); yyclearin;}
	 yyerrok;
	}
| equ_expression OPER_LE error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '<=' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '<=' in ST expression."); yyclearin;}
	 yyerrok;
	}
| equ_expression OPER_GE error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '>=' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '>=' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* Not required...
comparison_operator: '<' | '>' | '>=' '<='
*/

add_expression:
  term
| add_expression '+' term
	{$$ = new add_expression_c($1, $3, locloc(@$));}
| add_expression '-' term
	{$$ = new sub_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| add_expression '+' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '+' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '+' in ST expression."); yyclearin;}
	 yyerrok;
	}
| add_expression '-' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '-' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '-' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* Not required...
add_operator: '+' | '-'
*/

term:
  power_expression
| term '*' power_expression
	{$$ = new mul_expression_c($1, $3, locloc(@$));}
| term '/' power_expression
	{$$ = new div_expression_c($1, $3, locloc(@$));}
| term MOD power_expression
	{$$ = new mod_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| term '*' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '*' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '*' in ST expression."); yyclearin;}
	 yyerrok;
	}
| term '/' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '/' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '/' in ST expression."); yyclearin;}
	 yyerrok;
	}
| term MOD error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after 'MOD' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after 'MOD' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* Not required...
multiply_operator: '*' | '/' | 'MOD'
*/

power_expression:
  unary_expression
| power_expression OPER_EXP unary_expression
	{$$ = new power_expression_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| power_expression OPER_EXP error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after '**' in ST expression.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after '**' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


unary_expression:
  primary_expression
| '-' non_int_or_real_primary_expression
	{$$ = new neg_expression_c($2, locloc(@$));}
| NOT primary_expression
	{$$ = new not_expression_c($2, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| '-' error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no expression defined after '-' in ST expression.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid expression after '-' in ST expression."); yyclearin;}
	 yyerrok;
	}
| NOT error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@1), locf(@2), "no expression defined after 'NOT' in ST expression.");}
	 else {print_err_msg(locf(@2), locl(@2), "invalid expression after 'NOT' in ST expression."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* Not required...
unary_operator: '-' | 'NOT'
*/


/* NOTE: using constant as a possible symbol for primary_expression
 *       leads to a reduce/reduce conflict.
 *
 *       The text '-9' may be parsed as either a
 *       expression<-primary_expression<-constant<-signed_integer
 *       (i.e. the constant 9 negative)
 *       OR
 *       expression<-unary_expression<-constant<-integer
 *       (i.e. the constant 9, preceded by a unary negation)
 *
 *       To remove the conflict, we only allow constants without
 *       integer or reals that are not preceded by a sign 
 *       (i.e. a '-' or '+' character) to be used in primary_expression
 *       (i.e. as a parameter to the unary negation operator)
 *
 *       e.g.  '-42', '+54', '42', '54' are all allowed in primary expression
 *       according to the standard. However, we will allow only '-42' and '+54'
 *       to be used as an argument to the negation operator ('-').
 */
/* NOTE: Notice that the standard considers the following syntax correct:
 *         VAR intv: INT; END_VAR
 *         intv :=      42;         <----- OK
 *         intv :=     -42;         <----- OK
 *         intv :=     +42;         <----- OK
 *         intv :=    --42;         <----- OK!!
 *         intv :=    -+42;         <----- OK!!
 *         intv :=  -(--42);        <----- OK!!
 *         intv :=  -(-+42);        <----- OK!!
 *         intv :=-(-(--42));       <----- OK!!
 *         intv :=-(-(-+42));       <----- OK!!
 *     but does NOT allow the following syntax:
 *         VAR intv: INT; END_VAR
 *         intv :=   ---42;       <----- ERROR!!
 *         intv :=   --+42;       <----- ERROR!!
 *         intv :=  ----42;       <----- ERROR!!
 *         intv :=  ---+42;       <----- ERROR!!
 *
 *    Although strange, we follow the standard to the letter, and do exactly
 *    as stated above!!
 */
/* NOTE: We use enumerated_value_without_identifier instead of enumerated_value
 *       in order to remove a reduce/reduce conflict between reducing an
 *       identifier to a variable or an enumerated_value.
 *
 *       This change follows the IEC specification. The specification seems to
 *       imply (by introducing syntax that allows to unambiguosly reference an
 *       enumerated value - enum_type#enum_value) that in case the same identifier is used
 *       for a variable and an enumerated value, then the variable shall be
 *       considered.
 */
non_int_or_real_primary_expression:
  non_int_or_real_constant
//| enumerated_value_without_identifier
| enumerated_value
| variable
| '(' expression ')'
	{$$ = $2;}
|  function_invocation
/* ERROR_CHECK_BEGIN */
| '(' expression error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing at the end of expression in ST expression."); yyerrok;}
/* ERROR_CHECK_END */
;


primary_expression:
  constant
//| enumerated_value_without_identifier
| enumerated_value
| variable
| '(' expression ')'
	{$$ = $2;}
|  function_invocation
/* ERROR_CHECK_BEGIN */
| '(' expression error
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing at the end of expression in ST expression."); yyerrok;}
/* ERROR_CHECK_END */
;



/* intermediate helper symbol for primary_expression */
/* NOTE: function_name includes the standard function name 'NOT' !
 *       This introduces a reduce/reduce conflict, as NOT(var)
 *       may be parsed as either a function_invocation, or a
 *       unary_expression.
 *
 *       I (Mario) have opted to remove the possible reduction
 *       to function invocation, which means replacing the rule
 *           function_name '(' param_assignment_list ')'
 *       with
 *           function_name_no_NOT_clashes '(' param_assignment_list ')'
 *
 *       Notice how the new rule does not include the situation where
 *       the function NOT is called with more than one parameter, which
 *       the original rule does include! Callinf the NOT function with more
 *       than one argument is probably a semantic error anyway, so it
 *       doesn't make much sense to take it into account.
 *
 *       Nevertheless, if we were to to it entirely correctly,
 *       leaving the semantic checks for the next compiler stage,
 *       this syntax parser would need to include such a possibility.
 *
 *       We will leave this out for now. No need to complicate the syntax
 *       more than the specification does by contradicting itself, and
 *       letting names clash!
 */
function_invocation:
/*  function_name '(' [param_assignment_list] ')' */
  function_name_no_NOT_clashes '(' param_assignment_formal_list ')'
	{$$ = new function_invocation_c($1, $3, NULL, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
| function_name_no_NOT_clashes '(' param_assignment_nonformal_list ')'
	{$$ = new function_invocation_c($1, NULL, $3, locloc(@$)); if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR;} // $1 should be a poutype_identifier_c
| function_name_no_NOT_clashes '(' ')'
	{if (NULL == dynamic_cast<poutype_identifier_c*>($1)) ERROR; // $1 should be a poutype_identifier_c
	 if (runtime_options.allow_missing_var_in)
		{$$ = new function_invocation_c($1, NULL, NULL, locloc(@$));}
	 else
		{$$ = NULL; print_err_msg(locl(@2), locf(@3), "no parameter defined in function invocation of ST expression."); yynerrs++;}
	}
/* ERROR_CHECK_BEGIN */ 
| function_name_no_NOT_clashes param_assignment_formal_list ')'
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "'(' missing after function name in ST expression."); yynerrs++;}
| function_name_no_NOT_clashes '(' error ')'
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid parameter(s) defined in function invocation of ST expression."); yyerrok;}
| function_name_no_NOT_clashes '(' param_assignment_formal_list error
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing at the end of function invocation in ST expression."); yyerrok;}
| function_name_no_NOT_clashes '(' param_assignment_nonformal_list error
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing at the end of function invocation in ST expression."); yyerrok;}
/* ERROR_CHECK_END */
;


/********************/
/* B 3.2 Statements */
/********************/
statement_list:
  statement ';'
	{$$ = new statement_list_c(locloc(@$)); $$->add_element($1);}
| any_pragma
	{$$ = new statement_list_c(locloc(@$)); $$->add_element($1);}
| statement_list statement ';'
	{$$ = $1; $$->add_element($2);}
| statement_list any_pragma
	{$$ = $1; $$->add_element($2);}
/* ERROR_CHECK_BEGIN */
| statement error
	{$$ = new statement_list_c(locloc(@$)); print_err_msg(locl(@1), locf(@2), "';' missing at the end of statement in ST statement."); yyerrok;}
| statement_list statement error
	{$$ = $1; print_err_msg(locl(@2), locf(@3), "';' missing at the end of statement in ST statement."); yyerrok;}
| statement_list error ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "invalid statement in ST statement."); yyerrok;}
| statement_list ';'
	{$$ = $1; print_err_msg(locf(@2), locl(@2), "unexpected ';' after statement in ST statement."); yynerrs++;}
/* ERROR_CHECK_END */
;


statement:
  assignment_statement
| subprogram_control_statement
| selection_statement
| iteration_statement
| function_invocation 
	{ /* This is a non-standard extension (calling a function outside an ST expression!) */
	  /* Only allow this if command line option has been selected...                     */
	  $$ = $1; 
	  if (!runtime_options.allow_void_datatype) {
	    print_err_msg(locf(@1), locl(@1), "Function invocation in ST code is not allowed outside an expression. To allow this non-standard syntax, activate the apropriate command line option."); 
	    yynerrs++;
	  }
	}  
;


/*********************************/
/* B 3.2.1 Assignment Statements */
/*********************************/
assignment_statement:
  variable ASSIGN expression
	{$$ = new assignment_statement_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| error ASSIGN expression
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "invalid variable before ':=' in ST assignment statement."); yyerrok;}
| variable ASSIGN error
	{$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined after ':=' in ST assignment statement.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression after ':=' in ST assignment statement."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;




/*****************************************/
/* B 3.2.2 Subprogram Control Statements */
/*****************************************/
subprogram_control_statement:
  fb_invocation
| return_statement
;

return_statement:
  RETURN	{$$ = new return_statement_c(locloc(@$));}
;



fb_invocation:
  prev_declared_fb_name '(' ')'
	{$$ = new fb_invocation_c($1, NULL, NULL, locloc(@$));	}
| prev_declared_fb_name '(' param_assignment_formal_list ')'
	{$$ = new fb_invocation_c($1, $3, NULL, locloc(@$));}
| prev_declared_fb_name '(' param_assignment_nonformal_list ')'
	{$$ = new fb_invocation_c($1, NULL, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| prev_declared_fb_name ')'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'(' missing after function block name in ST statement."); yynerrs++;}
| prev_declared_fb_name param_assignment_formal_list ')'
	{$$ = NULL; print_err_msg(locl(@1), locf(@2), "'(' missing after function block name in ST statement."); yynerrs++;}
| prev_declared_fb_name '(' error ')'
	{$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid parameter list in function block invocation in ST statement."); yyerrok;}
| prev_declared_fb_name '(' error
	{$$ = NULL; print_err_msg(locl(@2), locf(@3), "')' missing after parameter list of function block invocation in ST statement."); yyerrok;}
| prev_declared_fb_name '(' param_assignment_formal_list error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing after parameter list of function block invocation in ST statement."); yyerrok;}
| prev_declared_fb_name '(' param_assignment_nonformal_list error
	{$$ = NULL; print_err_msg(locl(@3), locf(@4), "')' missing after parameter list of function block invocation in ST statement."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for
 * - fb_invocation
 * - function_invocation
 */
param_assignment_formal_list:
  param_assignment_formal
	{$$ = new param_assignment_list_c(locloc(@$)); $$->add_element($1);}
| param_assignment_formal_list ',' param_assignment_formal
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| param_assignment_formal_list ',' error
  {$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no parameter assignment defined in ST parameter assignment list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid parameter assignment in ST parameter assignment list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;

/* helper symbol for
 * - fb_invocation
 * - function_invocation
 */
param_assignment_nonformal_list:
  param_assignment_nonformal
	{$$ = new param_assignment_list_c(locloc(@$)); $$->add_element($1);}
| param_assignment_nonformal_list ',' param_assignment_nonformal
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| param_assignment_nonformal_list ',' error
  {$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no parameter assignment defined in ST parameter assignment list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid parameter assignment in ST parameter assignment list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


/* NOTE: According to the IEC 61131-3 standard, there are two possible
 *       syntaxes for calling function blocks within ST.
 *       The formal method has the form:
 *        fb ( invar := x, inoutvar := var1, outvar => var2);
 *       The non-formal method has the form:
 *        fb (x, var1, var2);
 *       In the text of IEC 61131-3 (where the semantics are defined),
 *       it is obvious that mixing the two syntaxes is considered incorrect.
 *       The following should therefore be incorrect: 
 *        fb ( invar := x, var1, var2);
 *       However, according to the syntax definition, as defined in IEC 61131-3,
 *       mixing the formal and non-formal methods of invocation is allowed.
 *       We have two alternatives:
 *        (a) implement the syntax here in iec.y according to the standard,
 *            and leave it to the semantic analyser stage to find this error
 *        (b) or implement the syntax in iec.y correctly, not allowing 
 *            the mixing of formal and non-formal invocation syntaxes.
 *       Considering that this is a syntax issue, and not semantic issue,
 *       I (Mario) have decided to go with alternative (a).
 *       In other words, in iec.y we do not follow the syntax as defined in
 *       Annex B of the IEC 61131-3 standard, but rather implement
 *       the syntax also taking into account the textual part of the standard too.
 */
/*
param_assignment:
  variable_name ASSIGN expression 
*/
param_assignment_nonformal:
  expression
;


param_assignment_formal:
  any_identifier ASSIGN expression
	{$$ = new input_variable_param_assignment_c($1, $3, locloc(@$));}
| en_identifier ASSIGN expression
	{$$ = new input_variable_param_assignment_c($1, $3, locloc(@$));}
/*| variable_name SENDTO variable */
/*| any_identifier SENDTO variable */
| sendto_identifier SENDTO variable
	{$$ = new output_variable_param_assignment_c(NULL, $1, $3, locloc(@$));}
/* The following is not required, as the sendto_identifier_token returned by flex will 
 * also include the 'ENO' identifier.
 * The resulting abstract syntax tree is identical with or without this following rule,
 * as both the eno_identifier and the sendto_identifier are stored as
 * an identifier_c !!
 *
 * To understand why we must even explicitly consider the use of ENO here,  
 * please read the comment above the definition of 'variable' in section B1.4 for details.
 */
/*
| eno_identifier SENDTO variable
	{$$ = new output_variable_param_assignment_c(NULL, $1, $3, locloc(@$));}
*/
/*| NOT variable_name SENDTO variable */
/*| NOT any_identifier SENDTO variable*/
| NOT sendto_identifier SENDTO variable
	{$$ = new output_variable_param_assignment_c(new not_paramassign_c(locloc(@$)), $2, $4, locloc(@$));}
/* The following is not required, as the sendto_identifier_token returned by flex will 
 * also include the 'ENO' identifier.
 * The resulting abstract syntax tree is identical with or without this following rule,
 * as both the eno_identifier and the sendto_identifier are stored as
 * an identifier_c !!
 *
 * To understand why we must even explicitly consider the use of ENO here,  
 * please read the comment above the definition of 'variable' in section B1.4 for details.
 */
/*
| NOT eno_identifier SENDTO variable
	{$$ = new output_variable_param_assignment_c(new not_paramassign_c(locloc(@$)), $2, $4, locloc(@$));}
*/
/* ERROR_CHECK_BEGIN */
| any_identifier ASSIGN error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined in ST formal parameter assignment.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression in ST formal parameter assignment."); yyclearin;}
	 yyerrok;
	}
| en_identifier ASSIGN error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined in ST formal parameter assignment.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression in ST formal parameter assignment."); yyclearin;}
	 yyerrok;
	}
| sendto_identifier SENDTO error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined in ST formal parameter out assignment.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression in ST formal parameter out assignment."); yyclearin;}
	 yyerrok;
	}
/*
| eno_identifier SENDTO error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no expression defined in ST formal parameter out assignment.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid expression in ST formal parameter out assignment."); yyclearin;}
	 yyerrok;
	}
*/
| NOT SENDTO variable
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no parameter name defined in ST formal parameter out negated assignment."); yynerrs++;}
| NOT error SENDTO variable
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid parameter name defined in ST formal parameter out negated assignment."); yyerrok;}
| NOT sendto_identifier SENDTO error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@3), locf(@4), "no expression defined in ST formal parameter out negated assignment.");}
	 else {print_err_msg(locf(@4), locl(@4), "invalid expression in ST formal parameter out negated assignment."); yyclearin;}
	 yyerrok;
	}
/*
| NOT eno_identifier SENDTO error
  {$$ = NULL;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@3), locf(@4), "no expression defined in ST formal parameter out negated assignment.");}
	 else {print_err_msg(locf(@4), locl(@4), "invalid expression in ST formal parameter out negated assignment."); yyclearin;}
	 yyerrok;
	}
*/
/* ERROR_CHECK_END */
;





/********************************/
/* B 3.2.3 Selection Statements */
/********************************/
selection_statement:
  if_statement
| case_statement
;


if_statement:
  IF expression THEN statement_list elseif_statement_list END_IF
	{$$ = new if_statement_c($2, $4, $5, NULL, locloc(@$));}
| IF expression THEN statement_list elseif_statement_list ELSE statement_list END_IF
	{$$ = new if_statement_c($2, $4, $5, $7, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| IF THEN statement_list elseif_statement_list END_IF
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined in ST 'IF' statement."); yynerrs++;}
| IF THEN statement_list elseif_statement_list ELSE statement_list END_IF
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined in ST 'IF' statement."); yynerrs++;}
| IF error THEN statement_list elseif_statement_list END_IF
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for ST 'IF' statement."); yyerrok;}
| IF error THEN statement_list elseif_statement_list ELSE statement_list END_IF
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for ST 'IF' statement."); yyerrok;}
| IF expression error statement_list elseif_statement_list END_IF
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'THEN' after test expression in ST 'IF' statement."); yyerrok;}
| IF expression error statement_list elseif_statement_list ELSE statement_list END_IF
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'THEN' after test expression in ST 'IF' statement."); yyerrok;}
| IF expression THEN elseif_statement_list END_IF
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no statement defined after 'THEN' in ST 'IF' statement."); yynerrs++;}
| IF expression THEN elseif_statement_list ELSE statement_list END_IF
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no statement defined after 'THEN' in ST 'IF' statement."); yynerrs++;}
| IF expression THEN statement_list elseif_statement_list ELSE END_IF
  {$$ = NULL; print_err_msg(locl(@6), locf(@7), "no statement defined after 'ELSE' in ST 'IF' statement."); yynerrs++;}
| IF expression THEN statement_list elseif_statement_list ELSE error END_IF
  {$$ = NULL; print_err_msg(locf(@7), locl(@7), "invalid statement defined after 'ELSE' in ST 'IF' statement."); yynerrs++; yyerrok;}
| IF expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed 'IF' statement in ST."); yyerrok;}
| IF expression THEN statement_list elseif_statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed 'IF' statement in ST."); yynerrs++;}
| IF expression THEN statement_list elseif_statement_list ELSE statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed 'IF' statement in ST."); yynerrs++;}
| IF error END_IF
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in ST 'IF' statement."); yyerrok;}
/* ERROR_CHECK_END */
;

/* helper symbol for if_statement */
elseif_statement_list:
  /* empty */
	{$$ = new elseif_statement_list_c(locloc(@$));}
| elseif_statement_list elseif_statement
	{$$ = $1; $$->add_element($2);}
;

/* helper symbol for elseif_statement_list */
elseif_statement:
  ELSIF expression THEN statement_list
	{$$ = new elseif_statement_c($2, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| ELSIF THEN statement_list
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined for 'ELSEIF' statement in ST 'IF' statement."); yynerrs++;}
| ELSIF error THEN statement_list
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for 'ELSEIF' statement in ST 'IF' statement."); yyerrok;}
| ELSIF expression error statement_list
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'THEN' after test expression in 'ELSEIF' statement of ST 'IF' statement."); yyerrok;}
| ELSIF expression THEN error
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid statement list in 'ELSEIF' statement of ST 'IF' statement."); yyerrok;}
/* ERROR_CHECK_END */
;


case_statement:
  CASE expression OF case_element_list END_CASE
	{$$ = new case_statement_c($2, $4, NULL, locloc(@$));}
| CASE expression OF case_element_list ELSE statement_list END_CASE
	{$$ = new case_statement_c($2, $4, $6, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| CASE OF case_element_list END_CASE
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined in ST 'CASE' statement."); yynerrs++;}
| CASE OF case_element_list ELSE statement_list END_CASE
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined in ST 'CASE' statement."); yynerrs++;}
| CASE error OF case_element_list END_CASE
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for ST 'CASE' statement."); yyerrok;}
| CASE error OF case_element_list ELSE statement_list END_CASE
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for ST 'CASE' statement."); yyerrok;}
| CASE expression error case_element_list END_CASE
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'OF' after test expression in ST 'CASE' statement."); yyerrok;}
| CASE expression error case_element_list ELSE statement_list END_CASE
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'OF' after test expression in ST 'CASE' statement."); yyerrok;}
| CASE expression OF END_CASE
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no case element(s) defined after 'OF' in ST 'CASE' statement."); yynerrs++;}
| CASE expression OF ELSE statement_list END_CASE
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no case element(s) defined after 'OF' in ST 'CASE' statement."); yynerrs++;}
| CASE expression OF error END_CASE
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid case element(s) defined after 'OF' in ST 'CASE' statement."); yyerrok;}
| CASE expression OF error ELSE statement_list END_CASE
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid case element(s) defined after 'OF' in ST 'CASE' statement."); yyerrok;}
| CASE expression OF case_element_list ELSE END_CASE
  {$$ = NULL; print_err_msg(locl(@5), locf(@6), "no statement defined after 'ELSE' in ST 'CASE' statement."); yynerrs++;}
| CASE expression OF case_element_list ELSE error END_CASE
  {$$ = NULL; print_err_msg(locf(@6), locl(@6), "invalid statement defined after 'ELSE' in ST 'CASE' statement."); yyerrok;}
| CASE expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@2), "unclosed 'CASE' statement in ST."); yyerrok;}
| CASE expression OF case_element_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed 'CASE' statement in ST."); yynerrs++;}
| CASE expression OF case_element_list ELSE statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@3), "unclosed 'CASE' statement in ST."); yynerrs++;}
| CASE error END_CASE
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in ST 'CASE' statement."); yyerrok;}
/* ERROR_CHECK_END */
;


/* helper symbol for case_statement */
case_element_list:
  case_element
	{$$ = new case_element_list_c(locloc(@$)); $$->add_element($1);}
| case_element_list case_element
	{$$ = $1; $$->add_element($2);}
;


case_element:
  case_list ':' statement_list
	{$$ = new case_element_c($1, $3, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| case_list statement_list
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "':' missing after case list in ST 'CASE' statement."); yynerrs++;}
| case_list ':' error
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "invalid statement in case element of ST 'CASE' statement."); yyerrok;}
/* ERROR_CHECK_END */
;


case_list:
  case_list_element
	{$$ = new case_list_c(locloc(@$)); $$->add_element($1);}
| case_list ',' case_list_element
	{$$ = $1; $$->add_element($3);}
/* ERROR_CHECK_BEGIN */
| case_list ',' error
  {$$ = $1;
	 if (is_current_syntax_token(yychar)) {print_err_msg(locl(@2), locf(@3), "no case defined in case list of ST parameter assignment list.");}
	 else {print_err_msg(locf(@3), locl(@3), "invalid case in case list of ST parameter assignment list."); yyclearin;}
	 yyerrok;
	}
/* ERROR_CHECK_END */
;


case_list_element:
  signed_integer
| subrange
| enumerated_value
;





/********************************/
/* B 3.2.4 Iteration Statements */
/********************************/
iteration_statement:
  for_statement
| while_statement
| repeat_statement
| exit_statement
;


for_statement:
  FOR control_variable ASSIGN expression TO expression BY expression DO statement_list END_FOR
	{$$ = new for_statement_c($2, $4, $6, $8, $10, locloc(@$));}
| FOR control_variable ASSIGN expression TO expression DO statement_list END_FOR
	{$$ = new for_statement_c($2, $4, $6, NULL, $8, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| FOR ASSIGN expression TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no control variable defined in ST 'FOR' statement."); yynerrs++;}
| FOR ASSIGN expression TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no control variable defined in ST 'FOR' statement."); yynerrs++;}
| FOR error ASSIGN expression TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid control variable defined for ST 'FOR' statement."); yyerrok;}
| FOR error ASSIGN expression TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid control variable defined for ST 'FOR' statement."); yyerrok;}
| FOR control_variable expression TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "':=' missing between control variable and start expression in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable expression TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@2), locf(@3), "':=' missing between control variable and start expression in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable error expression TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting ':=' between control variable and start expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable error expression TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting ':=' between control variable and start expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no start expression defined in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable ASSIGN TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no start expression defined in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable ASSIGN error TO expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid start expression defined in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN error TO expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid start expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression error expression BY expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@5), locl(@5), "expecting 'TO' between start expression and end expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression error expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@5), locl(@5), "expecting 'TO' between start expression and end expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression error expression DO statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@7), locl(@7), "expecting 'BY' between end expression and step expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression BY expression error statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@9), locl(@9), "expecting 'DO' after step expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression error statement_list END_FOR
  {$$ = NULL; print_err_msg(locf(@7), locl(@7), "expecting 'DO' after end expression in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression BY expression DO END_FOR
  {$$ = NULL; print_err_msg(locl(@9), locf(@10), "no statement(s) defined after 'DO' in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable ASSIGN expression TO expression DO END_FOR
  {$$ = NULL; print_err_msg(locl(@7), locf(@8), "no statement(s) defined after 'DO' in ST 'FOR' statement."); yynerrs++;}
| FOR control_variable ASSIGN expression TO expression BY expression DO error END_FOR
  {$$ = NULL; print_err_msg(locf(@10), locl(@10), "invalid statement(s) defined after 'DO' in ST 'FOR' statement."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression DO error END_FOR
  {$$ = NULL; print_err_msg(locf(@8), locl(@8), "invalid statement(s) defined after 'DO' in ST 'FOR' statement."); yyerrok;}
| FOR control_variable error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'FOR' statement in ST."); yyerrok;}
| FOR control_variable ASSIGN expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'FOR' statement in ST."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression DO statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'FOR' statement in ST."); yynerrs++;}
| FOR control_variable ASSIGN expression TO expression BY expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'FOR' statement in ST."); yyerrok;}
| FOR control_variable ASSIGN expression TO expression BY expression DO statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'FOR' statement in ST."); yynerrs++;}
| FOR error END_FOR
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in ST 'FOR' statement."); yyerrok;}
/* ERROR_CHECK_END */
;

/* The spec has the syntax
 * control_variable: identifier;
 * but then defines the semantics of control_variable
 * (Section 3.3.2.4) as being of an integer type
 * (e.g., SINT, INT, or DINT).
 *
 * Obviously this presuposes that the control_variable
 * must have been declared in some VAR .. END_VAR
 * We must therefore change the syntax to read
 * control_variable: prev_declared_variable_name;
 * 
 * If we don't, then the correct use of any previosuly declared 
 * variable would result in an incorrect syntax error
*/
control_variable: 
  prev_declared_variable_name 
	{$$ = new symbolic_variable_c($1,locloc(@$)); $$->token = $1->token;};
// control_variable: identifier {$$ = $1;};

/* Integrated directly into for_statement */
/*
for_list:
  expression TO expression [BY expression]
;
*/


while_statement:
  WHILE expression DO statement_list END_WHILE
	{$$ = new while_statement_c($2, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| WHILE DO statement_list END_WHILE
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no test expression defined in ST 'WHILE' statement."); yynerrs++;}
| WHILE error DO statement_list END_WHILE
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid test expression defined for ST 'WHILE' statement."); yyerrok;}
| WHILE expression error statement_list END_WHILE
  {$$ = NULL; print_err_msg(locf(@3), locl(@3), "expecting 'DO' after test expression in ST 'WHILE' statement."); yyerrok;}
| WHILE expression DO END_WHILE
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no statement(s) defined after 'DO' in ST 'WHILE' statement."); yynerrs++;}
| WHILE expression DO error END_WHILE
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid statement(s) defined after 'DO' in ST 'WHILE' statement."); yyerrok;}
| WHILE expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'WHILE' statement in ST."); yyerrok;}
| WHILE expression DO statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'WHILE' statement in ST."); yynerrs++;}
| WHILE error END_WHILE
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in ST 'WHILE' statement."); yyerrok;}
/* ERROR_CHECK_END */
;


repeat_statement:
  REPEAT statement_list UNTIL expression END_REPEAT
	{$$ = new repeat_statement_c($2, $4, locloc(@$));}
/* ERROR_CHECK_BEGIN */
| REPEAT UNTIL expression END_REPEAT
  {$$ = NULL; print_err_msg(locl(@1), locf(@2), "no statement(s) defined after 'REPEAT' in ST 'REPEAT' statement."); yynerrs++;}
| REPEAT error UNTIL expression END_REPEAT
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "invalid statement(s) defined after 'REPEAT' for ST 'REPEAT' statement."); yyerrok;}
| REPEAT statement_list UNTIL END_REPEAT
  {$$ = NULL; print_err_msg(locl(@3), locf(@4), "no test expression defined after 'UNTIL' in ST 'REPEAT' statement.");}
| REPEAT statement_list UNTIL error END_REPEAT
  {$$ = NULL; print_err_msg(locf(@4), locl(@4), "invalid test expression defined after 'UNTIL' in ST 'REPEAT' statement."); yyerrok;}
| REPEAT statement_list END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'REPEAT' statement in ST."); yynerrs++;}
| REPEAT statement_list UNTIL expression error END_OF_INPUT
  {$$ = NULL; print_err_msg(locf(@1), locl(@1), "unclosed 'REPEAT' statement in ST."); yyerrok;}
| REPEAT error END_REPEAT
  {$$ = NULL; print_err_msg(locf(@2), locl(@2), "unknown error in ST 'REPEAT' statement."); yyerrok;}
/* ERROR_CHECK_END */
;


exit_statement:
  EXIT	{$$ = new exit_statement_c(locloc(@$));}
;


%%


#include <stdio.h>	/* required for printf() */
#include <errno.h>



/*************************************************************************************************/
/* NOTE: These variables are really parameters we would like the stage2__ function to pass       */
/*       to the yyparse() function. However, the yyparse() function is created automatically     */
/*       by bison, so we cannot add parameters to this function. The only other                  */
/*       option is to use global variables! yuck!                                                */ 
/*************************************************************************************************/

/* A global flag used to tell the parser if overloaded funtions should be allowed.
 * The IEC 61131-3 standard allows overloaded funtions in the standard library,
 * but disallows them in user code...
 *
 * In essence, a parameter we would like to pass to the yyparse() function but
 * have to do it using a global variable, as the yyparse() prototype is fixed by bison.
 */
bool allow_function_overloading = false;

/* | [var1_list ','] variable_name '..' */
/* NOTE: This is an extension to the standard!!! */
/* In order to be able to handle extensible standard functions
 * (i.e. standard functions that may have a variable number of
 * input parameters, such as AND(word#33, word#44, word#55, word#66),
 * we have extended the acceptable syntax to allow var_name '..'
 * in an input variable declaration.
 *
 * This allows us to parse the declaration of standard
 * extensible functions and load their interface definition
 * into the abstract syntax tree just like we do to other 
 * user defined functions.
 * This has the advantage that we can later do semantic
 * checking of calls to functions (be it a standard or user defined
 * function) in (almost) exactly the same way.
 *
 * Of course, we have a flag that disables this syntax when parsing user
 * written code, so we only allow this extra syntax while parsing the 
 * 'header' file that declares all the standard IEC 61131-3 functions.
 */
bool allow_extensible_function_parameters = false;

/* A global flag used to tell the parser whether to allow use of DREF and '^' operators (defined in IEC 61131-3 v3) */
bool allow_ref_dereferencing;
/* A global flag used to tell the parser whether to allow use of REF_TO ANY datatypes (non-standard extension) */
bool allow_ref_to_any = false;
/* A global flag used to tell the parser whether to allow use of REF_TO as a struct or array element (non-standard extension) */
bool allow_ref_to_in_derived_datatypes = false;


/* The following function is called automatically by bison whenever it comes across
 * an error. Unfortunately it calls this function before executing the code that handles
 * the error itself, so we cannot print out the correct line numbers of the error location
 * over here.
 * Our solution is to store the current error message in a global variable, and have all
 * error action handlers call the function print_err_msg() after setting the location
 * (line number) variable correctly.
 */
const char *current_error_msg;
void yyerror (const char *error_msg) {
  current_error_msg = error_msg;
/* fprintf(stderr, "error %d: %s\n", yynerrs // global variable //, error_msg); */
/*  print_include_stack(); */
}


/* ERROR_CHECK_BEGIN */
bool is_current_syntax_token(int token) {
  switch (token) {
    case ';':
    case ',':
    case ')':
    case ']':
    case '+':
    case '*':
    case '-':
    case '/':
    case '<':
    case '>':
    case '=':
    case '&':
    case OR:
    case XOR:
    case AND:
    case AND2:
    case OPER_NE:
    case OPER_LE:
    case OPER_GE:
    case MOD:
    case OPER_EXP:
    case NOT:
      return true;
    default:
     return false;
  }
}
/* ERROR_CHECK_END */


void print_err_msg(int first_line,
                   int first_column,
                   const char *first_filename,
                   long int first_order,
                   int last_line,
                   int last_column,
                   const char *last_filename,
                   long int last_order,
                   const char *additional_error_msg) {

  const char *unknown_file = "<unknown_file>";
  if (first_filename == NULL) first_filename = unknown_file;
  if ( last_filename == NULL)  last_filename = unknown_file;

  if (runtime_options.full_token_loc) {
    if (first_filename == last_filename)
      fprintf(stderr, "%s:%d-%d..%d-%d: error: %s\n", first_filename, first_line, first_column, last_line, last_column, additional_error_msg);
    else
      fprintf(stderr, "%s:%d-%d..%s:%d-%d: error: %s\n", first_filename, first_line, first_column, last_filename, last_line, last_column, additional_error_msg);
  } else {
      fprintf(stderr, "%s:%d: error: %s\n", first_filename, first_line, additional_error_msg);
  }
  //fprintf(stderr, "error %d: %s\n", yynerrs /* a global variable */, additional_error_msg);
  //print_include_stack();
}



/* If function overloading is on, we allow several functions with the same name.
 *
 * However, to support standard functions, we also allow functions named
 *   AND, MOD, NOT, OR, XOR, ADD, ...
 */
/*
identifier_c *token_2_identifier_c(char *value, ) {
  identifier_c tmp = new identifier_c(value, locloc(@$));
	 if (!allow_function_overloading) {
	   fprintf(stderr, "Function overloading not allowed. Invalid identifier %s\n", ((token_c *)($$))->value);
	   ERROR;
	 }
	}
}
*/

/* convert between an il_operator to a function name */
/* This a kludge!
 * It is required because our language requires more than one
 * look ahead token, and bison only works with one!
 */
#define op_2_str(op, str) {\
  op ## _operator_c *ptr = dynamic_cast<op ## _operator_c *>(il_operator); \
  if (ptr != NULL) name = str; \
}

/* NOTE: this code is very ugly and un-eficient, but I (Mario) have many
 *       more things to worry about right now, so just let it be...
 */
poutype_identifier_c *il_operator_c_2_poutype_identifier_c(symbol_c *il_operator) {
  identifier_c         *    id = il_operator_c_2_identifier_c(il_operator);
  poutype_identifier_c *pou_id = new poutype_identifier_c(creat_strcopy(id->value));

  *(symbol_c *)pou_id = *(symbol_c *)id;
  delete id;
  return pou_id;
}
  

identifier_c *il_operator_c_2_identifier_c(symbol_c *il_operator) {
  const char *name = NULL;
  identifier_c *res;

  op_2_str(NOT,   "NOT");

  op_2_str(AND,   "AND");
  op_2_str(OR,    "OR");
  op_2_str(XOR,   "XOR");
  op_2_str(ADD,   "ADD");
  op_2_str(SUB,   "SUB");
  op_2_str(MUL,   "MUL");
  op_2_str(DIV,   "DIV");
  op_2_str(MOD,   "MOD");
  op_2_str(GT,    "GT");
  op_2_str(GE,    "GE");
  op_2_str(EQ,    "EQ");
  op_2_str(LT,    "LT");
  op_2_str(LE,    "LE");
  op_2_str(NE,    "NE");

  op_2_str(LD,    "LD");
  op_2_str(LDN,   "LDN");
  op_2_str(ST,    "ST");
  op_2_str(STN,   "STN");

  op_2_str(S,     "S");
  op_2_str(R,     "R");
  op_2_str(S1,    "S1");
  op_2_str(R1,    "R1");

  op_2_str(CLK,   "CLK");
  op_2_str(CU,    "CU");
  op_2_str(CD,    "CD");
  op_2_str(PV,    "PV");
  op_2_str(IN,    "IN");
  op_2_str(PT,    "PT");

  op_2_str(ANDN,  "ANDN");
  op_2_str(ORN,   "ORN");
  op_2_str(XORN,  "XORN");

  op_2_str(ADD,   "ADD");
  op_2_str(SUB,   "SUB");
  op_2_str(MUL,   "MUL");
  op_2_str(DIV,   "DIV");

  op_2_str(GT,    "GT");
  op_2_str(GE,    "GE");
  op_2_str(EQ,    "EQ");
  op_2_str(LT,    "LT");
  op_2_str(LE,    "LE");
  op_2_str(NE,    "NE");

  op_2_str(CAL,   "CAL");
  op_2_str(CALC,  "CALC");
  op_2_str(CALCN, "CALCN");
  op_2_str(RET,   "RET");
  op_2_str(RETC,  "RETC");
  op_2_str(RETCN, "RETCN");
  op_2_str(JMP,   "JMP");
  op_2_str(JMPC,  "JMPC");
  op_2_str(JMPCN, "JMPCN");

  if (name == NULL)
    ERROR;
  res = new identifier_c(creat_strcopy(name));
  *(symbol_c *)res = *(symbol_c *)il_operator;
  delete il_operator;
  
  return res;
}
