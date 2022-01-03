#define _CRT_SECURE_NO_WARNINGS
#include <fstream>
#include <llvm/IR/Module.h>
#include <llvm/Support/TargetSelect.h>
#include "llvm/ADT/StringRef.h"
#include "llvm/ExecutionEngine/JITSymbol.h"
#include "llvm/ExecutionEngine/Orc/CompileUtils.h"
#include "llvm/ExecutionEngine/Orc/Core.h"
#include "llvm/ExecutionEngine/Orc/ExecutionUtils.h"
#include "llvm/ExecutionEngine/Orc/IRCompileLayer.h"
#include "llvm/ExecutionEngine/Orc/JITTargetMachineBuilder.h"
#include "llvm/ExecutionEngine/Orc/RTDyldObjectLinkingLayer.h"
#include "llvm/ExecutionEngine/SectionMemoryManager.h"
#include <llvm/Analysis/LoopAnalysisManager.h>
#include <llvm/Analysis/CGSCCPassManager.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Analysis/AliasAnalysis.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/Support/Host.h>
#include <llvm/Support/TargetRegistry.h>
#include <llvm/ExecutionEngine/Orc/LLJIT.h>
#include "jit.h"
#include "gram.h"

int main1(int argc, char* argv[]) {
    yyscan_t scanner;
    yylex_init(&scanner); /*
     std::ifstream code("test1.ls");*/
    FILE* fin = fopen("test1.sl", "r");
    yyset_in(fin, scanner);
    // yy_scan_string("2323+23\n", scanner);
    oper_t* block;
    int rv = yyparse(scanner, &block);
    // block->print(0);
    delete block;
    yylex_destroy(scanner);
    return 0;
}

void Optimization(std::unique_ptr<Module>& modl) {
    LoopAnalysisManager LAM;
    FunctionAnalysisManager FAM;
    CGSCCAnalysisManager CGAM;
    ModuleAnalysisManager MAM;
    PassBuilder PB;
    FAM.registerPass([&] { return PB.buildDefaultAAPipeline(); });
    PB.registerModuleAnalyses(MAM);
    PB.registerCGSCCAnalyses(CGAM);
    PB.registerFunctionAnalyses(FAM);
    PB.registerLoopAnalyses(LAM);
    PB.crossRegisterProxies(LAM, FAM, CGAM, MAM);
    ModulePassManager MPM = PB.buildPerModuleDefaultPipeline(PassBuilder::OptimizationLevel::O2);

    // Optimize the IR!
    MPM.run(*modl, MAM);
}

int main() {
    using namespace llvm;
    // InitializeNativeTarget();
    InitializeAllTargetInfos();
    InitializeAllTargets();
    InitializeAllTargetMCs();
    InitializeAllAsmParsers();
    InitializeAllAsmPrinters();

    auto Context = std::make_unique<LLVMContext>();
    IRBuilder<> Builder(*Context);
    auto TheModule = std::make_unique<Module>("jsk jit", *Context);  //    new llvm::Module("jsk jit", Context);

    auto TargetTriple = sys::getDefaultTargetTriple();
    TheModule->setTargetTriple(TargetTriple);
    std::string Error;
    auto Target = TargetRegistry::lookupTarget(TargetTriple, Error);

    // Print an error and exit if we couldn't find the requested target.
    // This generally occurs if we've forgotten to initialise the
    // TargetRegistry or we have a bogus target triple.
    if (!Target) {
        errs() << Error;
        return 1;
    }

    auto CPU = "generic";
    auto Features = "";

    TargetOptions opt;
    auto RM = Optional<Reloc::Model>();
    auto TheTargetMachine = Target->createTargetMachine(TargetTriple, CPU, Features, opt, RM);
    TheModule->setDataLayout(TheTargetMachine->createDataLayout());

    Type* voidType = Type::getVoidTy(*Context);
    auto main = TheModule->getOrInsertFunction("main", voidType);
    Function* func_main = cast<Function>(main.getCallee());
    func_main->setCallingConv(CallingConv::C);
    BasicBlock* block = BasicBlock::Create(*Context, "code", func_main);
    Builder.SetInsertPoint(block);
    llvm_ctx ctx(*TheModule, Builder, func_main);

    yyscan_t scanner;
    yylex_init(&scanner);
    FILE* fin = fopen("test1.sl", "r");
    yyset_in(fin, scanner);
    oper_t* ast;
    int rv = yyparse(scanner, &ast);
    ast->emit(ctx);
    Builder.CreateRetVoid();

    Optimization(TheModule);
    TheModule->dump();

    /* Not work
    auto jit = orc::LLJITBuilder().create();
    if (!jit) {
        jit.takeError();
        return 1;
    }
    auto& jit_t = jit.get();
    auto Err = jit_t->addIRModule(orc::ThreadSafeModule(std::move(TheModule), std::move(Context)));
    if (Err) {
        return 2;
    }
    auto sym = jit_t->lookup("main");
    if (!sym) {
        auto err = sym.takeError();
        return 3;
    }
    auto* entry = (void (*)())sym->getAddress();
    entry();
    */

    std::error_code ErrStr;
    raw_fd_ostream bitcode("a.out.bc", ErrStr);
    
    WriteBitcodeToFile(*TheModule, bitcode);
    bitcode.close();
    yylex_destroy(scanner);
    delete ast;
}

