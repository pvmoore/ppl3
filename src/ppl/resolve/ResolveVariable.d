module ppl.resolve.ResolveVariable;

import ppl.internal;

final class ResolveVariable {
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
    void resolve(Variable n) {

        //if(n.numRefs==0 && module_.canonicalName=="misc::test_constant_folding") {
        //    dd("---------------->", n.line+1, n);
        //
        //    resolver.fold(n);
        //    return;
        //}

        resolver.resolveAlias(n, n.type);

        if(n.type.isUnknown) {

            if(n.isParameter) {
                /// If we are a closure inside a call
                auto call = n.getAncestor!Call;
                if(call && call.isResolved) {

                    auto params = n.parent.as!Parameters;
                    assert(params);

                    auto callIndex = call.indexOf(n);

                    auto ptype = call.target.paramTypes[callIndex];
                    if(ptype.isFunction) {
                        auto idx = params.getIndex(n);
                        assert(idx!=-1);

                        if(idx<ptype.getFunctionType.paramTypes.length) {
                            auto t = ptype.getFunctionType.paramTypes[idx];
                            n.setType(t);
                        }
                    }
                }
            }

            if(n.hasInitialiser) {
                /// Get the type from the initialiser
                if(n.initialiserType().isKnown) {
                    n.setType(n.initialiserType());
                }

            } else {
                /// No initialiser

            }
        }
        if(n.type.isKnown) {
            /// Ensure the function ptr matches the closure type
            if(n.isFunctionPtr && n.hasInitialiser) {
                auto lf = n.getDescendent!LiteralFunction;
                if(lf) {
                    lf.type = n.type;
                }
            }
        }
    }
}