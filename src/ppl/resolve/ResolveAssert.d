module ppl.resolve.ResolveAssert;

import ppl.internal;

final class ResolveAssert {
private:
    Module module_;
    ResolveModule resolver;
    FoldUnreferenced foldUnreferenced;
public:
    this(ResolveModule resolver) {
        this.resolver         = resolver;
        this.module_          = resolver.module_;
        this.foldUnreferenced = resolver.foldUnreferenced;
    }
    void resolve(Assert n) {
        /// Note: Assert is always unresolved because it needs
        ///       to be converted into a call to __assert

        /// This should be imported implicitly
        assert(findImportByCanonicalName("core::assert", n));

        /// Wait until we know what the type is
        Type type = n.expr().getType();
        if(type.isUnknown) return;

        if(n.expr().comptime()==CT.UNRESOLVED) {
            /// Wait for it to be resolved one way or the other
            return;
        }
        if(n.expr().comptime()==CT.YES) {

            auto ctc = n.expr().as!CompileTimeConstant;
            if(ctc) {
                if(ctc.isTrue()) {
                    /// Just remove the assertion
                    foldUnreferenced.fold(n);
                } else {
                    /// Assertion failed. Call __assert with false
                    rewriteAsCallToAssert(n, type);
                }
                return;
            } else {

                if(resolver.isStalemate) {
                    module_.addError(n, "Could not resolve comptime assert", true);
                }

                /// Wait for expr to resolve
                return;
            }
        }

        rewriteAsCallToAssert(n, type);
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

        foldUnreferenced.fold(n, c);
    }
}