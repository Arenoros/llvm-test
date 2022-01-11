#include <iostream>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/ExecutionEngine/ExecutionEngine.h>
#include <llvm/ExecutionEngine/JITSymbol.h>
#include <llvm/ExecutionEngine/SectionMemoryManager.h>
#include <llvm/ExecutionEngine/Orc/CompileUtils.h>
#include <llvm/ExecutionEngine/Orc/IRCompileLayer.h>
#include <llvm/ExecutionEngine/Orc/RTDyldObjectLinkingLayer.h>
#include <llvm/ExecutionEngine/Orc/LLJIT.h>
#include <llvm/ExecutionEngine/Orc/ThreadSafeModule.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Analysis/CGSCCPassManager.h>
#include <llvm/Analysis/LoopAnalysisManager.h>
#include <llvm/Analysis/AliasAnalysis.h>
#include <llvm/Transforms/Scalar.h>
#include <llvm/Transforms/Scalar/GVN.h>
#include <llvm/Transforms/InstCombine/InstCombine.h>
#include <memory>
#include <vector>
#include <string>
#include <strstream>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/IR/LegacyPassManager.h>
#include <llvm/Transforms/Scalar.h>

using namespace llvm;
using namespace std;

void Optimization(Module* modl) {
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
namespace test {
    using namespace llvm;
    using namespace llvm::orc;
    class KaleidoscopeJIT {
    private:
        std::unique_ptr<ExecutionSession> ES;

        DataLayout DL;
        MangleAndInterner Mangle;

        RTDyldObjectLinkingLayer ObjectLayer;
        IRCompileLayer CompileLayer;
        IRTransformLayer OptimizeLayer;

        JITDylib& MainJD;

    public:
        KaleidoscopeJIT(std::unique_ptr<ExecutionSession> ES, JITTargetMachineBuilder JTMB, DataLayout DL)
            : ES(std::move(ES)), DL(std::move(DL)), Mangle(*this->ES, this->DL),
              ObjectLayer(*this->ES, []() { return std::make_unique<SectionMemoryManager>(); }),
              CompileLayer(*this->ES, ObjectLayer, std::make_unique<ConcurrentIRCompiler>(std::move(JTMB))),
              OptimizeLayer(*this->ES, CompileLayer, optimizeModule), MainJD(this->ES->createBareJITDylib("<main>")) {
            MainJD.addGenerator(cantFail(DynamicLibrarySearchGenerator::GetForCurrentProcess(DL.getGlobalPrefix())));
        }

        ~KaleidoscopeJIT() {
            if (auto Err = ES->endSession())
                ES->reportError(std::move(Err));
        }

        static Expected<std::unique_ptr<KaleidoscopeJIT>> Create() {
            auto EPC = SelfExecutorProcessControl::Create();
            if (!EPC)
                return EPC.takeError();

            auto ES = std::make_unique<ExecutionSession>(std::move(*EPC));

            JITTargetMachineBuilder JTMB(ES->getExecutorProcessControl().getTargetTriple());

            auto DL = JTMB.getDefaultDataLayoutForTarget();
            if (!DL)
                return DL.takeError();

            return std::make_unique<KaleidoscopeJIT>(std::move(ES), std::move(JTMB), std::move(*DL));
        }

        const DataLayout& getDataLayout() const {
            return DL;
        }

        JITDylib& getMainJITDylib() {
            return MainJD;
        }

        Error addModule(ThreadSafeModule TSM, ResourceTrackerSP RT = nullptr) {
            if (!RT)
                RT = MainJD.getDefaultResourceTracker();

            return OptimizeLayer.add(RT, std::move(TSM));
        }

        Expected<JITEvaluatedSymbol> lookup(StringRef Name) {
            return ES->lookup({&MainJD}, Mangle(Name.str()));
        }

    private:
        static Expected<ThreadSafeModule> optimizeModule(ThreadSafeModule TSM, const MaterializationResponsibility& R) {
            TSM.withModuleDo([](Module& M) {
                // Create a function pass manager.
                auto FPM = std::make_unique<legacy::FunctionPassManager>(&M);

                // Add some optimizations.
                FPM->add(createInstructionCombiningPass());
                FPM->add(createReassociatePass());
                FPM->add(createGVNPass());
                FPM->add(createCFGSimplificationPass());
                FPM->doInitialization();

                // Run the optimizations over all functions in the module being added to
                // the JIT.
                for (auto& F: M)
                    FPM->run(F);
            });

            return std::move(TSM);
        }
    };
}  // namespace test

#ifdef _WIN32
#    define DLLEXPORT __declspec(dllexport)
#else
#    define DLLEXPORT
#endif

/// putchard - putchar that takes a double and returns 0.
extern "C" DLLEXPORT double add(double a, double b) {
    return a + b;
}

Function* reg_function(llvm::Module& mod) {
    // (double, double, double)
    std::vector<Type*> param_type(2, Type::getDoubleTy(mod.getContext()));
    // double (*)(double, double, double)
    FunctionType* prototype = FunctionType::get(Type::getDoubleTy(mod.getContext()), param_type, false);

    Function* func = Function::Create(prototype, Function::ExternalLinkage, llvm::Twine("add"), mod);
    func->setCallingConv(llvm::CallingConv::C);
    return func;
}

int main() {
    InitializeNativeTarget();
    InitializeNativeTargetAsmPrinter();
    InitializeNativeTargetAsmParser();
    ExitOnError ExitOnErr;
    auto JIT = ExitOnErr(orc::LLJITBuilder().setNumCompileThreads(4).create());
    // If we could not construct an instance, return an error.
    auto& ES = JIT->getExecutionSession();
    orc::MangleAndInterner Mangle(ES, JIT->getDataLayout());
    orc::SymbolMap AllowList;
    //// Register every symbol that can be accessed from the JIT'ed code.
    AllowList[Mangle("add")] = JITEvaluatedSymbol(pointerToJITTargetAddress(&add), JITSymbolFlags());

    orc::RTDyldObjectLinkingLayer ObjectLayer(ES, []() { return std::make_unique<SectionMemoryManager>(); });
    auto& MainJD = ES.createBareJITDylib("_main1");

    MainJD.define(orc::absoluteSymbols(AllowList));

    MainJD.addGenerator(
        cantFail(llvm::orc::DynamicLibrarySearchGenerator::GetForCurrentProcess(JIT->getDataLayout().getGlobalPrefix(),
                                                                                [&](const orc::SymbolStringPtr& S) {
                                                                                    return AllowList.count(S);
                                                                                })));

    // auto TheJIT = ExitOnErr(test::KaleidoscopeJIT::Create());
    auto Ctx = orc::ThreadSafeContext(std::make_unique<LLVMContext>());
    // Try to detect the host arch and construct an LLJIT instance.

    orc::ThreadSafeModule jit_module(std::make_unique<Module>("Test JIT Compiler", *Ctx.getContext()), Ctx);
    jit_module.getModuleUnlocked()->setDataLayout(JIT->getDataLayout());

    auto add_fn = reg_function(*jit_module.getModuleUnlocked());

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
    // llvm::ExecutionEngine::addGlobalMapping()

    std::vector<Value*> args;
    for (auto& arg: func->args())
        args.push_back(&arg);

    Value* temp = builder.CreateFMul(args[0], args[1], "temp");
    std::vector<Value*> add_args;
    add_args.push_back(temp);
    add_args.push_back(args[2]);
    //CallInst* add_call = builder.CreateCall(add_fn, add_args);
    //  auto rv = add_call->getReturnedArgOperand();
    Value* ret = builder.CreateFMul(args[2], temp, "result");

    builder.CreateRet(ret);

    // llvm::GlobalVariable* g = new llvm::GlobalVariable(*jit_module.getModuleUnlocked(),
    //                                                    arr_ty,
    //                                                    true,
    //                                                    llvm::GlobalValue::LinkageTypes::ExternalLinkage,
    //                                                    nullptr,
    //                                                    "c_call");

    printf("Before Optimization:\n");
    jit_module.getModuleUnlocked()->print(llvm::errs(), nullptr);
    // jit_module.getModuleUnlocked()->dump();

    // Optimization(jit_module.getModuleUnlocked());

    /*printf("After Optimization:\n");
    jit_module.getModuleUnlocked()->dump();*/

    /*ExitOnErr(TheJIT->addModule(cloneToNewContext(jit_module)));

    auto EntrySym = ExitOnErr(TheJIT->lookup("test_func"));
    auto* Entry = reinterpret_cast<double (*)(double, double, double)>(EntrySym.getAddress());
    double res = Entry(2, 3, 4);*/

    // Add the module.
    ExitOnErr(JIT->addIRModule(cloneToNewContext(jit_module)));

    auto EntrySym = ExitOnErr(JIT->lookup("test_func"));

    // auto EntrySym1 = ExitOnErr(JIT->lookup("add"));
    //  Cast the entry point address to a function pointer.
    auto* Entry = reinterpret_cast<double (*)(double, double, double)>(EntrySym.getAddress());

    // Call into JIT'd code.
    double res = Entry(2, 3, 4);
    return 0;
}