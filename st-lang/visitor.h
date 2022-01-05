#pragma once
#include "ast.h"

#define SYM_LIST(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_TOKEN(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF0(class_name_c, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF1(class_name_c, ref1, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF2(class_name_c, ref1, ref2, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF3(class_name_c, ref1, ref2, ref3, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF4(class_name_c, ref1, ref2, ref3, ref4, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF5(class_name_c, ref1, ref2, ref3, ref4, ref5, ...) virtual void* visit(class_name_c* symbol) = 0;
#define SYM_REF6(class_name_c, ref1, ref2, ref3, ref4, ref5, ref6, ...) virtual void* visit(class_name_c* symbol) = 0;

class visitor_c {
public:
#include "absyntax.def"

    virtual ~visitor_c(void);
};

#undef SYM_LIST
#undef SYM_TOKEN
#undef SYM_REF0
#undef SYM_REF1
#undef SYM_REF2
#undef SYM_REF3
#undef SYM_REF4
#undef SYM_REF5
#undef SYM_REF6

#define SYM_LIST(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_TOKEN(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF0(class_name_c, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF1(class_name_c, ref1, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF2(class_name_c, ref1, ref2, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF3(class_name_c, ref1, ref2, ref3, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF4(class_name_c, ref1, ref2, ref3, ref4, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF5(class_name_c, ref1, ref2, ref3, ref4, ref5, ...) virtual void* visit(class_name_c* symbol);
#define SYM_REF6(class_name_c, ref1, ref2, ref3, ref4, ref5, ref6, ...) virtual void* visit(class_name_c* symbol);

class null_visitor_c : public visitor_c {
public:
#include "absyntax.def"

    virtual ~null_visitor_c(void);
};

class fcall_visitor_c : public visitor_c {
public:
    virtual void fcall(symbol_c* symbol) = 0;

public:
    /* A class used to identify an entry (literal, variable, etc...) in the abstract syntax tree with an invalid data
     * type */
    /* This is only used from stage3 onwards. Stages 1 and 2 will never create any instances of invalid_type_name_c */
    virtual void* visit(invalid_type_name_c* symbol);

    /********************/
    /* 2.1.6 - Pragmas  */
    /********************/
    virtual void* visit(disable_code_generation_pragma_c* symbol);
    virtual void* visit(enable_code_generation_pragma_c* symbol);
    virtual void* visit(pragma_c* symbol);

    /***************************/
    /* B 0 - Programming Model */
    /***************************/
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    virtual void* visit(library_c* symbol);

    /*************************/
    /* B.1 - Common elements */
    /*************************/
    /*******************************************/
    /* B 1.1 - Letters, digits and identifiers */
    /*******************************************/
    SYM_TOKEN(identifier_c)
    /* A special identifier class, used for identifiers that have been previously declared as a derived datatype */
    /*  This is currently needed because generate_c stage 4 needs to handle the array datatype identifiers differently
     * to all other identifiers. */
    SYM_TOKEN(derived_datatype_identifier_c)
    SYM_TOKEN(poutype_identifier_c)

    /*********************/
    /* B 1.2 - Constants */
    /*********************/
    /*********************************/
    /* B 1.2.XX - Reference Literals */
    /*********************************/
    /* defined in IEC 61131-3 v3 - Basically the 'NULL' keyword! */
    SYM_REF0(ref_value_null_literal_c)

    /******************************/
    /* B 1.2.1 - Numeric Literals */
    /******************************/
    SYM_TOKEN(real_c)
    SYM_TOKEN(integer_c)
    SYM_TOKEN(binary_integer_c)
    SYM_TOKEN(octal_integer_c)
    SYM_TOKEN(hex_integer_c)

    /* Note:
     * We do not have signed_integer_c and signed_real_c classes.
     * These are stored in the parse tree as a integer_c or real_c
     * preceded by a unary minus operator if they are inside an expression,
     * or a neg_integer_c and neg_real_c when used outside an ST expression.
     */
    /* Not required:
    SYM_TOKEN(signed_integer_c)
    SYM_TOKEN(signed_real_c)
    */

    /* NOTE: literal __values__ are stored directly in classes such as:
     *          - real_c
     *          - integer_c
     *          - binary_integer_c
     *          - etc...
     *
     *       However, for both the real_c and the integer_c, if they are preceded
     *       by a '-' negation sign, they are further encapsulated inside
     *       a neg_literal_c (i.e. the neg_literal_c will point to the
     *       real_c or integer_c with the value being negated.
     *          neg_literal_c -> integer_literal_c
     *                OR
     *          neg_literal_c -> real_literal_c
     *
     *       However, this has since been changed to...
     *        - replace the neg_literal_c with two distinc classes
     *              (neg_integer_c and neg_real_c), one for each
     *              lietral type.
     *
     *       This change was done in order to ease the writing of semantic verification (stage3) code.
     *       However, that version of the code has since been replaced by a newer and better algoritm.
     *       This means the above change can now be undone, but there is really no need to undo it,
     *       so we leave it as it is.
     */
    SYM_REF1(neg_real_c, exp)
    SYM_REF1(neg_integer_c, exp)

    /* Not required:
    SYM_REF2(numeric_literal_c, type, value)
    */
    SYM_REF2(integer_literal_c, type, value)
    SYM_REF2(real_literal_c, type, value)
    SYM_REF2(bit_string_literal_c, type, value)
    /* A typed or untyped boolean literal... */
    /* type may be NULL */
    SYM_REF2(boolean_literal_c, type, value)

    /* helper class for boolean_literal_c */
    SYM_REF0(boolean_true_c)

    /* helper class for boolean_literal_c */
    SYM_REF0(boolean_false_c)

    /*******************************/
    /* B.1.2.2   Character Strings */
    /*******************************/
    SYM_TOKEN(double_byte_character_string_c)
    SYM_TOKEN(single_byte_character_string_c)

    /***************************/
    /* B 1.2.3 - Time Literals */
    /***************************/

    /************************/
    /* B 1.2.3.1 - Duration */
    /************************/
    SYM_REF0(neg_time_c)
    SYM_REF3(duration_c, type_name, neg, interval)
    SYM_REF5(interval_c, days, hours, minutes, seconds, milliseconds)
    SYM_TOKEN(fixed_point_c)
    /*
    SYM_REF2(days_c, days, hours)
    SYM_REF2(hours_c, hours, minutes)
    SYM_REF2(minutes_c, minutes, seconds)
    SYM_REF2(seconds_c, seconds, milliseconds)
    SYM_REF1(milliseconds_c, milliseconds)
    */

