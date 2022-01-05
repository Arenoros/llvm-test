#pragma once

#include <stdio.h>  // required for NULL
#include <vector>
#include <map>
#include <string>
#include <stdint.h>  // required for uint64_t, etc...
/* Function used throughout the code --> used to report failed assertions (i.e. internal compiler errors)! */
#include <list>
#include <stddef.h> /* required for NULL */
#define ERROR error_exit(__FILE__, __LINE__)
#define ERROR_MSG(msg, ...) error_exit(__FILE__, __LINE__, msg, ##__VA_ARGS__)

extern void error_exit(const char* file_name, int line_no, const char* errmsg = NULL, ...);

/* Get the definition of INT16_MAX, INT16_MIN, UINT64_MAX, INT64_MAX, INT64_MIN, ... */
#ifndef __STDC_LIMIT_MACROS
#    define __STDC_LIMIT_MACROS /* required to have UINTxx_MAX defined when including stdint.h from C++ source code.   \
                                 */
#endif
#include <stdint.h>
#include <limits>

#ifndef UINT64_MAX
#    define UINT64_MAX (std::numeric_limits<uint64_t>::max())
#endif
#ifndef INT64_MAX
#    define INT64_MAX (std::numeric_limits<int64_t>::max())
#endif
#ifndef INT64_MIN
#    define INT64_MIN (std::numeric_limits<int64_t>::min())
#endif

/* Determine, for the current platform, which datas types (float, double or long double) use 64 and 32 bits. */
/* NOTE: We cant use sizeof() in pre-processor directives, so we have to do it another way... */
/* CURIOSITY: We can use sizeof() and offsetof() inside static_assert() but:
 *          - this only allows us to make assertions, and not #define new macros
 *          - is only available in the C standard [ISO/IEC 9899:2011] and the C++ 0X draft standard [Becker 2008]. It is
 * not available in C99.
 *          https://www.securecoding.cert.org/confluence/display/seccode/DCL03-C.+Use+a+static+assertion+to+test+the+value+of+a+constant+expression
 *         struct {int a, b, c, d} header_t;
 *  e.g.:  static_assert(offsetof(struct header_t, c) == 8, "Compile time error message.");
 */

#include <float.h>
#if (LDBL_MANT_DIG == 53)         /* NOTE: 64 bit IEC559 real has 53 bits for mantissa! */
#    define real64_tX long_double /* so we can later use #if (real64_t == long_double) directives in the code! */
#    define real64_t long double  /* NOTE: no underscore '_' between 'long' and 'double' */
#    define REAL64_MAX LDBL_MAX
#elif (DBL_MANT_DIG == 53) /* NOTE: 64 bit IEC559 real has 53 bits for mantissa! */
#    define real64_tX double
#    define real64_t double
#    define REAL64_MAX DBL_MAX
#elif (FLT_MANT_DIG == 53) /* NOTE: 64 bit IEC559 real has 53 bits for mantissa! */
#    define real64_tX float
#    define real64_t float
#    define REAL64_MAX FLT_MAX
#else
#    error Could not find a 64 bit floating point data type on this platform. Aborting...
#endif

#if (LDBL_MANT_DIG == 24)         /* NOTE: 32 bit IEC559 real has 24 bits for mantissa! */
#    define real32_tX long_double /* so we can later use #if (real32_t == long_double) directives in the code! */
#    define real32_t long double  /* NOTE: no underscore '_' between 'long' and 'double' */
#    define REAL32_MAX LDBL_MAX
#elif (DBL_MANT_DIG == 24) /* NOTE: 32 bit IEC559 real has 24 bits for mantissa! */
#    define real32_tX double
#    define real32_t double
#    define REAL32_MAX DBL_MAX
#elif (FLT_MANT_DIG == 24) /* NOTE: 32 bit IEC559 real has 24 bits for mantissa! */
#    define real32_tX float
#    define real32_t float
#    define REAL32_MAX FLT_MAX
#else
#    error Could not find a 32 bit floating point data type on this platform. Aborting...
#endif

#include <math.h>
#ifndef INFINITY
#    error Could not find the macro that defines the value for INFINITY in the current platform.
#endif
#ifndef NAN
#    error Could not find the macro that defines the value for NAN in the current platform.
#endif