void yyerror(char const* msg) {
    printf("%s", msg);
}

Value* ErrorV(const char* Str) {
    std::cerr << Str << std::endl;
    return 0;
}

Function* declare_printf(Module* mod) {
    std::vector<Type*> printf_args;
    PointerType* FormatString = PointerType::get(IntegerType::get(mod->getContext(), 8), 0);
    printf_args.push_back(FormatString);

    FunctionType* Printf_definition = FunctionType::get(
        /* result */ Type::getVoidTy(mod->getContext()),
        /* params */ printf_args,
        /* Var args */ true);
    Function* func_printf = Function::Create(Printf_definition, GlobalValue::ExternalLinkage, "printf", mod);
    func_printf->setCallingConv(CallingConv::C);
    return func_printf;
}

Function* declare_scanf(Module* mod) {
    std::vector<Type*> scanf_args;
    PointerType* FormatString = PointerType::get(IntegerType::get(mod->getContext(), 8), 0);
    scanf_args.push_back(FormatString);
    FunctionType* Scanf_definition = FunctionType::get(
        /* result */ Type::getVoidTy(mod->getContext()),
        /* params */ scanf_args,
        /* Var args */ true);
    Function* func_scanf = Function::Create(Scanf_definition, GlobalValue::ExternalLinkage, "scanf", mod);
    func_scanf->setCallingConv(CallingConv::C);
    return func_scanf;
}

Function* declare_exit(Module* mod) {
    std::vector<Type*> exit_args;
    IntegerType* exit_reason = IntegerType::get(mod->getContext(), 32);
    exit_args.push_back(exit_reason);
    FunctionType* exit_definition = FunctionType::get(
        /* result */ Type::getVoidTy(mod->getContext()),
        /* params */ exit_args,
        /* Var args */ false);
    Function* func_exit = Function::Create(exit_definition, GlobalValue::ExternalLinkage, "exit", mod);
    func_exit->setCallingConv(CallingConv::C);
    return func_exit;
}

AllocaInst* CreateEntryBlockAlloca(LLVMContext& ctx, Function* TheFunction, const std::string& VarName) {
    IRBuilder<> TmpB(&TheFunction->getEntryBlock(), TheFunction->getEntryBlock().begin());
    return TmpB.CreateAlloca(IntegerType::get(ctx, 32), 0, VarName.c_str());
}

void yyerror(YYLTYPE* yyllocp, yyscan_t, oper_t**, const char* msg) {
    fprintf(stderr, "[%d:%d]: %s\n", yyllocp->last_line, yyllocp->last_column, msg);
}