    /************************************/
    /* B 1.2.3.2 - Time of day and Date */
    /************************************/
    SYM_REF2(time_of_day_c, type_name, daytime)
    SYM_REF3(daytime_c, day_hour, day_minute, day_second)
    SYM_REF2(date_c, type_name, date_literal)
    SYM_REF3(date_literal_c, year, month, day)
    SYM_REF3(date_and_time_c, type_name, date_literal, daytime)

    /**********************/
    /* B.1.3 - Data types */
    /**********************/
    /***********************************/
    /* B 1.3.1 - Elementary Data Types */
    /***********************************/
    SYM_REF0(time_type_name_c)
    SYM_REF0(bool_type_name_c)
    SYM_REF0(sint_type_name_c)
    SYM_REF0(int_type_name_c)
    SYM_REF0(dint_type_name_c)
    SYM_REF0(lint_type_name_c)
    SYM_REF0(usint_type_name_c)
    SYM_REF0(uint_type_name_c)
    SYM_REF0(udint_type_name_c)
    SYM_REF0(ulint_type_name_c)
    SYM_REF0(real_type_name_c)
    SYM_REF0(lreal_type_name_c)
    SYM_REF0(date_type_name_c)
    SYM_REF0(tod_type_name_c)
    SYM_REF0(dt_type_name_c)
    SYM_REF0(byte_type_name_c)
    SYM_REF0(word_type_name_c)
    SYM_REF0(dword_type_name_c)
    SYM_REF0(lword_type_name_c)
    SYM_REF0(string_type_name_c)
    SYM_REF0(wstring_type_name_c)
    SYM_REF0(void_type_name_c) /* a non-standard extension! */

    /*****************************************************************/
    /* Keywords defined in "Safety Software Technical Specification" */
    /*****************************************************************/

    SYM_REF0(safetime_type_name_c)
    SYM_REF0(safebool_type_name_c)
    SYM_REF0(safesint_type_name_c)
    SYM_REF0(safeint_type_name_c)
    SYM_REF0(safedint_type_name_c)
    SYM_REF0(safelint_type_name_c)
    SYM_REF0(safeusint_type_name_c)
    SYM_REF0(safeuint_type_name_c)
    SYM_REF0(safeudint_type_name_c)
    SYM_REF0(safeulint_type_name_c)
    SYM_REF0(safereal_type_name_c)
    SYM_REF0(safelreal_type_name_c)
    SYM_REF0(safedate_type_name_c)
    SYM_REF0(safetod_type_name_c)
    SYM_REF0(safedt_type_name_c)
    SYM_REF0(safebyte_type_name_c)
    SYM_REF0(safeword_type_name_c)
    SYM_REF0(safedword_type_name_c)
    SYM_REF0(safelword_type_name_c)
    SYM_REF0(safestring_type_name_c)
    SYM_REF0(safewstring_type_name_c)

    /********************************/
    /* B.1.3.2 - Generic data types */
    /********************************/

    /* ANY is currently only allowed when defining REF_TO ANY datatypes
     * (equivalent to a (void *)). This is a non standard extension to the
     * standard.
     * Standard library function that use the generic datatypes (ANY_***) are
     * currently handed as overloaded functions, and do not therefore require
     * the use of the generic datatype keywords.
     */
    SYM_REF0(generic_type_any_c)  // ANY
    /*
    SYM_REF0(generic_type_any_derived_c)    // ANY_DERIVED
    SYM_REF0(generic_type_any_elementary_c) // ANY_ELEMENTARY
    SYM_REF0(generic_type_any_magnitude_c)  // ANY_MAGNITUDE
    SYM_REF0(generic_type_any_num_c)        // ANY_NUM
    SYM_REF0(generic_type_any_real_c)       // ANY_REAL
    SYM_REF0(generic_type_any_int_c)        // ANY_INT
    SYM_REF0(generic_type_any_bit_c)        // ANY_BIT
    SYM_REF0(generic_type_any_string_c)     // ANY_STRING
    SYM_REF0(generic_type_any_date_c)       // ANY_DATE
    */

    /********************************/
    /* B 1.3.3 - Derived data types */
    /********************************/
    /*  TYPE type_declaration_list END_TYPE */
    SYM_REF1(data_type_declaration_c, type_declaration_list)

    /* helper symbol for data_type_declaration */
    SYM_LIST(type_declaration_list_c)

    /*  simple_type_name ':' simple_spec_init */
    SYM_REF2(simple_type_declaration_c, simple_type_name, simple_spec_init)

    /* simple_specification ASSIGN constant */
    SYM_REF2(simple_spec_init_c, simple_specification, constant)

    /*  subrange_type_name ':' subrange_spec_init */
    SYM_REF2(subrange_type_declaration_c, subrange_type_name, subrange_spec_init)

    /* subrange_specification ASSIGN signed_integer */
    SYM_REF2(subrange_spec_init_c, subrange_specification, signed_integer)

    /*  integer_type_name '(' subrange')' */
    SYM_REF2(subrange_specification_c, integer_type_name, subrange)

    /*  signed_integer DOTDOT signed_integer */
    /* dimension will be filled in during stage 3 (array_range_check_c) with the number of elements in this subrange */
    SYM_REF2(subrange_c, lower_limit, upper_limit, unsigned long long int dimension;)

    /*  enumerated_type_name ':' enumerated_spec_init */
    SYM_REF2(enumerated_type_declaration_c, enumerated_type_name, enumerated_spec_init)

    /* enumerated_specification ASSIGN enumerated_value */
    SYM_REF2(enumerated_spec_init_c, enumerated_specification, enumerated_value)

    /* helper symbol for enumerated_specification->enumerated_spec_init */
    /* enumerated_value_list ',' enumerated_value */
    SYM_LIST(enumerated_value_list_c)

    /* enumerated_type_name '#' identifier */
    SYM_REF2(enumerated_value_c, type, value)

    /*  identifier ':' array_spec_init */
    SYM_REF2(array_type_declaration_c, identifier, array_spec_init)

    /* array_specification [ASSIGN array_initialization] */
    /* array_initialization may be NULL ! */
    SYM_REF2(array_spec_init_c, array_specification, array_initialization)

    /* ARRAY '[' array_subrange_list ']' OF non_generic_type_name */
    SYM_REF2(array_specification_c, array_subrange_list, non_generic_type_name)

    /* helper symbol for array_specification */
    /* array_subrange_list ',' subrange */
    SYM_LIST(array_subrange_list_c)

    /* array_initialization:  '[' array_initial_elements_list ']' */
    /* helper symbol for array_initialization */
    /* array_initial_elements_list ',' array_initial_elements */
    SYM_LIST(array_initial_elements_list_c)

    /* integer '(' [array_initial_element] ')' */
    /* array_initial_element may be NULL ! */
    SYM_REF2(array_initial_elements_c, integer, array_initial_element)

    /*  structure_type_name ':' structure_specification */
    SYM_REF2(structure_type_declaration_c, structure_type_name, structure_specification)

