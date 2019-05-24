module ppl.resolve.misc.FoldUnreferenced;

import ppl.internal;
///
///
///
///
///
///
///
/// todo - cache targets
///
final class FoldUnreferenced {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(Module module_, ResolveModule resolver) {
        this.module_  = module_;
        this.resolver = resolver;
    }
    void fold(ASTNode node) {

        if(node.isModule) {
            checkModule();
        } else if(node.isLiteralFunction) {
            checkScope(node);
        } else if(node.isComposite) {
            auto c = node.as!Composite;
            if(c.usage==Composite.Usage.INNER_KEEP || c.usage==Composite.Usage.INNER_REMOVABLE) {
                checkScope(node);
            }
        } else if(node.isA!Struct) {
            checkStruct(node.as!Struct);
        }
    }
private:
    //bool allTargetsResolved() {
    //    Target[] targets;
    //    foreach(node; module_.getCopyOfActiveRoots) {
    //        node.collectTargets(targets);
    //    }
    //    return targets.all!(it=>it.isResolved);
    //}
    bool allTargetsResolved(ASTNode scope_) {
        Target[] targets;
        scope_.collectTargets(targets);
        return targets.all!(it=>it.isResolved);
    }
    void checkModule() {
        if(allTargetsResolved(module_)) {
            foreach(v; module_.getVariables()) checkVariable(v);
            foreach(e; module_.getEnums()) checkEnum(e);
            foreach(f; module_.getFunctions()) checkFunction(f);
        }
    }
    /// Struct has members which are visible to other nodes in parent scope:
    ///
    /// Parent
    ///     Struct
    ///         Variable
    ///         Function
    ///     Node (can see members of struct)
    ///
    void checkStruct(Struct s) {
        auto parent = s.getParentIgnoreComposite();

        if(allTargetsResolved(parent)) {
            foreach(v; s.getMemberVariables()) checkVariable(v);
            foreach(v; s.getStaticVariables()) checkVariable(v);

            foreach(e; s.getEnums()) checkEnum(e);

            foreach(f; s.getMemberFunctions()) checkFunction(f);
            foreach(f; s.getStaticFunctions()) checkFunction(f);
        }
    }
    /// Standard inner scope:
    ///
    /// Scope
    ///     Node
    /// Node (Cannot see members of scope)
    void checkScope(ASTNode scope_) {
        assert(!scope_.isA!Module);
        assert(!scope_.isA!Struct);

        if(allTargetsResolved(scope_)) {
            scope_.recurse!Variable( (v) {
                checkVariable(v);
            });
            scope_.recurse!Enum( (e) {
                checkEnum(e);
            });
            scope_.recurse!Call( (call) {
                checkCall(call);
            });
            scope_.recurse!Function( (f) {
                checkFunction(f);
            });
        }
    }
    void checkVariable(Variable v) {
        /// Must be a local variable or a private global
        if(v.access.isPublic && v.isGlobal) return;
        if(!v.isGlobal && !v.isLocalAlloc) return;

        if(v.numRefs==0) {
            /// If numRefs==0 then remove it
            resolver.fold(v);

        } else if(v.numRefs==1) {

            //'b' Variable[refs=1] (type=int) LOCAL PRIVATE
            //    Initialiser var=b, type=int
            //       ASSIGN (type=int)
            //          ID:b (type=int) Target: VAR b int
            //          2 (type=const int)

            /// If the only reference is the initialiser and the
            /// initialiser is a CompileTimeConstant then the Variable can be removed
            if(v.hasInitialiser) {
                auto lit = v.initialiser().getExpr();
                auto ctc = lit.as!CompileTimeConstant;
                if(ctc) {
                    resolver.fold(v);
                }
            }
        }
    }
    void checkFunction(Function f) {
        /// Don't get rid of any constructors
        /// Only look at private functions
        if(f.name=="new") return;
        if(f.access.isPublic) return;

        if(f.numRefs==0) {
            resolver.fold(f);
        } else {

        }
    }
    void checkCall(Call call) {
        assert(call.target.isResolved, "target not resolved: %s %s".format(module_.canonicalName, call));

        if(call.target.isFunction) {
            auto func  = call.target.getFunction;
            auto body_ = func.hasBody() ? func.getBody() : null;
            if(body_) {
                if(body_.isEmpty()) {
                    /// Function has nothing in it so the call can be removed

                    resolver.fold(call);

                } else if(body_.numStatements()==1) {
                    if(body_.second().isA!Return) {
                        /// Function only has a single statement which is a return.
                        /// If it returns void or a compile time constant
                        /// then we can fold the call
                        auto ret = body_.second().as!Return;
                        if(ret.hasExpr) {
                            auto ctc = ret.expr().as!CompileTimeConstant;
                            if(ctc) {
                                resolver.fold(call, ctc.copy());
                            }
                        } else {
                            resolver.fold(call);
                        }
                    }
                }
            }
        }
    }
    void checkEnum(Enum e) {
        /// Only look at private enums
        if(e.access.isPublic) return;

        if(e.numRefs==0) {
            resolver.fold(e);
        } else {
            //bool allKnown;
            //int usages = getNumUsagesInScope(scope_, e, allKnown);
            //if(allKnown) {
            //    // todo
            //    dd("=====>", module_.canonicalName, e.line+1, e, "usages =", usages);
            //}
        }
    }
    int getNumUsagesInScope(ASTNode scope_, Enum e, ref bool allKnown) {
        int count = 0;
        allKnown = true;
        scope_.recurse!Variable( (v) {
            auto type = v.getType;
            if(type.isKnown) {
                if(type.isEnum) count++;
            } else {
                allKnown = false;
            }
        });
        if(allKnown) {
            //scope_.recurse!Dot( (d) {
            //
            //});
        }
        return count;
    }
}