/* get the printf format macros for printing variables of fixed data size
 * e.g.  int64_t v; printf("value=%"PRId64" !!\n", v);
 * e.g. uint64_t v; printf("value=%"PRIu64" !!\n", v);
 * e.g. uint64_t v; printf("value=%"PRIx64" !!\n", v);  // hexadecimal format
 */
#ifndef __STDC_FORMAT_MACROS
#    define __STDC_FORMAT_MACROS
#endif
#include <inttypes.h>

/* Compiler options, specified at runtime on the command line */

typedef struct {
    /* options specific to stage1_2 */
    bool allow_void_datatype; /* Allow declaration of functions returning VOID  */
    bool
        allow_missing_var_in; /* Allow definition and invocation of POUs with no input, output and in_out parameters! */
    bool disable_implicit_en_eno; /* Disable the generation of implicit EN and ENO parameters on functions and Function
                                     Blocks */
    bool pre_parsing;     /* Support forward references (Run a pre-parsing phase before the defintive parsing phase that
                             builds the AST) */
    bool safe_extensions; /* support SAFE_* datatypes defined in PLCOpen TC5 "Safety Software Technical Specification -
                             Part 1" v1.0 */
    bool full_token_loc;  /* error messages specify full token location */
    bool conversion_functions;     /* Create a conversion function for derived datatype */
    bool nested_comments;          /* Allow the use of nested comments. */
    bool ref_standard_extensions;  /* Allow the use of REFerences (keywords REF_TO, REF, DREF, ^, NULL). */
    bool ref_nonstand_extensions;  /* Allow the use of non-standard extensions to REF_TO datatypes: REF_TO ANY, and
                                      REF_TO in struct elements! */
    bool nonliteral_in_array_size; /* Allow the use of constant non-literals when specifying size of arrays (ARRAY
                                      [1..max] OF INT) */
    const char* includedir;        /* Include directory, where included files will be searched for... */

    /* options specific to stage3 */
    bool relaxed_datatype_model; /* Use the relaxed datatype equivalence model, instead of the default strict
                                    equivalence model */
} runtime_options_t;

extern runtime_options_t runtime_options;

/* Forward declaration of the visitor interface
 * declared in the visitor.hh file
 * We cannot include the visitor.hh file, as it will
 * include this same file first, as it too requires references
 * to the abstract syntax classes defined here.
 */
class visitor_c;  // forward declaration

class symbol_c;  // forward declaration

/* Case insensitive string compare */
/* Case insensitive string compare copied from
 * "The C++ Programming Language" - 3rd Edition
 * by Bjarne Stroustrup, ISBN 0201889544.
 */
class nocasecmp_c {
public:
    bool operator()(const std::string& x, const std::string& y) const {
        std::string::const_iterator ix = x.begin();
        std::string::const_iterator iy = y.begin();

        for (; (ix != x.end()) && (iy != y.end()) && (toupper(*ix) == toupper(*iy)); ++ix, ++iy)
            ;
        if (ix == x.end())
            return (iy != y.end());
        if (iy == y.end())
            return false;
        return (toupper(*ix) < toupper(*iy));
    };
};

/*** constant folding ***/
/* During stage 3 (semantic analysis/checking) we will be doing constant folding.
 * That algorithm will anotate the abstract syntax tree with the result of operations
 * on literals (i.e. 44 + 55 will store the result 99).
 * Since the same source code (e.g. 1 + 0) may actually be a BOOL or an ANY_INT,
 * or an ANY_BIT, we need to handle all possibilities, and determine the result of the
 * operation assuming each type.
 * For this reason, we have one entry for each possible type, with some expressions
 * having more than one entry filled in!
 */
class const_value_c {
public:
    typedef enum {
        cs_undefined,   /* not defined/not yet evaluated --> const_value is not valid! */
        cs_non_const,   /* we have determined that expression is not a const value --> const_value is not valid! */
        cs_const_value, /* const value is valid */
        cs_overflow     /* result produced overflow or underflow --> const_value is not valid! */
    } const_status_t;

    template<typename value_type>
    class const_value__ {
        const_status_t status;
        value_type value;

    public:
        const_value__(void): status(cs_undefined), value(0){};

        value_type get(void) {
            return value;
        }
        void set(value_type value_) {
            status = cs_const_value;
            value = value_;
        }
        void set_overflow(void) {
            status = cs_overflow;
        }
        void set_nonconst(void) {
            status = cs_non_const;
        }
        bool is_valid(void) {
            return (status == cs_const_value);
        }
        bool is_overflow(void) {
            return (status == cs_overflow);
        }
        bool is_nonconst(void) {
            return (status == cs_non_const);
        }
        bool is_undefined(void) {
            return (status == cs_undefined);
        }
        bool is_zero(void) {
            return (is_valid() && (get() == 0));
        }

