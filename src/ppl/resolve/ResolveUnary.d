module ppl.resolve.ResolveUnary;

import ppl.internal;

final class ResolveUnary {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Unary n) {
        if(n.expr.getType.isStruct && n.op.isOverloadable) {
            /// Look for an operator overload
            string name = "operator" ~ n.op.value;

            /// Rewrite to operator overload:
            /// Unary
            ///     expr struct
            /// Dot
            ///     AddressOf
            ///         expr struct
            ///     Call
            ///
            auto b = module_.builder(n);

            auto left  = n.expr.getType.isValue ? b.addressOf(n.expr) : n.expr;
            auto right = b.call(name, null);

            auto dot = b.dot(left, right);

            resolver.fold(n, dot);
            return;
        }
        /// If expression is a const literal number then apply the
        /// operator and replace Unary with the result
        if(n.isResolved && n.comptime()==CT.YES) {
            auto lit = n.expr().as!LiteralNumber;
            if(lit) {
                bool ok = lit.value.applyUnary(n.op);
                if(ok) {
                    lit.str = lit.value.getString();

                    resolver.fold(n, lit);
                    return;
                } else {
                    module_.addError(n, "(%s %s) is not supported".format(n.op.value, n.expr.getType), true);
                }
            }
        }
    }
}
