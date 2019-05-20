module ppl.resolve.ResolveAssert;

import ppl.internal;

final class ResolveAssert {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Assert n) {

        /// Note: Assert is always unresolved because it needs
        ///       to be converted into a call to __assert

        if(!n.isResolved) {

            /// This should be imported implicitly
            assert(findImportByCanonicalName("core::assert", n));

            /// Wait until we know what the type is
            Type type = n.expr().getType();
            if(type.isUnknown) return;

            auto ctc = n.expr().as!CompileTimeConstant;
            if(ctc) {
                if(ctc.isTrue()) {
                    /// Just remove the assertion
                    resolver.fold(n);
                } else {
                    /// Assertion failed. Call __assert with false
                    rewriteAsCallToAssert(n, type);
                }
                return;

            } else {
                if(n.expr().isConst) {
                    /// Wait for it to be resolved to a CompileTimeConstant

                    //dd("waiting for", module_.canonicalName, n.line+1, n.expr());

                    // todo - we need something better than isConst. Maybe isCTConst?
                    //return;
                }
            }

            rewriteAsCallToAssert(n, type);
        }
    }
private:
    /// Rewrite to:
    ///
    /// call __assert
    ///     bool    (assert result)
    ///     string  (module name)
    ///     int     (line number)
    void rewriteAsCallToAssert(Assert n, Type exprType) {
        auto parent = n.parent;
        auto b      = module_.builder(n);

        auto c = b.call("__assert", null);

        /// value
        Expression value;
        if(exprType.isPtr) {
            value = b.binary(Operator.BOOL_NE, n.expr(), LiteralNull.makeConst(exprType));
        } else if(exprType.isBool) {
            value = n.expr();
        } else {
            value = b.binary(Operator.BOOL_NE, n.expr(), LiteralNumber.makeConst(0));
        }
        c.add(value);

        /// string
        //c.add(b.string_(module_.moduleNameLiteral));
        c.add(module_.moduleNameLiteral.copy());

        /// line
        c.add(LiteralNumber.makeConst(n.line+1, TYPE_INT));

        resolver.fold(n, c);
    }
}