module ppl.check.ControlFlow;

import ppl.internal;

enum VERBOSE = null; //"test_control_flow";

/**
 *  Control flow analisys.
 *
 *  Follow all paths through a function to check:
 *
 *  - If the function returns non-null then there should be a return at the end
 *
 */
final class ControlFlow {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    void check(LiteralFunction f) {
        checkReturn(f);
    }
private:
    /**
     * If this function returns non-void, check the last node to see if it is a return.
     * If not then assume it is wrong.
     */
    void checkReturn(LiteralFunction f) {

        auto type = f.type.getFunctionType();
        assert(type);

        if(type.returnType().isVoid) return;

        // Look at the last node

        auto last = f.last();
        while(last !is null && last.isEthereal()) {
            last = last.last();
        }

        if(last !is null && !last.isReturn) {
            module_.addError(f, "Not all paths return a value", true);
        }
    }
}