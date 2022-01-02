#pragma once
#include <iostream>
#include <list>
#include "llvm/IR/DerivedTypes.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Verifier.h"
#include "llvm/IR/IRBuilder.h"
#include <llvm/Support/raw_ostream.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/IR/LLVMContext.h>
#include <iostream>
#include <vector>
#include <list>
#include <map>
#include <stdlib.h>
#include <string>
#include <sstream>

using namespace llvm;
void yyerror(char const* msg);

Value* ErrorV(const char* Str);
AllocaInst* CreateEntryBlockAlloca(LLVMContext& ctx, Function* TheFunction, const std::string& VarName);
Function* declare_printf(Module* mod);
Function* declare_scanf(Module* mod);
Function* declare_exit(Module* mod);

struct llvm_ctx {
    LLVMContext& Context;
    IRBuilder<>& Builder;
    Value* zero;
    Function *func_printf, *func_scanf, *func_exit;
    std::map<std::string, Value*> VarDict;
    Value *format1, *format2;
    Function* func_main;
    AllocaInst* int_for_scanf;
    llvm_ctx(Module& modl, IRBuilder<>& Builder, Function* func_main)
        : Context(modl.getContext()), Builder(Builder), func_printf(nullptr), func_scanf(nullptr), func_exit(nullptr),
          func_main(func_main) {
        zero = ConstantInt::get(IntegerType::get(Context, 32), 0);
        format1 = Builder.CreateGlobalStringPtr("%d", ".format1");
        format2 = Builder.CreateGlobalStringPtr("%s", ".format2");
        int_for_scanf = CreateEntryBlockAlloca(Context, func_main, "int_for_scanf___");
        func_printf = declare_printf(&modl);
        func_scanf = declare_scanf(&modl);
        func_exit = declare_exit(&modl);
    }
};
class oper_t {  // abstract
protected:
    oper_t() {}

public:
    virtual ~oper_t() {}
    virtual Value* emit(llvm_ctx& ctx) = 0;
};

class expr_t {  // abstract
protected:
    expr_t() {}

public:
    virtual ~expr_t() {}
    virtual Value* emit(llvm_ctx& ctx) = 0;
};

class block : public oper_t {
    std::list<oper_t*> ops;

    void append(oper_t* op) {
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
    int size() {
        return ops.size();
    }

    virtual Value* emit(llvm_ctx& ctx) {
        Value* result = nullptr;
        for (auto i = ops.begin(); i != ops.end(); i++) {
            result = (*i)->emit(ctx);
        }
        return result;
    }
    virtual ~block() {}
};

class exprop : public oper_t {
    expr_t* expr;

public:
    exprop(expr_t* expr): expr(expr) {}
    virtual Value* emit(llvm_ctx& ctx) {
        return expr->emit(ctx);
    }
    virtual ~exprop() {}
};

class ifop : public oper_t {
    expr_t* cond;
    block thenops, elseops;

public:
    ifop(expr_t* cond, oper_t* thenops, oper_t* elseops): cond(cond), thenops(thenops), elseops(elseops) {}
    virtual Value* emit(llvm_ctx& ctx) {
        Value* CondV = cond->emit(ctx);
        if (CondV == 0)
            return 0;
        // Convert condition to a bool by comparing equal to 0.0.
        CondV = ctx.Builder.CreateICmpNE(CondV, ctx.zero, "ifcond");
        Function* TheFunction = ctx.Builder.GetInsertBlock()->getParent();

        // Create blocks for the then and else cases.  Insert the 'then' block at the
        // end of the function.
        BasicBlock* ThenBB = BasicBlock::Create(ctx.Context, "", TheFunction);
        BasicBlock* ElseBB = BasicBlock::Create(ctx.Context, "");
        BasicBlock* MergeBB = BasicBlock::Create(ctx.Context, "");
        ctx.Builder.CreateCondBr(CondV, ThenBB, ElseBB);

        ctx.Builder.SetInsertPoint(ThenBB);

        this->thenops.emit(ctx);

        ctx.Builder.CreateBr(MergeBB);

        TheFunction->getBasicBlockList().push_back(ElseBB);
        ctx.Builder.SetInsertPoint(ElseBB);

        this->elseops.emit(ctx);

        ctx.Builder.CreateBr(MergeBB);

        // Emit merge block.
        TheFunction->getBasicBlockList().push_back(MergeBB);
        ctx.Builder.SetInsertPoint(MergeBB);
        return ctx.zero;
    }
    virtual ~ifop() {
        delete cond;
    }
};

class whileop : public oper_t {
    expr_t* cond;
    block ops;

public:
    whileop(expr_t* cond, oper_t* ops): cond(cond), ops(ops) {}
    virtual Value* emit(llvm_ctx& ctx) {
        Function* TheFunction = ctx.Builder.GetInsertBlock()->getParent();
        BasicBlock* CondBB = BasicBlock::Create(ctx.Context, "whilexpr", TheFunction);
        BasicBlock* LoopBB = BasicBlock::Create(ctx.Context, "loop");
        BasicBlock* AfterBB = BasicBlock::Create(ctx.Context, "after");
        ctx.Builder.CreateBr(CondBB);
        ctx.Builder.SetInsertPoint(CondBB);

        Value* CondV = cond->emit(ctx);
        if (CondV == 0)
            return 0;
        // Convert condition to a bool by comparing equal to 0.
        CondV = ctx.Builder.CreateICmpNE(CondV, ctx.zero, "whilecond");
        ctx.Builder.CreateCondBr(CondV, LoopBB, AfterBB);

        // Emit merge block.
        TheFunction->getBasicBlockList().push_back(LoopBB);
        ctx.Builder.SetInsertPoint(LoopBB);
        Value* Ops = this->ops.emit(ctx);
        ctx.Builder.CreateBr(CondBB);

        TheFunction->getBasicBlockList().push_back(AfterBB);
        ctx.Builder.SetInsertPoint(AfterBB);
        return Constant::getNullValue(Type::getInt32Ty(ctx.Context));
    }
    virtual ~whileop() {
        delete cond;
    }
};

class exitop : public oper_t {
    virtual Value* emit(llvm_ctx& ctx) {
        return ctx.Builder.CreateCall(ctx.func_exit, ctx.zero);
    }
};

class binary : public expr_t {
    char op;
    expr_t *arg1, *arg2;

public:
    binary(char op, expr_t* arg1, expr_t* arg2): op(op), arg1(arg1), arg2(arg2) {}
    Value* emit(llvm_ctx& ctx) override {
        Value* tmp;
        Value* L = arg1->emit(ctx);
        Value* R = arg2->emit(ctx);
        if (L == 0 || R == 0)
            return 0;

        switch (op) {
        case '+':
            return ctx.Builder.CreateAdd(L, R);
        case '-':
            return ctx.Builder.CreateSub(L, R);
        case '*':
            return ctx.Builder.CreateMul(L, R);
        case '/':
            return ctx.Builder.CreateSDiv(L, R);
        case '<':
            tmp = ctx.Builder.CreateICmpSLT(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));
        case '>':
            tmp = ctx.Builder.CreateICmpSGT(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));
        case 'L':
            tmp = ctx.Builder.CreateICmpSLE(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));
        case 'G':
            tmp = ctx.Builder.CreateICmpSGE(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));
        case 'N':
            tmp = ctx.Builder.CreateICmpNE(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));
        case '=':
            tmp = ctx.Builder.CreateICmpEQ(L, R);
            return ctx.Builder.CreateZExt(tmp, IntegerType::get(ctx.Context, 32));

        default:
            return ErrorV("invalid binary operator ");
        }
    }
    virtual ~binary() {
        delete arg1;
        delete arg2;
    }
};

