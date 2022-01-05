#pragma once

#include "core.h"
#include "add_en_eno_param_decl.h"
#include "flex_priv.h"
#include "ast.h"
#include "traking.h"

#define MAX_LINE_LENGTH 1024
typedef void* yyscan_t;

struct parser_t {
    symbol_c* tree_root;
    tracking_t* current_tracking;
    tracking_t previous_tracking;
    std::vector<include_stack_t> include_stack;

    /* The buffer used by the body_state state */
    tracking_t bodystate_init_tracking;
    std::string bodystate_buffer;
    bool bodystate_is_whitespace = 1;

    int include_stack_ptr = 0;
    long int current_order = 0;
    /*************************/
    /* Tracking Functions... */
    /*************************/
    parser_t() {
        tree_root = new library_c();
        current_tracking = new tracking_t;
    }
    list_c* root() const {
        return (list_c*)tree_root;
    }
    /* print the include file stack to stderr... */
    void print_include_stack(void) {
        if (!include_stack.empty())
            fprintf(stderr, "in file ");
        for (auto& inc: include_stack)
            fprintf(stderr, "included from file %s:%d\n", inc.filename, inc.env->lineNumber);
    }
    void FreeTracking(tracking_t* tracking) {
        include_stack.pop_back();
        delete tracking;
    }
    int lineNumber() {
        return current_tracking->lineNumber;
    }
    int currentChar() {
        return current_tracking->currentChar;
    }
    void backup_tracking() {
        previous_tracking = *current_tracking;
    }
    void restore_tracking() {
        *current_tracking = previous_tracking;
    }
    void update_cur_tocken() {
        current_tracking->currentTokenStart = current_tracking->currentChar;
    }
    void UpdateTracking(const char* text) {
        const char *newline, *token = text;
        while ((newline = strchr(token, '\n')) != NULL) {
            token = newline + 1;
            current_tracking->lineNumber++;
            current_tracking->currentChar = 1;
        }
        current_tracking->currentChar += strlen(token);
    }
};