module ppl.check.ControlFlow;

import ppl.internal;

enum VERBOSE = null; //"test_control_flow";

/**
 *  Control flow analisys.
 *
 *  Follow all paths through a function to check:
 *
 *  - ?
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

    }
}