        /* comparison operator */
        bool operator==(const const_value__ cv) {
            return (((status != cs_const_value) && (status == cv.status)) ||
                    ((status == cs_const_value) && (value == cv.value)));
        }
    };

    const_value__<int64_t> _int64v;  /* status is initialised to UNDEFINED */
    const_value__<uint64_t> _uint64; /* status is initialised to UNDEFINED */
    const_value__<real64_t> _real64; /* status is initialised to UNDEFINED */
    const_value__<bool> _bool;       /* status is initialised to UNDEFINED */

    /* default constructor and destructor */
    const_value_c(void){};
    ~const_value_c(void){};

    /* comparison operator */
    bool operator==(const const_value_c cv) {
        return ((_int64v == cv._int64v) && (_uint64 == cv._uint64) && (_real64 == cv._real64) && (_bool == cv._bool));
    }

    /* return true if at least one of the const values (int, real, ...) is a valid const value */
    bool is_const(void) {
        return (_int64v.is_valid() || _uint64.is_valid() || _real64.is_valid() || _bool.is_valid());
    }
};

// A forward declaration
class token_c;

/* The base class of all symbols */
class symbol_c {
public:
    /* WARNING: only use this method for debugging purposes!! */
    virtual const char* absyntax_cname(void) {
        return "symbol_c";
    };

    /*
     * Annotations produced during stage 1_2
     */
    /* Points to the parent symbol in the AST, i.e. the symbol in the AST that will contain the current symbol */
    symbol_c* parent;
    /* Some symbols may not be tokens, but may be clearly identified by a token.
     * For e.g., a FUNCTION declaration is not itself a token, but may be clearly identified by the
     * token_c object that contains it's name. Another example is an element in a STRUCT declaration,
     * where the structure_element_declaration_c is not itself a token, but can be clearly identified
     * by the structure_element_name
     * To make it easier to find these tokens from the top level object, we will have the stage1_2 populate this
     * token_c *token wherever it makes sense.
     * NOTE: This was a late addition to the AST. Not all objects may be currently so populated.
     *       If you need this please make sure the bison code is populating it correctly for your use case.
     */
    token_c* token;

    /* Line number for the purposes of error checking.  */
    int first_line;
    int first_column;
    const char* first_file; /* filename referenced by first line/column */
    long int first_order;   /* relative order in which it is read by lexcial analyser */
    int last_line;
    int last_column;
    const char* last_file; /* filename referenced by last line/column */
    long int last_order;   /* relative order in which it is read by lexcial analyser */

    /*
     * Annotations produced during stage 3
     */
    /*** Data type analysis ***/
    std::vector<symbol_c*> candidate_datatypes; /* All possible data types the expression/literal/etc. may take. Filled
                                                   in stage3 by fill_candidate_datatypes_c class */
    /* Data type of the expression/literal/etc. Filled in stage3 by narrow_candidate_datatypes_c
     * If set to NULL, it means it has not yet been evaluated.
     * If it points to an object of type invalid_type_name_c, it means it is invalid.
     * Otherwise, it points to an object of the apropriate data type (e.g. int_type_name_c, bool_type_name_c, ...)
     */
    symbol_c* datatype;
    /* The POU in which the symbolic variable (or structured variable, or array variable, or located variable, - any
     * more?) was declared. This will point to a Configuration, Resource, Program, FB, or Function. This is set in stage
     * 3 by the datatype analyser algorithm (fill/narrow) for the symbols: symbolic_variable_c, array_variable_c,
     * structured_variable_c
     */
    symbol_c* scope;

    /*** constant folding ***/
    /* If the symbol has a constant numerical value, this will be set to that value by constant_folding_c */
    const_value_c const_value;

    /*** Enumeration datatype checking ***/
    /* Not all symbols will contain the following anotations, which is why they are not declared here in symbol_c
     * They will be declared only inside the symbols that require them (have a look at absyntax.def)
     */
    typedef std::multimap<std::string, symbol_c*, nocasecmp_c> enumvalue_symtable_t;