    /* structure_type_name ASSIGN structure_initialization */
    /* structure_initialization may be NULL ! */
    SYM_REF2(initialized_structure_c, structure_type_name, structure_initialization)

    /* helper symbol for structure_declaration */
    /* structure_declaration:  STRUCT structure_element_declaration_list END_STRUCT */
    /* structure_element_declaration_list structure_element_declaration ';' */
    SYM_LIST(structure_element_declaration_list_c)

    /*  structure_element_name ':' *_spec_init */
    SYM_REF2(structure_element_declaration_c, structure_element_name, spec_init)

    /* helper symbol for structure_initialization */
    /* structure_initialization: '(' structure_element_initialization_list ')' */
    /* structure_element_initialization_list ',' structure_element_initialization */
    SYM_LIST(structure_element_initialization_list_c)

    /*  structure_element_name ASSIGN value */
    SYM_REF2(structure_element_initialization_c, structure_element_name, value)

    /*  string_type_name ':' elementary_string_type_name string_type_declaration_size string_type_declaration_init */
    /*
     * NOTE:
     * (Summary: Contrary to what is expected, the
     *           string_type_declaration_c is not used to store
     *           simple string type declarations that do not include
     *           size limits.
     *           For e.g.:
     *             str1_type: STRING := "hello!"
     *           will be stored in a simple_type_declaration_c
     *           instead of a string_type_declaration_c.
     *           The following:
     *             str2_type: STRING [64] := "hello!"
     *           will be stored in a sring_type_declaration_c
     *
     *           Read on for why this is done...
     * End Summary)
     *
     * According to the spec, the valid construct
     * TYPE new_str_type : STRING := "hello!"; END_TYPE
     * has two possible routes to type_declaration...
     *
     * Route 1:
     * type_declaration: single_element_type_declaration
     * single_element_type_declaration: simple_type_declaration
     * simple_type_declaration: identifier ':' simple_spec_init
     * simple_spec_init: simple_specification ASSIGN constant
     * (shift:  identifier <- 'new_str_type')
     * simple_specification: elementary_type_name
     * elementary_type_name: STRING
     * (shift: elementary_type_name <- STRING)
     * (reduce: simple_specification <- elementary_type_name)
     * (shift: constant <- "hello!")
     * (reduce: simple_spec_init: simple_specification ASSIGN constant)
     * (reduce: ...)
     *
     *
     * Route 2:
     * type_declaration: string_type_declaration
     * string_type_declaration: identifier ':' elementary_string_type_name string_type_declaration_size
     * string_type_declaration_init (shift:  identifier <- 'new_str_type') elementary_string_type_name: STRING (shift:
     * elementary_string_type_name <- STRING) (shift: string_type_declaration_size <-  empty )
     * string_type_declaration_init: ASSIGN character_string
     * (shift: character_string <- "hello!")
     * (reduce: string_type_declaration_init <- ASSIGN character_string)
     * (reduce: string_type_declaration <- identifier ':' elementary_string_type_name string_type_declaration_size
     * string_type_declaration_init ) (reduce: type_declaration <- string_type_declaration)
     *
     *
     * At first glance it seems that removing route 1 would make
     * the most sense. Unfortunately the construct 'simple_spec_init'
     * shows up multiple times in other rules, so changing this construct
     * would also mean changing all the rules in which it appears.
     * I (Mario) therefore chose to remove route 2 instead. This means
     * that the above declaration gets stored in a
     * simple_type_declaration_c, and not in a string_type_declaration_c
     * as would be expected!
     */
    /*  string_type_name ':' elementary_string_type_name string_type_declaration_size string_type_declaration_init */
    SYM_REF4(string_type_declaration_c,
             string_type_name,
             elementary_string_type_name,
             string_type_declaration_size,
             string_type_declaration_init) /* may be == NULL! */

    /* helper symbol for fb_name_decl_c */
    /* This symbol/leaf does not exist in the IEC standard syntax as an isolated symbol,
     * as, for some reason, the standard syntax defines FB variable declarations in a slightly
     * different style as all other spec_init declarations. I.e., fr FBs variable declarations,
     * the standard defines a single leaf/node (fb_name_decl) that references:
     *   a) the variable name list
     *   b) the FB datatype
     *   c) the FB intial value
     *
     * All other variable declarations break this out into two nodes:
     *   1) references b) and c) above (usually named ***_spec_init)
     *   2) references a), and node 1)
     *
     * In order to allow the datatype analyses to proceed without special cases, we will handle
     * FB variable declarations in the same style. For this reason, we have added the
     * following node to the Abstract Syntax Tree, even though it does not have a direct equivalent in
     * the standard syntax.
     */
    /*  function_block_type_name ASSIGN structure_initialization */
    /* structure_initialization -> may be NULL ! */
    SYM_REF2(fb_spec_init_c, function_block_type_name, structure_initialization)

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

    /* REF_TO (non_generic_type_name | function_block_type_name) */
    SYM_REF1(ref_spec_c, type_name)

    /* ref_spec [ ASSIGN ref_initialization ]; */
    /* NOTE: ref_initialization may be NULL!!  */
    SYM_REF2(ref_spec_init_c, ref_spec, ref_initialization)

    /* identifier ':' ref_spec_init */
    SYM_REF2(ref_type_decl_c, ref_type_name, ref_spec_init)

    /*********************/
    /* B 1.4 - Variables */
    /*********************/
    SYM_REF1(symbolic_variable_c, var_name)

    /* symbolic_constant_c is used only when a variable is used inside the subrange of an array declaration
     *    e.g.: ARRAY [1 .. maxval] OF INT
     *  where maxval is a CONSTANT variable.
     *  When maxval shows up in the POU body,          it will be stored as a standard symbolic_variable_c in the AST.
     *  When maxval shows up in the ARRAY declaration, it will be stored as a          symbolic_constant_c in the AST.
     *  This will allow us to more easily handle this special case, without affecting the remaining working code.
     */
    SYM_REF1(symbolic_constant_c, var_name)  // a non-standard extension!!

    /********************************************/
    /* B.1.4.1   Directly Represented Variables */
    /********************************************/
    SYM_TOKEN(direct_variable_c)

    /*************************************/
    /* B.1.4.2   Multi-element Variables */
    /*************************************/
    /*  subscripted_variable '[' subscript_list ']' */
    SYM_REF2(array_variable_c, subscripted_variable, subscript_list)

    /* subscript_list ',' subscript */
    SYM_LIST(subscript_list_c)

