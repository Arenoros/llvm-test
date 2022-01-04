#include <errno.h>
#include <string.h>
#include <iostream>
#include "parser.h"
#include "parser_priv.h"

int main() {
    yyscan_t scanner;
    yylex_init(&scanner);
    FILE* fin = nullptr;
    auto err = fopen_s(&fin, "test1.txt", "r");
    if (err) {
        char errmsg[255] = {0};
        strerror_s(errmsg, 254, err);
        std::cerr << errmsg << std::endl;
        return 1;
    }
    yyset_in(fin, scanner);
    runtime_options.allow_void_datatype = false; /* disable: allow declaration of functions returning VOID  */
    runtime_options.allow_missing_var_in =
        false; /* disable: allow definition and invocation of POUs with no input, output and in_out parameters! */
    runtime_options.disable_implicit_en_eno = false; /* disable: do not generate EN and ENO parameters */
    runtime_options.pre_parsing = false; /* disable: allow use of forward references (run pre-parsing phase before the
                                            definitive parsing phase that builds the AST) */
    runtime_options.safe_extensions = false;      /* disable: allow use of SAFExxx datatypes */
    runtime_options.full_token_loc = false;       /* disable: error messages specify full token location */
    runtime_options.conversion_functions = false; /* disable: create a conversion function for derived datatype */
    runtime_options.nested_comments = false;      /* disable: Allow the use of nested comments. */
    runtime_options.ref_standard_extensions =
        false; /* disable: Allow the use of REFerences (keywords REF_TO, REF, DREF, ^, NULL). */
    runtime_options.ref_nonstand_extensions = false;  /* disable: Allow the use of non-standard extensions to REF_TO
                                                         datatypes: REF_TO ANY, and REF_TO in struct elements! */
    runtime_options.nonliteral_in_array_size = false; /* disable: Allow the use of constant non-literals when specifying
                                                         size of arrays (ARRAY [1..max] OF INT) */
    runtime_options.includedir = NULL; /* Include directory, where included files will be searched for... */

    /* Default values for the command line options... */
    runtime_options.relaxed_datatype_model = false; /* by default use the strict datatype equivalence model */
    parser_t parser;
    yyset_extra(&parser, scanner);
    parser_t* test = (parser_t*)yyget_extra(scanner);

    int rv = yyparse(scanner, &parser);

    yylex_destroy(scanner);
    return 0;
}

void yyerror(YYLTYPE* locp, yyscan_t scanner, parser_t* parser, const char* msg) {}
