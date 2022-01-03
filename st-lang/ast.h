#pragma once
#include <cassert>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace ast {
    typedef void* val_t;
    typedef void* func_t;

    enum class binary_op_t {
        // 5
        mul,   // *
        div,   // /
        rdiv,  // %
        // 6
        add,  // +
        sub,  // -
        // 7
        rshift,  // >>
        lshift,  // <<
        // 9
        lt,  // <
        gt,  // >
        le,  // <=
        ge,  // >=
        // 10
        eq,  // ==
        ne,  // !=
        // 11
        band,  // &
        // 12
        bxor,  // ^
        // 13
        bor,  // |

        // 14
        and_,  // &&
        // 15
        or_,  // ||
    };

    /// ExprAST - Base class for all expression nodes.
    class expr_node_t {
    public:
        virtual ~expr_node_t() = default;

        virtual val_t* codegen() = 0;
    };

    /// Expression class for numeric literals like "1.0".
    class float64_expr_t : public expr_node_t {
        double val;

    public:
        float64_expr_t(double Val): val(Val) {}

        val_t* codegen() override;
    };
    /// Expression class for numeric literals like "14234".
    class int64_expr_t : public expr_node_t {
        int64_t val;

    public:
        int64_expr_t(double Val): val(Val) {}

        val_t* codegen() override;
    };
    /// VariableExprAST - Expression class for referencing a variable, like "a".
    class variable_expr_t : public expr_node_t {
        std::string name;

    public:
        variable_expr_t(const std::string& Name): name(Name) {}

        val_t* codegen() override;
        const std::string& getName() const {
            return name;
        }
    };

    /// UnaryExprAST - Expression class for a unary operator.
    class unary_expr_t : public expr_node_t {
        char opcode;
        std::unique_ptr<expr_node_t> operand;

    public:
        unary_expr_t(char Opcode, std::unique_ptr<expr_node_t> Operand): opcode(Opcode), operand(std::move(Operand)) {}

        val_t* codegen() override;
    };

    /// BinaryExprAST - Expression class for a binary operator.
    class binary_expr_t : public expr_node_t {
        char op;
        std::unique_ptr<expr_node_t> lhs, rhs;

    public:
        binary_expr_t(char op, std::unique_ptr<expr_node_t> lhs, std::unique_ptr<expr_node_t> rhs)
            : op(op), lhs(std::move(lhs)), rhs(std::move(rhs)) {}

        val_t* codegen() override;
    };

    /// CallExprAST - Expression class for function calls.
    class call_expr_t : public expr_node_t {
        std::string callee;
        std::vector<std::unique_ptr<expr_node_t>> args;

    public:
        call_expr_t(const std::string& callee, std::vector<std::unique_ptr<expr_node_t>> args)
            : callee(callee), args(std::move(args)) {}

        val_t* codegen() override;
    };

    /// IfExprAST - Expression class for if/then/else.
    class if_expr_t : public expr_node_t {
        std::unique_ptr<expr_node_t> cond, true_stmt, false_stmt;

    public:
        if_expr_t(std::unique_ptr<expr_node_t> cond,
                  std::unique_ptr<expr_node_t> true_stmt,
                  std::unique_ptr<expr_node_t> false_stmt)
            : cond(std::move(cond)), true_stmt(std::move(true_stmt)), false_stmt(std::move(false_stmt)) {}

        val_t* codegen() override;
    };

    /// ForExprAST - Expression class for for/in.
    class for_expr_t : public expr_node_t {
        std::string var_name;
        std::unique_ptr<expr_node_t> start, end, step, body;

    public:
        for_expr_t(const std::string& var_name,
                   std::unique_ptr<expr_node_t> Start,
                   std::unique_ptr<expr_node_t> End,
                   std::unique_ptr<expr_node_t> Step,
                   std::unique_ptr<expr_node_t> body)
            : var_name(var_name), start(std::move(Start)), end(std::move(End)), step(std::move(Step)),
              body(std::move(body)) {}

        val_t* codegen() override;
    };

    /// VarExprAST - Expression class for var/in
    class vardef_expr_t : public expr_node_t {
        std::vector<std::pair< std::string, std::unique_ptr<expr_node_t>>> var_names;
        std::unique_ptr<expr_node_t> body;

    public:
        vardef_expr_t(std::vector<std::pair<std::string, std::unique_ptr<expr_node_t>>> var_names,
                      std::unique_ptr<expr_node_t> body)
            : var_names(std::move(var_names)), body(std::move(body)) {}

        val_t* codegen() override;
    };

    /// PrototypeAST - This class represents the "prototype" for a function,
    /// which captures its name, and its argument names (thus implicitly the number
    /// of arguments the function takes), as well as if it is an operator.
    class prototype_ast_t {
        std::string name;
        std::vector<std::string> args;
        bool is_operator;
        unsigned precedence;  // Precedence if a binary op.

    public:
        prototype_ast_t(const std::string& name,
                        std::vector<std::string> args,
                        bool is_operator = false,
                        unsigned prec = 0)
            : name(name), args(std::move(args)), is_operator(is_operator), precedence(prec) {}

        func_t* codegen();
        const std::string& get_name() const {
            return name;
        }

        bool is_unary() const {
            return is_operator && args.size() == 1;
        }
        bool is_binary() const {
            return is_operator && args.size() == 2;
        }

        char get_operator_name() const {
            assert(is_unary() || is_binary());
            return name[name.size() - 1];
        }

        unsigned get_binary_precedence() const {
            return precedence;
        }
    };

    /// FunctionAST - This class represents a function definition itself.
    class function_ast {
        std::unique_ptr<prototype_ast_t> proto;
        std::unique_ptr<expr_node_t> body;

    public:
        function_ast(std::unique_ptr<prototype_ast_t> Proto, std::unique_ptr<expr_node_t> body)
            : proto(std::move(Proto)), body(std::move(body)) {}

        func_t* codegen();
    };

    /// LogError* - These are little helper functions for error handling.
    std::unique_ptr<expr_node_t> log_error(const char* Str);

    std::unique_ptr<prototype_ast_t> log_error_p(const char* Str);

    /// expression
    ///   ::= unary binoprhs
    ///
    std::unique_ptr<expr_node_t> parse_expression();

    /// numberexpr ::= number
    std::unique_ptr<expr_node_t> parse_int64_expr();

    /// numberexpr ::= number
    std::unique_ptr<expr_node_t> parse_float64_expr();

    /// parenexpr ::= '(' expression ')'
    std::unique_ptr<expr_node_t> parse_paren_expr();

    /// identifierexpr
    ///   ::= identifier
    ///   ::= identifier '(' expression* ')'
    std::unique_ptr<expr_node_t> parse_identifier_expr();

    /// ifexpr ::= 'if' expression 'then' expression 'else' expression
    std::unique_ptr<expr_node_t> parse_if_expr();

    /// forexpr ::= 'for' identifier '=' expr ',' expr (',' expr)? 'in' expression
    std::unique_ptr<expr_node_t> parse_for_expr();

    /// varexpr ::= 'var' identifier ('=' expression)?
    //                    (',' identifier ('=' expression)?)* 'in' expression
    std::unique_ptr<expr_node_t> parse_var_expr();

    /// primary
    ///   ::= identifierexpr
    ///   ::= numberexpr
    ///   ::= parenexpr
    ///   ::= ifexpr
    ///   ::= forexpr
    ///   ::= varexpr
    std::unique_ptr<expr_node_t> parse_primary();

    /// unary
    ///   ::= primary
    ///   ::= '!' unary
    std::unique_ptr<expr_node_t> parse_unary();

    /// binoprhs
    ///   ::= ('+' unary)*
    std::unique_ptr<expr_node_t> parse_bin_op_rhs(int ExprPrec, std::unique_ptr<expr_node_t> LHS);

    /// prototype
    ///   ::= id '(' id* ')'
    ///   ::= binary LETTER number? (id, id)
    ///   ::= unary LETTER (id)
    std::unique_ptr<prototype_ast_t> parse_prototype();

    /// definition ::= 'def' prototype expression
    std::unique_ptr<function_ast> parse_definition();

    /// toplevelexpr ::= expression
    std::unique_ptr<function_ast> parse_top_level_expr();

    /// external ::= 'extern' prototype
    std::unique_ptr<prototype_ast_t> parse_extern();
}  // namespace ast