    /*  record_variable '.' field_selector */
    /*  WARNING: input and/or output variables of function blocks
     *           may be accessed as fields of a structured variable!
     *           Code handling a structured_variable_c must take this into account!
     *           (i.e. that a FB instance may be accessed as a structured variable)!
     *
     *  WARNING: Status bit (.X) and activation time (.T) of STEPS in SFC diagrams
     *           may be accessed as fields of a structured variable!
     *           Code handling a structured_variable_c must take this into account
     *           (i.e. that an SFC STEP may be accessed as a structured variable)!
     */
    SYM_REF2(structured_variable_c, record_variable, field_selector)

    /******************************************/
    /* B 1.4.3 - Declaration & Initialisation */
    /******************************************/
    SYM_REF0(constant_option_c)
    SYM_REF0(retain_option_c)
    SYM_REF0(non_retain_option_c)

    /* VAR_INPUT [option] input_declaration_list END_VAR */
    /* option -> the RETAIN/NON_RETAIN/<NULL> directive... */
    /* NOTE: We need to implicitly define the EN and ENO function and FB parameters when the user
     *       does not do it explicitly in the IEC 61131-3 source code.
     *       To be able to distinguish later on between implictly and explicitly defined
     *       variables, we use the 'method' flag that allows us to remember
     *       whether this declaration was in the original source code (method -> implicit_definition_c)
     *       or not (method -> explicit_definition_c).
     */
    SYM_REF3(input_declarations_c, option, input_declaration_list, method)

    /* helper symbol for input_declarations */
    SYM_LIST(input_declaration_list_c)

    /* NOTE: The formal definition of the standard is erroneous, as it simply does not
     *       consider the EN and ENO keywords!
     *       The semantic description of the languages clearly states that these may be
     *       used in several ways. One of them is to declare an EN input parameter, or
     *       an ENO output parameter.
     *       We have added the 'en_param_declaration_c' and 'eno_param_declaration_c'
     *       to cover for this.
     *
     *       We could have re-used the standard class used for all other input variables (with
     *       an identifier set to 'EN' or 'ENO') however we may sometimes need to add this
     *       declaration implicitly (if the user does not include it in the source
     *       code himself), and it is good to know whether it was added implicitly or not.
     *       So we create a new class that has a 'method' flag that allows us to remember
     *       whether this declaration was in the original source code (method -> implicit_definition_c)
     *       or not (method -> explicit_definition_c).
     */
    SYM_REF0(implicit_definition_c)
    SYM_REF0(explicit_definition_c)
    /* type_decl is a simple_spec_init_c */
    SYM_REF3(en_param_declaration_c, name, type_decl, method)
    SYM_REF3(eno_param_declaration_c, name, type, method)

    /* edge -> The F_EDGE or R_EDGE directive */
    SYM_REF2(edge_declaration_c, edge, var1_list)

    SYM_REF0(raising_edge_option_c)
    SYM_REF0(falling_edge_option_c)

    /* spec_init is one of the following...
     *    simple_spec_init_c *
     *    subrange_spec_init_c *
     *    enumerated_spec_init_c *
     */
    SYM_REF2(var1_init_decl_c, var1_list, spec_init)

    /* | var1_list ',' variable_name */
    SYM_LIST(var1_list_c)

    /* | [var1_list ','] variable_name integer '..' */
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
     * The integer tells the compiler the number of the first parameter.
     * for example, for ADD(IN1 := 11, IN2:=22), the index for IN starts off at 1.
     * Some other standard library functions, such as MUX, has the extensible
     * variable starting off from 0 (IN0, IN1, IN2, ...).
     *
     * Of course, we have a flag that disables this syntax when parsing user
     * written code, so we only allow this extra syntax while parsing the
     * 'header' file that declares all the standard IEC 61131-3 functions.
     */
    SYM_REF2(extensible_input_parameter_c, var_name, first_index)

    /* var1_list ':' array_spec_init */
    SYM_REF2(array_var_init_decl_c, var1_list, array_spec_init)

    /*  var1_list ':' initialized_structure */
    SYM_REF2(structured_var_init_decl_c, var1_list, initialized_structure)

    /* fb_name_list ':' function_block_type_name ASSIGN structure_initialization */
    /* NOTE: in order to allow datatype handling to proceed using the normal algorithm with no special cases,
     * we will be storing the
     *    function_block_type_name ASSIGN structure_initialization
     * componentes inside a new node, namely fb_spec_init_c
     */
    /* structure_initialization -> may be NULL ! */
    SYM_REF2(fb_name_decl_c, fb_name_list, fb_spec_init)

    /* fb_name_list ',' fb_name */
    SYM_LIST(fb_name_list_c)

    /* VAR_OUTPUT [RETAIN | NON_RETAIN] var_init_decl_list END_VAR */
    /* option -> may be NULL ! */
    /* NOTE: We need to implicitly define the EN and ENO function and FB parameters when the user
     *       does not do it explicitly in the IEC 61131-3 source code.
     *       To be able to distinguish later on between implictly and explicitly defined
     *       variables, we use the 'method' flag that allows us to remember
     *       whether this declaration was in the original source code (method -> implicit_definition_c)
     *       or not (method -> explicit_definition_c).
     */
    SYM_REF3(output_declarations_c, option, var_init_decl_list, method)

    /*  VAR_IN_OUT var_declaration_list END_VAR */
    SYM_REF1(input_output_declarations_c, var_declaration_list)

    /* helper symbol for input_output_declarations */
    /* var_declaration_list var_declaration ';' */
    SYM_LIST(var_declaration_list_c)

    /*  var1_list ':' array_specification */
    SYM_REF2(array_var_declaration_c, var1_list, array_specification)

    /*  var1_list ':' structure_type_name */
    SYM_REF2(structured_var_declaration_c, var1_list, structure_type_name)

    /* VAR [CONSTANT] var_init_decl_list END_VAR */
    /* option -> may be NULL ! */
    SYM_REF2(var_declarations_c, option, var_init_decl_list)

    /*  VAR RETAIN var_init_decl_list END_VAR */
    SYM_REF1(retentive_var_declarations_c, var_init_decl_list)

    /*  VAR [CONSTANT|RETAIN|NON_RETAIN] located_var_decl_list END_VAR */
    /* option -> may be NULL ! */
    SYM_REF2(located_var_declarations_c, option, located_var_decl_list)

    /* helper symbol for located_var_declarations */
    /* located_var_decl_list located_var_decl ';' */
    SYM_LIST(located_var_decl_list_c)

    /*  [variable_name] location ':' located_var_spec_init */
    /* variable_name -> may be NULL ! */
    SYM_REF3(located_var_decl_c, variable_name, location, located_var_spec_init)

    /*| VAR_EXTERNAL [CONSTANT] external_declaration_list END_VAR */
    /* option -> may be NULL ! */
    SYM_REF2(external_var_declarations_c, option, external_declaration_list)

    /* helper symbol for external_var_declarations */
    /*| external_declaration_list external_declaration';' */
    SYM_LIST(external_declaration_list_c)