    /*
     * Annotations produced during stage 4
     */
    /* Since we support several distinct stage_4 implementations, having explicit entries for each
     * possible use would quickly get out of hand.
     * We therefore simply add a map, that each stage 4 may use for all its needs.
     */
    typedef std::map<std::string, symbol_c*> anotations_map_t;
    anotations_map_t anotations_map;

public:
    /* default constructor */
    symbol_c(int fl = 0,
             int fc = 0,
             const char* ffile = NULL /* filename */,
             long int forder = 0, /* order in which it is read by lexcial analyser */
             int ll = 0,
             int lc = 0,
             const char* lfile = NULL /* filename */,
             long int lorder = 0 /* order in which it is read by lexcial analyser */
    );

    /* default destructor */
    /* must be virtual so compiler does not complain... */
    virtual ~symbol_c(void) {
        return;
    };

    virtual void* accept(visitor_c& visitor) {
        return NULL;
    };
};

class token_c : public symbol_c {
public:
    /* WARNING: only use this method for debugging purposes!! */
    virtual const char* absyntax_cname(void) {
        return "token_c";
    };

    /* the value of the symbol. */
    const char* value;

public:
    token_c(const char* value,
            int fl = 0,
            int fc = 0,
            const char* ffile = NULL /* filename */,
            long int forder = 0, /* order in which it is read by lexcial analyser */
            int ll = 0,
            int lc = 0,
            const char* lfile = NULL /* filename */,
            long int lorder = 0 /* order in which it is read by lexcial analyser */
    );
};

/* a list of symbols... */
class list_c : public symbol_c {
public:
    /* WARNING: only use this method for debugging purposes!! */
    virtual const char* absyntax_cname(void) {
        return "list_c";
    };

    // int c, n; /* c: current capacity of list (malloc'd memory);  n: current number of elements in list */
private:
    //     symbol_c **elements;
    typedef struct {
        const char* token_value;
        symbol_c* symbol;
    } element_entry_t;
    // element_entry_t* elements;
    std::vector<element_entry_t> elements;

public:
    list_c(int fl = 0,
           int fc = 0,
           const char* ffile = NULL /* filename */,
           long int forder = 0, /* order in which it is read by lexcial analyser */
           int ll = 0,
           int lc = 0,
           const char* lfile = NULL /* filename */,
           long int lorder = 0 /* order in which it is read by lexcial analyser */
    );

    list_c(symbol_c* elem,
           int fl = 0,
           int fc = 0,
           const char* ffile = NULL /* filename */,
           long int forder = 0, /* order in which it is read by lexcial analyser */
           int ll = 0,
           int lc = 0,
           const char* lfile = NULL /* filename */,
           long int lorder = 0 /* order in which it is read by lexcial analyser */
    );
    int size() const {
        return elements.size();
    }
    /* get element in position pos of the list */
    virtual symbol_c* get_element(size_t pos);
    /* find element associated to token value */
    virtual symbol_c* find_element(symbol_c* token);
    virtual symbol_c* find_element(const char* token_value);
    /* append a new element to the end of the list */
    virtual void add_element(symbol_c* elem);
    virtual void add_element(symbol_c* elem, symbol_c* token);
    virtual void add_element(symbol_c* elem, const char* token_value);
    /* insert a new element before position pos. */
    /* To insert into the begining of list, call with pos=0  */
    /* To insert into the end of list, call with pos=list->n */
    virtual void insert_element(symbol_c* elem, const char* token_value, int pos = 0);
    virtual void insert_element(symbol_c* elem, symbol_c* token, int pos = 0);
    virtual void insert_element(symbol_c* elem, int pos = 0);
    // virtual void insert_element(symbol_c *elem, int pos, std::string map_ref);
    /* remove element at position pos. */
    virtual void remove_element(int pos = 0);
    /* remove all elements from list. Does not delete the elements in the list! */
    virtual void clear(void);
};

