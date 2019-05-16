module ppl.resolve.ResolveSelect;

import ppl.internal;

final class ResolveSelect {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(Select n) {
        if(!n.isResolved) {

            assert(n.isExpr);

            Type[] types = n.casesIncludingDefault().map!(it=>it.getType).array;

            if(!types.areKnown) {
                /// Allow cases to resolve if possible
                if(!resolver.isStalemate) return;

                /// Stalemate situation. Choose a type from the clauses that are resolved
                types = types.filter!(it=>it.isKnown).array;
            }

            auto type = getBestFit(types);
            if(type) {
                n.type = type;
            } else {
                // todo - print a more helpful error message
                module_.addError(n, "Select case values do not resolve to a common type", true);
            }
        }
        if(n.isResolved && !n.isSwitch) {
            ///
            /// Convert to a series of if/else
            ///
            auto cases = n.cases();
            auto def   = n.defaultStmts();

            /// Exit if this select is badly formed. This will already be an error
            if(cases.length==0 || def is null) return;

            If first;
            If prev;

            foreach(c; n.cases()) {
                If if_ = makeNode!If(n);
                if(first is null) first = if_;

                if(prev) {
                    /// else
                    auto else_ = Composite.make(n, Composite.Usage.INNER_KEEP);
                    else_.add(if_);
                    prev.add(else_);
                }

                /// No inits
                if_.add(Composite.make(n, Composite.Usage.INLINE_KEEP));

                /// Condition
                if_.add(c.cond());

                /// then
                if_.add(c.stmts());

                prev = if_;
            }
            /// Final else
            assert(first);
            assert(prev);
            prev.add(def);

            resolver.fold(n, first);
            return;
        }
        if(n.isSwitch && n.valueType().isKnown) {
            /// If value type is bool then change it to int
            if(n.valueType.isBool) {

                auto val = n.valueExpr();
                auto as  = makeNode!As(n);

                resolver.fold(val, as);

                as.add(val);
                as.add(TypeExpr.make(TYPE_INT));
                return;
            }
        }
        if(n.isResolved && n.isSwitch && n.valueExpr().isA!LiteralNumber) {
            ///
            /// Try to fold switch select
            ///
            auto val = n.valueExpr().as!LiteralNumber;

            /// Pick the case/default that would be chosen
            /// and replace the select with the contents of that

            void _doFold(Composite stmts) {
                stmts.usage = Composite.Usage.INNER_REMOVABLE;
                resolver.fold(n, stmts);
            }

            foreach(c; n.cases()) {
                foreach(condition; c.conds()) {
                    auto lit = condition.as!LiteralNumber;
                    if(lit) {
                        if(lit.getType.canImplicitlyCastTo(val.getType)) {
                            if(lit.value.getLong()==val.value.getLong()) {
                                _doFold(c.stmts());
                                return;
                            }
                        }
                    } else {
                        /// Wait for case expression to be resolved to a CompileTimeConstant
                        return;
                    }
                }
            }

            /// If we get here then none of the cases matched
            auto else_ = n.defaultStmts();
            _doFold(else_);
            return;
        }
    }
}