    /*  global_var_name ':'
     * (simple_specification|subrange_specification|enumerated_specification|array_specification|prev_declared_structure_type_name|function_block_type_name
     */
    SYM_REF2(external_declaration_c, global_var_name, specification)

    /*| VAR_GLOBAL [CONSTANT|RETAIN] global_var_decl_list END_VAR */
    /* option -> may be NULL ! */
    SYM_REF2(global_var_declarations_c, option, global_var_decl_list)

    /* helper symbol for global_var_declarations */
    /*| global_var_decl_list global_var_decl ';' */
    SYM_LIST(global_var_decl_list_c)

    /*| global_var_spec ':' [located_var_spec_init|function_block_type_name] */
    /* type_specification ->may be NULL ! */
    SYM_REF2(global_var_decl_c, global_var_spec, type_specification)

    /*| global_var_name location */
    SYM_REF2(global_var_spec_c, global_var_name, location)

    /*  AT direct_variable */
    SYM_REF1(location_c, direct_variable)

    /*| global_var_list ',' global_var_name */
    SYM_LIST(global_var_list_c)

    /*  var1_list ':' single_byte_string_spec */
    SYM_REF2(single_byte_string_var_declaration_c, var1_list, single_byte_string_spec)

    /*  STRING ['[' integer ']'] [ASSIGN single_byte_character_string] */
    /* integer ->may be NULL ! */
    /* single_byte_character_string ->may be NULL ! */
    SYM_REF2(single_byte_string_spec_c, string_spec, single_byte_character_string)

    /*   STRING ['[' integer ']'] */
    /* integer ->may be NULL ! */
    SYM_REF2(single_byte_limited_len_string_spec_c, string_type_name, character_string_len)

    /*  WSTRING ['[' integer ']'] */
    /* integer ->may be NULL ! */
    SYM_REF2(double_byte_limited_len_string_spec_c, string_type_name, character_string_len)

    /*  var1_list ':' double_byte_string_spec */
    SYM_REF2(double_byte_string_var_declaration_c, var1_list, double_byte_string_spec)

    /*  WSTRING ['[' integer ']'] [ASSIGN double_byte_character_string] */
    /* integer ->may be NULL ! */
    /* double_byte_character_string ->may be NULL ! */
    SYM_REF2(double_byte_string_spec_c, string_spec, double_byte_character_string)

    /*| VAR [RETAIN|NON_RETAIN] incompl_located_var_decl_list END_VAR */
    /* option ->may be NULL ! */
    SYM_REF2(incompl_located_var_declarations_c, option, incompl_located_var_decl_list)

    /* helper symbol for incompl_located_var_declarations */
    /*| incompl_located_var_decl_list incompl_located_var_decl ';' */
    SYM_LIST(incompl_located_var_decl_list_c)

    /*  variable_name incompl_location ':' var_spec */
    SYM_REF3(incompl_located_var_decl_c, variable_name, incompl_location, var_spec)

    /*  AT incompl_location_token */
    SYM_TOKEN(incompl_location_c)

    /* intermediate helper symbol for:
     *  - non_retentive_var_decls
     *  - output_declarations
     */
    SYM_LIST(var_init_decl_list_c)

    /**************************************/
    /* B.1.5 - Program organization units */
    /**************************************/
    /***********************/
    /* B 1.5.1 - Functions */
    /***********************/
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    SYM_REF4(function_declaration_c,
             derived_function_name,
             type_name,
             var_declarations_list,
             function_body,
             enumvalue_symtable_t enumvalue_symtable;)

    /* intermediate helper symbol for
     * - function_declaration
     * - function_block_declaration
     * - program_declaration
     */
    SYM_LIST(var_declarations_list_c)

    /* option -> storage method, CONSTANT or <null> */
    SYM_REF2(function_var_decls_c, option, decl_list)

    /* intermediate helper symbol for function_var_decls */
    SYM_LIST(var2_init_decl_list_c)

    /*****************************/
    /* B 1.5.2 - Function Blocks */
    /*****************************/
    /*  FUNCTION_BLOCK derived_function_block_name io_OR_other_var_declarations function_block_body END_FUNCTION_BLOCK
     */
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    SYM_REF3(function_block_declaration_c,
             fblock_name,
             var_declarations,
             fblock_body,
             enumvalue_symtable_t enumvalue_symtable;)

    /* intermediate helper symbol for function_declaration */
    /*  { io_var_declarations | other_var_declarations }   */
    /*
     * NOTE: we re-use the var_declarations_list_c
     */

    /*  VAR_TEMP temp_var_decl_list END_VAR */
    SYM_REF1(temp_var_decls_c, var_decl_list)

    /* intermediate helper symbol for temp_var_decls */
    SYM_LIST(temp_var_decls_list_c)

    /*  VAR NON_RETAIN var_init_decl_list END_VAR */
    SYM_REF1(non_retentive_var_decls_c, var_decl_list)

    /**********************/
    /* B 1.5.3 - Programs */
    /**********************/
    /*  PROGRAM program_type_name program_var_declarations_list function_block_body END_PROGRAM */
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    SYM_REF3(program_declaration_c,
             program_type_name,
             var_declarations,
             function_block_body,
             enumvalue_symtable_t enumvalue_symtable;)

    /* intermediate helper symbol for program_declaration_c */
    /*  { io_var_declarations | other_var_declarations }   */
    /*
     * NOTE: we re-use the var_declarations_list_c
     */

    /*********************************************/
    /* B.1.6  Sequential function chart elements */
    /*********************************************/

    /* | sequential_function_chart sfc_network */
    SYM_LIST(sequential_function_chart_c)

    /* initial_step {step | transition | action} */
    SYM_LIST(sfc_network_c)

    /* INITIAL_STEP step_name ':' action_association_list END_STEP */
    SYM_REF2(initial_step_c, step_name, action_association_list)

    /* | action_association_list action_association ';' */
    SYM_LIST(action_association_list_c)

    /* STEP step_name ':' action_association_list END_STEP */
    SYM_REF2(step_c, step_name, action_association_list)

    /* action_name '(' action_qualifier indicator_name_list ')' */
    /* action_qualifier -> may be NULL ! */
    SYM_REF3(action_association_c, action_name, action_qualifier, indicator_name_list)

    /* N | R | S | P */
    SYM_TOKEN(qualifier_c)

    /* L | D | SD | DS | SL */
    SYM_TOKEN(timed_qualifier_c)

    /* | indicator_name_list ',' indicator_name */
    SYM_LIST(indicator_name_list_c)

    /* qualifier | timed_qualifier ',' action_time */
    /* action_time -> may be NULL ! */
    SYM_REF2(action_qualifier_c, action_qualifier, action_time)