#define SYM_LIST(class_name_c, ...)                                                                                    \
    class class_name_c : public list_c {                                                                               \
    public:                                                                                                            \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        class_name_c(symbol_c* elem,                                                                                   \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_TOKEN(class_name_c, ...)                                                                                   \
    class class_name_c : public token_c {                                                                              \
    public:                                                                                                            \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(const char* value,                                                                                \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF0(class_name_c, ...)                                                                                    \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF1(class_name_c, ref1, ...)                                                                              \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF2(class_name_c, ref1, ref2, ...)                                                                        \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        symbol_c* ref2;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     symbol_c* ref2 = NULL,                                                                            \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF3(class_name_c, ref1, ref2, ref3, ...)                                                                  \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        symbol_c* ref2;                                                                                                \
        symbol_c* ref3;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     symbol_c* ref2,                                                                                   \
                     symbol_c* ref3,                                                                                   \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF4(class_name_c, ref1, ref2, ref3, ref4, ...)                                                            \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        symbol_c* ref2;                                                                                                \
        symbol_c* ref3;                                                                                                \
        symbol_c* ref4;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     symbol_c* ref2,                                                                                   \
                     symbol_c* ref3,                                                                                   \
                     symbol_c* ref4 = NULL,                                                                            \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF5(class_name_c, ref1, ref2, ref3, ref4, ref5, ...)                                                      \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        symbol_c* ref2;                                                                                                \
        symbol_c* ref3;                                                                                                \
        symbol_c* ref4;                                                                                                \
        symbol_c* ref5;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     symbol_c* ref2,                                                                                   \
                     symbol_c* ref3,                                                                                   \
                     symbol_c* ref4,                                                                                   \
                     symbol_c* ref5,                                                                                   \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

#define SYM_REF6(class_name_c, ref1, ref2, ref3, ref4, ref5, ref6, ...)                                                \
    class class_name_c : public symbol_c {                                                                             \
    public:                                                                                                            \
        symbol_c* ref1;                                                                                                \
        symbol_c* ref2;                                                                                                \
        symbol_c* ref3;                                                                                                \
        symbol_c* ref4;                                                                                                \
        symbol_c* ref5;                                                                                                \
        symbol_c* ref6;                                                                                                \
        __VA_ARGS__                                                                                                    \
    public:                                                                                                            \
        class_name_c(symbol_c* ref1,                                                                                   \
                     symbol_c* ref2,                                                                                   \
                     symbol_c* ref3,                                                                                   \
                     symbol_c* ref4,                                                                                   \
                     symbol_c* ref5,                                                                                   \
                     symbol_c* ref6 = NULL,                                                                            \
                     int fl = 0,                                                                                       \
                     int fc = 0,                                                                                       \
                     const char* ffile = NULL /* filename */,                                                          \
                     long int forder = 0,                                                                              \
                     int ll = 0,                                                                                       \
                     int lc = 0,                                                                                       \
                     const char* lfile = NULL /* filename */,                                                          \
                     long int lorder = 0);                                                                             \
        virtual void* accept(visitor_c& visitor);                                                                      \
        /* WARNING: only use this method for debugging purposes!! */                                                   \
        virtual const char* absyntax_cname(void) {                                                                     \
            return #class_name_c;                                                                                      \
        };                                                                                                             \
    };

//#define SYM_REFN_DECL(r, data, elem) data elem;
//#define SYM_REFN_DEF(r, data, elem) data elem,
//
//#define SYM_REFN(class_name_c, ...)                                                                                    \
//    class class_name_c : public symbol_c {                                                                             \
//    public:                                                                                                            \
//        BOOST_PP_SEQ_FOR_EACH(SYM_REFN_DECL, symbol_c*, BOOST_PP_TUPLE_TO_SEQ((__VA_ARGS__)))                          \
//    public:                                                                                                            \
//        class_name_c(BOOST_PP_SEQ_FOR_EACH(SYM_REFN_DEF, symbol_c*, BOOST_PP_TUPLE_TO_SEQ((__VA_ARGS__))) int fl = 0,  \
//                     int fc = 0,                                                                                       \
//                     const char* ffile = NULL /* filename */,                                                          \
//                     long int forder = 0,                                                                              \
//                     int ll = 0,                                                                                       \
//                     int lc = 0,                                                                                       \
//                     const char* lfile = NULL /* filename */,                                                          \
//                     long int lorder = 0);                                                                             \
//        virtual void* accept(visitor_c& visitor);                                                                      \
//        /* WARNING: only use this method for debugging purposes!! */                                                   \
//        virtual const char* absyntax_cname(void) {                                                                     \
//            return #class_name_c;                                                                                      \
//        };                                                                                                             \
//    };


#include "absyntax.def"

#undef SYM_LIST
#undef SYM_TOKEN
#undef SYM_REF0
#undef SYM_REF1
#undef SYM_REF2
#undef SYM_REF3
#undef SYM_REF4
#undef SYM_REF5
#undef SYM_REF6
