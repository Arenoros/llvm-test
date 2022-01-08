#include <llvm/IR/IRBuilder.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/JITSymbol.h>
#include <llvm/ExecutionEngine/SectionMemoryManager.h>
#include <llvm/ExecutionEngine/Orc/CompileUtils.h>
#include <llvm/ExecutionEngine/Orc/IRCompileLayer.h>
#include <llvm/ExecutionEngine/Orc/RTDyldObjectLinkingLayer.h>
#include <llvm/ExecutionEngine/Orc/LLJIT.h>
#include <llvm/ExecutionEngine/Orc/ThreadSafeModule.h>\
#include <memory>
#include <vector>

using namespace llvm;
using namespace std;

int main() {
    InitializeNativeTarget();
    InitializeNativeTargetAsmPrinter();
    InitializeNativeTargetAsmParser();
    auto Ctx = orc::ThreadSafeContext(std::make_unique<LLVMContext>());
    // Try to detect the host arch and construct an LLJIT instance.

    orc::ThreadSafeModule jit_module(std::make_unique<Module>("Test JIT Compiler", *Ctx.getContext()), Ctx);
    // (double, double, double)
    std::vector<Type*> param_type(3, Type::getDoubleTy(*Ctx.getContext()));
    // double (*)(double, double, double)
    FunctionType* prototype = FunctionType::get(Type::getDoubleTy(*Ctx.getContext()), param_type, false);

    Function* func = Function::Create(prototype,
                                      Function::ExternalLinkage,
                                      "test_func",
                                      jit_module.getModuleUnlocked());
    BasicBlock* body = BasicBlock::Create(*Ctx.getContext(), "body", func);
    IRBuilder<> builder(*Ctx.getContext());
    builder.SetInsertPoint(body);

    std::vector<Value*> args;
    for (auto& arg: func->args())
        args.push_back(&arg);

    Value* temp = builder.CreateFMul(args[0], args[1], "temp");
    Value* ret = builder.CreateFMul(args[2], temp, "result");
    builder.CreateRet(ret);

    auto JIT = orc::LLJITBuilder().create();

    // If we could not construct an instance, return an error.
    if (!JIT)
        return 1;  // JIT.takeError();

    // Add the module.
    auto Err = (*JIT)->addIRModule(cloneToNewContext(jit_module));
    if (Err)
        return 2;  // Err;

    // Look up the JIT'd code entry point.
    auto EntrySym = (*JIT)->lookup("test_func");
    if (!EntrySym)
        return 3;  // EntrySym.takeError();

    // Cast the entry point address to a function pointer.
    auto* Entry = reinterpret_cast<double (*)(double, double, double)>((*EntrySym).getAddress());

    // Call into JIT'd code.
    double res = Entry(2, 3, 4);
    return 0;
}