    /* TRANSITION [transition_name] ['(' PRIORITY ASSIGN integer ')']
     *   FROM steps TO steps
     *   transition_condition
     * END_TRANSITION
     */
    /* transition_name -> may be NULL ! */
    /* integer -> may be NULL ! */
    SYM_REF5(transition_c, transition_name, integer, from_steps, to_steps, transition_condition)

    /* ':' eol_list simple_instr_list | ASSIGN expression ';' */
    /* transition_condition_il -> may be NULL ! */
    /* transition_condition_st -> may be NULL ! */
    SYM_REF2(transition_condition_c, transition_condition_il, transition_condition_st)

    /* step_name | '(' step_name_list ')' */
    /* step_name      -> may be NULL ! */
    /* step_name_list -> may be NULL ! */
    SYM_REF2(steps_c, step_name, step_name_list)

    /* | step_name_list ',' step_name */
    SYM_LIST(step_name_list_c)

    /* ACTION action_name ':' function_block_body END_ACTION */
    SYM_REF2(action_c, action_name, function_block_body)

    /********************************/
    /* B 1.7 Configuration elements */
    /********************************/

    /*
    CONFIGURATION configuration_name
       optional_global_var_declarations
       (resource_declaration_list | single_resource_declaration)
       optional_access_declarations
       optional_instance_specific_initializations
    END_CONFIGURATION
    */
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    SYM_REF5(configuration_declaration_c,
             configuration_name,
             global_var_declarations,
             resource_declarations,
             access_declarations,
             instance_specific_initializations,
             enumvalue_symtable_t enumvalue_symtable;)

    /* intermediate helper symbol for configuration_declaration  */
    /*  { global_var_declarations_list }   */
    SYM_LIST(global_var_declarations_list_c)

    /* helper symbol for configuration_declaration */
    SYM_LIST(resource_declaration_list_c)

    /*
    RESOURCE resource_name ON resource_type_name
       optional_global_var_declarations
       single_resource_declaration
    END_RESOURCE
    */
    /* enumvalue_symtable is filled in by enum_declaration_check_c, during stage3 semantic verification, with a list of
     * all enumerated constants declared inside this POU */
    SYM_REF4(resource_declaration_c,
             resource_name,
             resource_type_name,
             global_var_declarations,
             resource_declaration,
             enumvalue_symtable_t enumvalue_symtable;)

    /* task_configuration_list program_configuration_list */
    SYM_REF2(single_resource_declaration_c, task_configuration_list, program_configuration_list)

    /* helper symbol for single_resource_declaration */
    SYM_LIST(task_configuration_list_c)

    /* helper symbol for single_resource_declaration */
    SYM_LIST(program_configuration_list_c)

    /* helper symbol for
     *  - access_path
     *  - instance_specific_init
     */
    SYM_LIST(any_fb_name_list_c)

    /*  [resource_name '.'] global_var_name ['.' structure_element_name] */
    SYM_REF3(global_var_reference_c, resource_name, global_var_name, structure_element_name)

    /*  prev_declared_program_name '.' symbolic_variable */
    SYM_REF2(program_output_reference_c, program_name, symbolic_variable)

    /*  TASK task_name task_initialization */
    SYM_REF2(task_configuration_c, task_name, task_initialization)

    /*  '(' [SINGLE ASSIGN data_source ','] [INTERVAL ASSIGN data_source ','] PRIORITY ASSIGN integer ')' */
    SYM_REF3(task_initialization_c, single_data_source, interval_data_source, priority_data_source)

    /*  PROGRAM [RETAIN | NON_RETAIN] program_name [WITH task_name] ':' program_type_name ['(' prog_conf_elements ')']
     */
    SYM_REF5(program_configuration_c, retain_option, program_name, task_name, program_type_name, prog_conf_elements)

    /* prog_conf_elements ',' prog_conf_element */
    SYM_LIST(prog_conf_elements_c)

    /*  fb_name WITH task_name */
    SYM_REF2(fb_task_c, fb_name, task_name)

    /*  any_symbolic_variable ASSIGN prog_data_source */
    SYM_REF2(prog_cnxn_assign_c, symbolic_variable, prog_data_source)

    /* any_symbolic_variable SENDTO data_sink */
    SYM_REF2(prog_cnxn_sendto_c, symbolic_variable, data_sink)

    /* VAR_CONFIG instance_specific_init_list END_VAR */
    SYM_REF1(instance_specific_initializations_c, instance_specific_init_list)

    /* helper symbol for instance_specific_initializations */
    SYM_LIST(instance_specific_init_list_c)

    /* resource_name '.' program_name '.' {fb_name '.'}
        ((variable_name [location] ':' located_var_spec_init) | (fb_name ':' fb_initialization))
    */
    SYM_REF6(instance_specific_init_c,
             resource_name,
             program_name,
             any_fb_name_list,
             variable_name,
             location,
             initialization)

    /* helper symbol for instance_specific_init */
    /* function_block_type_name ':=' structure_initialization */
    SYM_REF2(fb_initialization_c, function_block_type_name, structure_initialization)

    /****************************************/
    /* B.2 - Language IL (Instruction List) */
    /****************************************/
    /***********************************/
    /* B 2.1 Instructions and Operands */
    /***********************************/
    /*| instruction_list il_instruction */
    SYM_LIST(instruction_list_c)

    /* | label ':' [il_incomplete_instruction] eol_list */
    /* NOTE: The parameters 'prev_il_instruction'/'next_il_instruction' are used to point to all previous/next il
     * instructions that may be executed imedaitely before/after this instruction. In case of an il instruction preceded
     * by a label, the previous_il_instruction will include all IL instructions that jump to this label! It is filled in
     * by the flow_control_analysis_c during stage 3. This will essentially be a doubly linked list of il_instruction_c
     * and il_simple_instruction_c objects!!
     */
    SYM_REF2(il_instruction_c, label, il_instruction, std::vector<symbol_c*> prev_il_instruction, next_il_instruction;)

    /* | il_simple_operator [il_operand] */
    SYM_REF2(il_simple_operation_c, il_simple_operator, il_operand)

    /* | function_name [il_operand_list] */
    /* NOTE: The parameter 'called_function_declaration', 'extensible_param_count' and 'candidate_functions' are used to
     * pass data between the stage 3 and stage 4. data between the stage 3 and stage 4. See the comment above
     * function_invocation_c for more details
     */
    SYM_REF2(il_function_call_c, function_name, il_operand_list, symbol_c* called_function_declaration;
             int extensible_param_count;
             std::vector<symbol_c*> candidate_functions;)