class assign : public expr_t {
    std::string name;
    Value* varreference;
    expr_t* value;

public:
    assign(const std::string& name, expr_t* value): name(name), varreference(nullptr), value(value) {
        std::map<std::string, Value*>::iterator varrec;
    }

    Value* emit(llvm_ctx& ctx) override {
        auto varrec = ctx.VarDict.find(name);
        if (varrec == ctx.VarDict.end()) {
            ctx.VarDict[name] = varreference = CreateEntryBlockAlloca(ctx.Context, ctx.func_main, name);
        } else {
            varreference = varrec->second;
        }
        Value* result = value->emit(ctx);
        ctx.Builder.CreateStore(result, varreference);
        return result;
    }
    virtual ~assign() {
        delete value;
    }
};

class unary : public expr_t {
    char op;
    expr_t* arg;

public:
    unary(char op, expr_t* arg): op(op), arg(arg) {}
    virtual Value* emit(llvm_ctx& ctx) {
        Value* L = arg->emit(ctx);
        if (L == 0)
            return 0;

        switch (op) {
        case '-':
            return ctx.Builder.CreateNeg(L);
        case '!':
            return ctx.Builder.CreateNot(L);

        default:
            return ErrorV("invalid binary operator");
        }
    }
    virtual ~unary() {
        delete arg;
    }
};

class value : public expr_t {
    std::string text;

public:
    value(const std::string& text): text(text) {}
    virtual Value* emit(llvm_ctx& ctx) {
        return ConstantInt::get(IntegerType::get(ctx.Context, 32), atoi(text.c_str()));
    }
};

class varref : public expr_t {
    std::string name;

public:
    varref(const std::string& name): name(name) {}
    virtual Value* emit(llvm_ctx& ctx) {
        // Look this variable up in the function.
        auto item = ctx.VarDict.find(name);
        if (item != ctx.VarDict.end()) {
            Value* vref = item->second;
            return ctx.Builder.CreateLoad(vref->getType()->getPointerElementType(), vref);
        } else
            return 0;
    }
};

class str : public expr_t {
private:
    Value* strval;

public:
    std::string text;
    str(const std::string& text): text(text) {}
    virtual Value* emit(llvm_ctx& ctx) {
        return ctx.Builder.CreateGlobalStringPtr(text.c_str());
    }
};

class funcall : public expr_t {
    std::string name;
    std::list<expr_t*> args;

public:
    funcall(const std::string& name, const std::list<expr_t*>& args): name(name), args(args) {}

    virtual Value* emit(llvm_ctx& ctx) {
        Value* result = ctx.zero;
        if (!name.compare("input")) {
            if (args.size())
                yyerror((char*)"Input: too many arguments");
            std::vector<Value*> args;
            args.push_back(ctx.format1);
            args.push_back(ctx.int_for_scanf);
            ctx.Builder.CreateCall(ctx.func_scanf, args, "");
            return ctx.Builder.CreateLoad(ctx.int_for_scanf->getType()->getPointerElementType(), ctx.int_for_scanf);
        } else if (!name.compare("echo")) {
            if (!args.size())
                yyerror((char*)"Input: missing arguments");
            for (auto i = args.begin(); i != args.end(); ++i) {
                Value* argument = (*i)->emit(ctx);
                const Type* argtype = argument->getType();
                Value* formatStr = argtype->isIntegerTy() ? ctx.format1 : ctx.format2;
                std::vector<Value*> args;
                args.push_back(formatStr);
                args.push_back(argument);
                ctx.Builder.CreateCall(ctx.func_printf, args);
            }
        } else
            yyerror((char*)"Undefined function");
        return result;
    }
    virtual ~funcall() {
        for (auto i = args.begin(); i != args.end(); i++)
            delete *i;
    }
};
// ----------------------

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
