#pragma once
#include <iostream>
#include <list>

class oper_t {  // abstract
protected:
    oper_t() {}

public:
    virtual ~oper_t() {}
};

class expr_t {  // abstract
protected:
    expr_t() {}

public:
    virtual ~expr_t() {}
};

class block : public oper_t {
    std::list<oper_t*> ops;
    void append(oper_t* op) {
        block* b = dynamic_cast<block*>(op);
        if (b) {
            ops.splice(ops.end(), b->ops, b->ops.begin(), b->ops.end());
            delete b;
        } else
            ops.push_back(op);
    }

public:
    block() {}
    block(oper_t* op) {
        append(op);
    }
    block(oper_t* op1, oper_t* op2) {
        append(op1);
        append(op2);
    }
};

class exprop : public oper_t {
    expr_t* expr;

public:
    exprop(expr_t* expr): expr(expr) {}
};

class ifop : public oper_t {
    expr_t* cond;
    block thenops, elseops;

public:
    ifop(expr_t* cond, oper_t* thenops, oper_t* elseops): cond(cond), thenops(thenops), elseops(elseops) {}
};

class whileop : public oper_t {
    expr_t* cond;
    block ops;

public:
    whileop(expr_t* cond, oper_t* ops): cond(cond), ops(ops) {}
};

class exitop : public oper_t {};

class binary : public expr_t {
    const char* op;
    expr_t *arg1, *arg2;

public:
    binary(const char* op, expr_t* arg1, expr_t* arg2): op(op), arg1(arg1), arg2(arg2) {}
};

class assign : public expr_t {
    std::string name;
    expr_t* value;

public:
    assign(const std::string& name, expr_t* value): name(name), value(value) {}
};

class unary : public expr_t {
    const char* op;
    expr_t* arg;

public:
    unary(const char* op, expr_t* arg): op(op), arg(arg) {}
};

class funcall : public expr_t {
    std::string name;
    std::list<expr_t*> args;

public:
    funcall(const std::string& name, const std::list<expr_t*>& args): name(name), args(args) {}
};

class value : public expr_t {
    std::string text;

public:
    value(const std::string& text): text(text) {}
};

typedef struct {
    std::string str;
    oper_t* oper;
    expr_t* expr;
    std::list<expr_t*> args;
} ast_t;

inline std::string replaceAll(const std::string& where, const std::string& what, const std::string& withWhat) {
    std::string result = where;
    while (1) {
        int pos = result.find(what);
        if (pos == -1)
            return result;
        result.replace(pos, what.size(), withWhat);
    }
}
inline void yyerror(char const* msg) {
    printf("%s", msg);
}