    /* | il_expr_operator '(' [il_operand] eol_list [simple_instr_list] ')' */
    /* WARNING
     *   The semantics of the il_expression_c.il_operand member is NOT what you may expect!
     *   In order to simplify processing of the IL code, stage2 will prepend an artifical (and equivalent) 'LD
     * <il_operand>' IL instruction into the simple_instr_list The il_expression_c.il_operand is maintained, in case we
     * really need to handle it as a special case! See the comments in iec_bison.yy for details and an example.
     */
    SYM_REF3(il_expression_c, il_expr_operator, il_operand, simple_instr_list)

    /*  il_jump_operator label */
    SYM_REF2(il_jump_operation_c, il_jump_operator, label)

    /*   il_call_operator prev_declared_fb_name
     * | il_call_operator prev_declared_fb_name '(' ')'
     * | il_call_operator prev_declared_fb_name '(' eol_list ')'
     * | il_call_operator prev_declared_fb_name '(' il_operand_list ')'
     * | il_call_operator prev_declared_fb_name '(' eol_list il_param_list ')'
     */
    /* NOTE: The parameter 'called_fb_declaration'is used to pass data between stage 3 and stage4 (although currently it
     * is not used in stage 4 */
    SYM_REF4(il_fb_call_c, il_call_operator, fb_name, il_operand_list, il_param_list, symbol_c* called_fb_declaration;)

    /* | function_name '(' eol_list [il_param_list] ')' */
    /* NOTE: The parameter 'called_function_declaration', 'extensible_param_count' and 'candidate_functions' are used to
     * pass data between the stage 3 and stage 4. See the comment above function_invocation_c for more details.
     */
    SYM_REF2(il_formal_funct_call_c, function_name, il_param_list, symbol_c* called_function_declaration;
             int extensible_param_count;
             std::vector<symbol_c*> candidate_functions;)

    /* | il_operand_list ',' il_operand */
    SYM_LIST(il_operand_list_c)

    /* | simple_instr_list il_simple_instruction */
    SYM_LIST(simple_instr_list_c)

    /* il_simple_instruction:
     *   il_simple_operation eol_list
     * | il_expression eol_list
     * | il_formal_funct_call eol_list
     */
    /* NOTE: The parameters 'prev_il_instruction'/'next_il_instruction' are used to point to all previous/next il
     * instructions that may be executed imedaitely before/after this instruction. In case of an il instruction preceded
     * by a label, the previous_il_instruction will include all IL instructions that jump to this label! It is filled in
     * by the flow_control_analysis_c during stage 3. This will essentially be a doubly linked list of il_instruction_c
     * and il_simple_instruction_c objects!!
     */
    SYM_REF1(il_simple_instruction_c,
             il_simple_instruction,
             std::vector<symbol_c*> prev_il_instruction,
             next_il_instruction;)

    /* | il_initial_param_list il_param_instruction */
    SYM_LIST(il_param_list_c)

    /*  il_assign_operator il_operand
     * | il_assign_operator '(' eol_list simple_instr_list ')'
     */
    SYM_REF3(il_param_assignment_c, il_assign_operator, il_operand, simple_instr_list)

    /*  il_assign_out_operator variable */
    SYM_REF2(il_param_out_assignment_c, il_assign_out_operator, variable)

