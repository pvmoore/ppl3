module ppl.resolve.ResolveEnum;

import ppl.internal;

final class ResolveEnum {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Enum n) {

        if(!n.elementType.isKnown) return;

        if(n.elementType.isVoid && n.elementType.isValue) {
            module_.addError(n, "Enum values cannot be void", true);
            return;
        }
        if(n.numChildren==0) {
            module_.addError(n, "Enums cannot be empty", true);
            return;
        }

        setImplicitValues(n);
    }
    void resolve(EnumMemberValue n) {
        if(n.isResolved) {
            if(n.expr.comptime()==CT.YES) {

                auto expr = n.expr();

                if(expr.isA!ExpressionRef) {
                    expr = expr.as!ExpressionRef.reference;
                }
                if(expr.isA!EnumMember) {
                    expr = expr.as!EnumMember.expr();
                }

                if(!expr.isResolved) return;

                auto ctc = expr.as!CompileTimeConstant;

                if(ctc) {
                    resolver.fold(n, ctc.copy());
                }
            }
        }
    }
private:
    void setImplicitValues(Enum n) {

        /// Set any unset values
        int value = 0;

        foreach(em; n.members()) {

            if(em.hasChildren) {
                auto expr = em.expr();

                /// We need this to be resolved or we can't continue
                if(!expr.isResolved) return;

                if(expr.comptime()==CT.UNRESOLVED) return;

                /// Assume it is a LiteralNumber for now
                auto lit = expr.as!LiteralNumber;
                assert(lit);

                value = lit.value.getInt();
            } else {
                /// Add implicit value

                if(!n.elementType.isBasicType || n.elementType.isPtr) {
                    module_.addError(n, "Enum type %s must have explicit initialisers".format(n.elementType), true);
                    return;
                }

                auto lit = LiteralNumber.makeConst(value, n.elementType);
                em.add(lit);

                resolver.setModified(em);
            }

            value++;
        }
    }
}