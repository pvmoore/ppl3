module ppl.resolve.misc.FoldUnreferenced;

import ppl.internal;

final class FoldUnreferenced {
private:
    Module module_;
    ResolveModule resolveModule;
public:
    this(Module module_, ResolveModule resolveModule) {
        this.module_       = module_;
        this.resolveModule = resolveModule;
    }

    /// Attempt to remove any unreferenced nodes.
    /// Called after each resolution phase.
    void process() {

        /// Process functions and structs
        foreach(f; module_.getFunctions()) {
            if(f.hasBody()) {
                processNode(f.getBody());
            }
        }
        foreach(s; module_.getStructs()) {
            processStruct(s);
        }

        /// Remove any Variable or Function that is not referenced
        if(allTargetsResolved(module_)) {
            foreach(v; module_.getVariables()) checkVariable(v);
            foreach(f; module_.getFunctions()) checkFunction(f);
        }
    }
    void fold(ASTNode replaceMe, ASTNode withMe, bool dereference = true) {

        auto p = replaceMe.parent;

        resolveModule.setModified(replaceMe);
        resolveModule.setModified(withMe);

        p.replaceChild(replaceMe, withMe);

        if(dereference) {
            recursiveDereference(replaceMe);
        }
        resolveModule.setModified();

        /// Ensure active roots remain valid
        module_.addActiveRoot(withMe);
    }
    void fold(ASTNode removeMe, bool dereference = true) {
        if(dereference) {
            recursiveDereference(removeMe);
        }
        resolveModule.setModified(removeMe);
        removeMe.detach();
        resolveModule.setModified();
    }
private:
    void processNode(ASTNode scope_) {
        if(scope_.isA!Struct) {
            processStruct(scope_.as!Struct);
        } else if(scope_.isA!Enum) {
            processEnum(scope_.as!Enum);
        } else if(!scope_.isAScope) {
            return;
        }
        /// This is an inner scope

        /// Remove Variable, Function, Call -> All targets must be known
        if(allTargetsResolved(scope_)) {
            scope_.recurse!Variable( (v) {
                checkVariable(v);
            });
            scope_.recurse!Call( (call) {
                checkCall(call);
            });
            scope_.recurse!Function( (f) {
                checkFunction(f);
            });
        }

        /// recurse
        foreach(ch; scope_.children) {
            processNode(ch);
        }
    }
    void processEnum(Enum e) {
        /// Not possible to remove
        if(e.isAtModuleScope() && e.access.isPublic) return;

        auto scope_ = e.getLogicalParent();

        if(scope_.isA!Struct && e.access.isPublic) {
            /// scope
            ///     struct
            ///         pub enum
            ///     node (can access)

            /// Can be accessed by struct parent scope
            scope_ = scope_.getLogicalParent();
        } else {
            /// Must be one of these.

            /// struct (scope_)
            ///     enum (private)
            ///     node (can access)
            /// node (no access)

            ///
            /// scope
            ///     enum
            ///     node (can access)
        }

        bool removable = true;

        scope_.recurse!ASTNode(
            n=>removable && (n !is e) && (!n.parent || n.parent !is e),
            (n) {
                auto type = n.getType;
                if(type.isUnknown) {
                    removable = false;
                } else {
                    auto enum_ = n.getType.getEnum;
                    if(enum_ && enum_.nid==e.nid) {
                        removable = false;
                    }
                }
            }
        );
        if(removable) {
            fold(e);
        }
    }
    void processStruct(Struct s) {
        if(s.isTemplateBlueprint) return;

        /// scope_
        ///     struct
        ///
        auto scope_ = s.getLogicalParent();

        /// If this struct is a private global or inner struct then see if it can be removed
        if(!s.isAtModuleScope() && s.access.isPrivate) {

            bool removable = true;

            scope_.recurse!ASTNode(
                n=>removable && (n !is s),
                (n) {
                    auto type = n.getType;
                    if(type.isUnknown) {
                        removable = false;
                    } else {
                        auto ns = n.getType.getStruct;
                        if(ns && ns !is s) {
                            removable = false;
                        }
                    }
                }
            );
            if(removable) {
                fold(s);
                return;
            }
        }

        /// Remove any Variable or Function that is not referenced within parent scope
        if(allTargetsResolved(scope_)) {
            foreach(v; s.getMemberVariables()) checkVariable(v);
            foreach(v; s.getStaticVariables()) checkVariable(v);

            foreach(f; s.getMemberFunctions()) checkFunction(f);
            foreach(f; s.getStaticFunctions()) checkFunction(f);
        }
        foreach(e; s.getEnums()) processEnum(e);

        /// recurse functions
        foreach(f; s.getMemberFunctions()) {
            if(f.hasBody) {
                processNode(f.getBody());
            }
        }
        foreach(f; s.getStaticFunctions()) {
            if(f.hasBody) {
                processNode(f.getBody());
            }
        }
    }
    bool allTargetsResolved(ASTNode scope_) {
        Target[] targets;
        scope_.collectTargets(targets);
        return targets.all!(it=>it.isResolved);
    }
    void checkVariable(Variable v) {
        /// Must be a local variable or a private global
        if(v.access.isPublic && v.isGlobal) return;
        if(!v.isGlobal && !v.isLocalAlloc) return;

        if(v.numRefs==0) {
            /// If numRefs==0 then remove it
            fold(v);

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
                    fold(v);
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
            fold(f);
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

                    fold(call);

                } else if(body_.numStatements()==1) {
                    if(body_.second().isA!Return) {
                        /// Function only has a single statement which is a return.
                        /// If it returns void or a compile time constant
                        /// then we can fold the call
                        auto ret = body_.second().as!Return;
                        if(ret.hasExpr) {
                            auto ctc = ret.expr().as!CompileTimeConstant;
                            if(ctc) {
                                fold(call, ctc.copy());
                            }
                        } else {
                            fold(call);
                        }
                    }
                }
            }
        }
    }
    void recursiveDereference(ASTNode n) {
        /// dereference
        if(n.isIdentifier) {
            auto t = n.as!Identifier.target;
            t.dereference();
        } else if(n.isCall) {
            auto t = n.as!Call.target;
            t.dereference();
        } else if(n.isLambda) {
            module_.removeLambda(n.as!Lambda);
        }
        foreach(ch; n.children) {
            recursiveDereference(ch);
        }
    }
}
