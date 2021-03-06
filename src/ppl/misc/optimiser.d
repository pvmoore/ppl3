module ppl.misc.optimiser;

import ppl.internal;

final class Optimiser {
private:
    LLVMWrapper llvm;
    LLVMPassManager passManager;
    StopWatch watch;
public:
    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(LLVMWrapper llvm) {
        this.llvm        = llvm;
        this.passManager = llvm.passManager;

        passManager.addPassesO3();
        //passManager.addPassesO0();
    }
    void clearState() {
        watch.reset();
    }
    void optimise(Module m) {
        watch.start();
        passManager.runOnModule(m.llvmValue);
        writeLL(m, "ir_opt/");
        watch.stop();
    }
    void optimiseCombined(Module m) {
        watch.start();
        passManager.runOnModule(m.llvmValue);
        writeLL(m, "");
        watch.stop();
    }
}