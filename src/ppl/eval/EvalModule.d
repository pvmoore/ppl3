module ppl.eval.EvalModule;

import ppl.internal;

final class EvalModule {
private:
    Module mod;
    EvalBinaryUnary binaryUnary;
public:
    this(ResolveModule resolver) {
        this.mod = resolver.module_;
        this.binaryUnary = new EvalBinaryUnary(resolver);
    }

    void eval(Binary n) {
        binaryUnary.eval(n);
    }
    void eval(Unary n) {
        binaryUnary.eval(n);
    }
}