    /*******************/
    /* B 2.2 Operators */
    /*******************/
    /* NOTE: The parameter 'called_fb_declaration' is used to pass data between stage 3 and stage4 (although currently
     * it is not used in stage 4 */
    /* NOTE: The parameter 'deprecated_operation' indicates that the operation, with the specific data types being used,
     * is currently defined in the standard as being deprecated. This variable is filled in with the correct value in
     * stage 3 (narrow_candidate_datatypes_c) and currently only used in stage 3 (print_datatypes_error_c).
     */
    SYM_REF0(LD_operator_c)
    SYM_REF0(LDN_operator_c)
    SYM_REF0(ST_operator_c)
    SYM_REF0(STN_operator_c)
    SYM_REF0(NOT_operator_c)
    SYM_REF0(S_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(R_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(S1_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(R1_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(CLK_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(CU_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(CD_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(PV_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(IN_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(PT_operator_c, symbol_c* called_fb_declaration;)
    SYM_REF0(AND_operator_c)
    SYM_REF0(OR_operator_c)
    SYM_REF0(XOR_operator_c)
    SYM_REF0(ANDN_operator_c)
    SYM_REF0(ORN_operator_c)
    SYM_REF0(XORN_operator_c)
    SYM_REF0(ADD_operator_c, bool deprecated_operation;)
    SYM_REF0(SUB_operator_c, bool deprecated_operation;)
    SYM_REF0(MUL_operator_c, bool deprecated_operation;)
    SYM_REF0(DIV_operator_c, bool deprecated_operation;)
    SYM_REF0(MOD_operator_c)
    SYM_REF0(GT_operator_c)
    SYM_REF0(GE_operator_c)
    SYM_REF0(EQ_operator_c)
    SYM_REF0(LT_operator_c)
    SYM_REF0(LE_operator_c)
    SYM_REF0(NE_operator_c)
    SYM_REF0(CAL_operator_c)
    SYM_REF0(CALC_operator_c)
    SYM_REF0(CALCN_operator_c)
    SYM_REF0(RET_operator_c)
    SYM_REF0(RETC_operator_c)
    SYM_REF0(RETCN_operator_c)
    SYM_REF0(JMP_operator_c)
    SYM_REF0(JMPC_operator_c)
    SYM_REF0(JMPCN_operator_c)

    /*  any_identifier ASSIGN */
    SYM_REF1(il_assign_operator_c, variable_name)

    /*| [NOT] any_identifier SENDTO */
    SYM_REF2(il_assign_out_operator_c, option, variable_name)

    /***************************************/
    /* B.3 - Language ST (Structured Text) */
    /***************************************/
    /***********************/
    /* B 3.1 - Expressions */
    /***********************/
    SYM_REF1(ref_expression_c, exp) /* an extension to the IEC 61131-3 standard - based on the IEC 61131-3 v3 standard.
                                       REF() -> returns address of the varible! */
    SYM_REF1(deref_expression_c, exp) /* an extension to the IEC 61131-3 standard - based on the IEC 61131-3 v3
                                         standard. DREF() -> dereferences an address!        */
    SYM_REF1(deref_operator_c, exp) /* an extension to the IEC 61131-3 standard - based on the IEC 61131-3 v3 standard.
                                       ^   -> dereferences an address!        */
    SYM_REF2(or_expression_c, l_exp, r_exp)
    SYM_REF2(xor_expression_c, l_exp, r_exp)
    SYM_REF2(and_expression_c, l_exp, r_exp)
    SYM_REF2(equ_expression_c, l_exp, r_exp)
    SYM_REF2(notequ_expression_c, l_exp, r_exp)
    SYM_REF2(lt_expression_c, l_exp, r_exp)
    SYM_REF2(gt_expression_c, l_exp, r_exp)
    SYM_REF2(le_expression_c, l_exp, r_exp)
    SYM_REF2(ge_expression_c, l_exp, r_exp)
    SYM_REF2(add_expression_c, l_exp, r_exp, bool deprecated_operation;)
    SYM_REF2(sub_expression_c, l_exp, r_exp, bool deprecated_operation;)
    SYM_REF2(mul_expression_c, l_exp, r_exp, bool deprecated_operation;)
    SYM_REF2(div_expression_c, l_exp, r_exp, bool deprecated_operation;)
    SYM_REF2(mod_expression_c, l_exp, r_exp)
    SYM_REF2(power_expression_c, l_exp, r_exp)
    SYM_REF1(neg_expression_c, exp)
    SYM_REF1(not_expression_c, exp)

    /*    formal_param_list -> may be NULL ! */
    /* nonformal_param_list -> may be NULL ! */
    /* NOTES:
     *    The parameter 'called_function_declaration'...
     *       ...is used to pass data between the stage 3 and stage 4.
     *       The IEC 61131-3 standard allows for overloaded standard functions. This means that some
     *       function calls are not completely defined by the name of the function being called,
     *       and need to be disambiguated with using the data types of the parameters being passed.
     *       Stage 3 does this to verify semantic correctness.
     *       Stage 4 also needs to do this in order to determine which function to call.
     *       It does not make sense to determine the exact function being called twice (once in stage 3,
     *       and again in stage 4), so stage 3 will store this info in the parameter called_function_declaration
     *       for stage 4 to use it later on.
     *    The parameter 'candidate_functions'...
     *       ...is used to pass data between two passes within stage 3
     *       (actually between fill_candidate_datatypes_c and narrow_candidate_datatypes_c).
     *       It is used to store all the functions that may be legally called with the current parameters
     *       being used in this function invocation. Note that the standard includes some standard functions
     *       that have the exact same input parameter types, but return different data types.
     *       In order to determine which of these functions should be called, we first create a list
     *       of all possible functions, and then narrow down the list (hopefully down to 1 function)
     *       once we know the data type that the function invocation must return (this will take into
     *       account the expression in which the function invocation is inserted/occurs).
     *       The 'called_function_declaration' will eventually be set (in stage 3) to one of
     *       the functions in the 'candidate_functions' list!
     *    The parameter 'extensible_param_count'...
     *       ...is used to pass data between the stage 3 and stage 4.
     *       The IEC 61131-3 standard allows for extensible standard functions. This means that some
     *       standard functions may be called with a variable number of paramters. Stage 3 will store
     *       in extensible_param_count the number of parameters being passed to the extensible parameter.
     */
    SYM_REF3(function_invocation_c,
             function_name,
             formal_param_list,
             nonformal_param_list,
             symbol_c* called_function_declaration;
             int extensible_param_count;
             std::vector<symbol_c*> candidate_functions;)

    /********************/
    /* B 3.2 Statements */
    /********************/
    SYM_LIST(statement_list_c)

    /*********************************/
    /* B 3.2.1 Assignment Statements */
    /*********************************/
    SYM_REF2(assignment_statement_c, l_exp, r_exp)

    /*****************************************/
    /* B 3.2.2 Subprogram Control Statements */
    /*****************************************/

    /*  RETURN */
    SYM_REF0(return_statement_c)

    /* fb_name '(' [param_assignment_list] ')' */
    /*    formal_param_list -> may be NULL ! */
    /* nonformal_param_list -> may be NULL ! */
    /* NOTE: The parameter 'called_fb_declaration'is used to pass data between stage 3 and stage4 (although currently it
     * is not used in stage 4 */
    SYM_REF3(fb_invocation_c, fb_name, formal_param_list, nonformal_param_list, symbol_c* called_fb_declaration;)

    /* helper symbol for fb_invocation */
    /* param_assignment_list ',' param_assignment */
    SYM_LIST(param_assignment_list_c)

    /*  variable_name ASSIGN expression */
    SYM_REF2(input_variable_param_assignment_c, variable_name, expression)

    /* [NOT] variable_name '=>' variable */
    SYM_REF3(output_variable_param_assignment_c, not_param, variable_name, variable)

    /* helper CLASS for output_variable_param_assignment */
    SYM_REF0(not_paramassign_c)

    /********************************/
    /* B 3.2.3 Selection Statements */
    /********************************/
    /* IF expression THEN statement_list elseif_statement_list ELSE statement_list END_IF */
    SYM_REF4(if_statement_c, expression, statement_list, elseif_statement_list, else_statement_list)

    /* helper symbol for if_statement */
    SYM_LIST(elseif_statement_list_c)

    /* helper symbol for elseif_statement_list */
    /* ELSIF expression THEN statement_list    */
    SYM_REF2(elseif_statement_c, expression, statement_list)

    /* CASE expression OF case_element_list ELSE statement_list END_CASE */
    SYM_REF3(case_statement_c, expression, case_element_list, statement_list)

    /* helper symbol for case_statement */
    SYM_LIST(case_element_list_c)

    /*  case_list ':' statement_list */
    SYM_REF2(case_element_c, case_list, statement_list)

    SYM_LIST(case_list_c)

    /********************************/
    /* B 3.2.4 Iteration Statements */
    /********************************/
    /*  FOR control_variable ASSIGN expression TO expression [BY expression] DO statement_list END_FOR */
    SYM_REF5(for_statement_c, control_variable, beg_expression, end_expression, by_expression, statement_list)

    /*  WHILE expression DO statement_list END_WHILE */
    SYM_REF2(while_statement_c, expression, statement_list)

    /*  REPEAT statement_list UNTIL expression END_REPEAT */
    SYM_REF2(repeat_statement_c, statement_list, expression)

    /*  EXIT */
    SYM_REF0(exit_statement_c)


    //   virtual ~fcall_visitor_c(void);
};

class iterator_visitor_c : public visitor_c {
protected:
    void* visit_list(list_c* list);

public:
#include "absyntax.def"

    virtual ~iterator_visitor_c(void);
};

class fcall_iterator_visitor_c : public iterator_visitor_c {
public:
    virtual void prefix_fcall(symbol_c* symbol);
    virtual void suffix_fcall(symbol_c* symbol);

public:
#include "absyntax.def"

    virtual ~fcall_iterator_visitor_c(void);
};

class search_visitor_c : public visitor_c {
protected:
    void* visit_list(list_c* list);

public:
#include "absyntax.def"

    virtual ~search_visitor_c(void);
};

#undef SYM_LIST
#undef SYM_TOKEN
#undef SYM_REF0
#undef SYM_REF1
#undef SYM_REF2
#undef SYM_REF3
#undef SYM_REF4
#undef SYM_REF5
#undef SYM_REF6
