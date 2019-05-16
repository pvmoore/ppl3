module ppl.resolve.ResolveIf;

import ppl.internal;

final class ResolveIf {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(If n) {
        if(!n.isResolved) {

            if(!n.isExpr) {
                n.type = TYPE_VOID;
                return;
            }
            if(!n.hasThen) {
                n.type = TYPE_VOID;
                return;
            }

            auto thenType = n.thenType();
            Type elseType = n.hasElse ? n.elseType() : TYPE_UNKNOWN;

            if(thenType.isUnknown) {
                return;
            }

            if(n.hasElse) {
                if(elseType.isUnknown) return;

                auto t = getBestFit(thenType, elseType);
                if(!t) {
                    module_.addError(n, "If result types %s and %s are incompatible".format(thenType, elseType), true);
                }

                n.type = t;

            } else {
                n.type = thenType;
            }
        }
        /// Try to fold
        if(n.isResolved && n.condition().isResolved && n.condition().isA!CompileTimeConstant) {

            auto cond = n.condition();
            auto cct  = cond.as!CompileTimeConstant;
            auto val  = cct.isTrue();

            /// Extract the init expressions and mark them as an inline scope
            auto inits = n.initExprs();
            inits.usage = Composite.Usage.INLINE_REMOVABLE;

            /// Put an empty init expression Composite in it's place so nothing breaks
            auto empty = Composite.make(n, Composite.Usage.INLINE_REMOVABLE);
            resolver.fold(n.initExprs(), empty, false);

            if(val) {
                /// Replace the IF with the THEN block
                auto then = n.thenStmt();
                then.usage = Composite.Usage.INNER_REMOVABLE;

                resolver.fold(n, then);

                /// Add the init expressions back at the front
                then.addToFront(inits);

            } else if(n.hasElse) {
                /// Replace IF with ELSE block
                auto else_ = n.elseStmt();
                else_.usage = Composite.Usage.INNER_REMOVABLE;

                resolver.fold(n, else_);

                /// Add the init expressions back at the front
                else_.addToFront(inits);

            } else {
                /// Remove the IF completely
                resolver.fold(n);
                resolver.fold(inits);
            }

            return;
        }
    }
}