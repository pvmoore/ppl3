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

            /// Convert to a call to __assert(bool, string, int)
            auto parent = n.parent;
            auto b      = module_.builder(n);

            auto c = b.call("__assert", null);

            /// value
            Expression value;
            if(type.isPtr) {
                value = b.binary(Operator.BOOL_NE, n.expr(), LiteralNull.makeConst(type));
            } else if(type.isBool) {
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
}