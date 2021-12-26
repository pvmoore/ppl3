module ppl.eval.FoldUnreferenced;

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
    void processModule() {
        /// Remove any Variable or Function that is not referenced
        if(allTargetsResolved(module_)) {
            /// All global variables are private so potentially foldable
            foreach(v; module_.getVariables()) {
                tryToFold(v);
            }
            foreach(f; module_.getFunctions()) {
                /// Don't try to fold public global functions or the module constructor
                if(f.name!="new") {
                    tryToFold(f);
                }
            }
        }

        /// Recurse all function bodies
        foreach(f; module_.getFunctions()) {
            if(f.hasBody()) {
                processInnerScope(f.getBody());
            }
        }

        /// Try to fold structs
        foreach(s; module_.getStructsAndClasses()) {
            processStruct(s);
        }
        /// Try to fold private enums
        foreach(e; module_.getEnums()) {
            if(e.access.isPrivate) {
                processEnum(e);
            }
        }
    }
    /// Called from ResolveXXX classes to fold a node
    void fold(ASTNode replaceMe, ASTNode withMe, bool dereference = true) {
        auto p = replaceMe.parent;

        resolveModule.setModified(replaceMe);
        resolveModule.setModified(withMe);

        p.replaceChild(replaceMe, withMe);

        if(dereference) {
            recursiveDereference(replaceMe, module_);
        }
    }
    /// Called from ResolveXXX classes to fold a node
    void fold(ASTNode removeMe, bool dereference = true) {

        if(dereference) {
            recursiveDereference(removeMe, module_);
        }
        resolveModule.setModified(removeMe);
        removeMe.detach();
    }
    /// Find outer-most scope of visibility
    static ASTNode findAccessScope(ASTNode node) {
        assert(node.isA!Struct || node.isA!Enum);

        ASTNode scope_ = node.getLogicalParent;
        if(getAccess(node).isPrivate) return scope_;

        if(scope_.isA!Struct && scope_.as!Struct.access.isPublic) {
            return findAccessScope(scope_);
        }
        return scope_;
    }
    static bool typeHasReferencesInScope(ASTNode node, ASTNode scope_) {
        assert(node.isA!Struct || node.isA!Enum);

        bool referenced = false;
        bool isStruct   = node.isA!Struct;

        scope_.recurse!ASTNode(
            n => !referenced &&
                (n !is node) &&
                (n !is scope_) &&
                (n.id != NodeID.IMPORT) &&
                (n.parent.id != NodeID.IMPORT) &&
                (n.parent.id != NodeID.ENUM),
            (n) {
                auto type = n.getType;
                if(type.isUnknown) {
                    /// Assume it could be referenced
                   referenced = true;
                } else {
                    auto t = isStruct ? n.getType.getStruct : n.getType.getEnum;
                    if(t && t.nid==node.nid) {
                        /// It's definitely referenced
                        referenced = true;
                    }
                }
            }
        );
        return referenced;
    }
    static void recursiveDereference(ASTNode n, Module m) {
        /// dereference
        if(n.isIdentifier) {
            auto t = n.getIdentifier().target;
            t.dereference();
        } else if(n.isCall) {
            auto t = n.getCall().target;
            t.dereference();
        } else if(n.isLambda) {
            m.removeLambda(n.as!Lambda);
        }

        foreach(ch; n.children) {
            recursiveDereference(ch, m);
        }
    }
private:
    static bool allTargetsResolved(ASTNode scope_) {
        Target[] targets;
        scope_.collectTargets(targets);
        return targets.all!(it=>it.isResolved);
    }
    /// Look at a scope with a view to folding nodes within it
    void processInnerScope(ASTNode scope_) {

        if(scope_.isA!Struct) {
            processStruct(scope_.as!Struct);
            return;
        } else if(scope_.isA!Enum) {
            processEnum(scope_.as!Enum);
            return;
        } else if(!scope_.isAScope) {
            return;
        }

        /// This is an inner scope

        assert(scope_.isLiteralFunction || (scope_.isComposite && scope_.as!Composite.isInner));

        /// Remove Variable, Function, Call -> All targets must be known
        if(allTargetsResolved(scope_)) {

            scope_.recurse!Variable( (v) {
                if(v.isLocalAlloc) {
                    tryToFold(v);
                }
            });
            scope_.recurse!Call( (call)  {
                tryToFold(call);
            });
            scope_.recurse!Function( (f) {
                tryToFold(f);
            });
        }

        /// recurse
        foreach(ch; scope_.children) {
            processInnerScope(ch);
        }
    }
    void processStruct(Struct struct_) {
        if(struct_.isTemplateBlueprint) return;

        auto externallyVisible = struct_.isVisibleToOtherModules();
        auto scope_            = findAccessScope(struct_);

        if(externallyVisible==false) {

            /// If we find no references in this module, remove it
            if(!typeHasReferencesInScope(struct_, scope_)) {
                fold(struct_);
                return;
            }

            /// NOTE: We can't remove any struct member variables because that
            /// would affect indexing eg. str[1].var will be broken if the variable index changes.
            /// Static member variables should be ok to remove if possible.

            /// Try to fold public struct Variables and Functions
            /// (The access scope is the same as for the struct)
            if(allTargetsResolved(scope_)) {
                // foreach(v; struct_.getMemberVariables()) {
                //     tryToFold(v);
                // }
                foreach(f; struct_.getMemberFunctions()) {
                    tryToFold(f);
                }
                foreach(v; struct_.getStaticVariables()) {
                    tryToFold(v);
                }
                foreach(f; struct_.getStaticFunctions()) {
                    tryToFold(f);
                }
            }
        }

        /// Recurse struct functions
        /// Recurse all function bodies
        foreach(f; struct_.getMemberFunctions()) {
            if(f.hasBody()) {
                processInnerScope(f.getBody());
            }
        }
        foreach(f; struct_.getStaticFunctions()) {
            if(f.hasBody()) {
                processInnerScope(f.getBody());
            }
        }
        /// Try to fold inner structs
        foreach(s; struct_.getStructs()) {
            processStruct(s);
        }
        /// Try to fold inner enums
        foreach(e; struct_.getEnums()) {
            processEnum(e);
        }

        /// Try to fold private Variables and Functions
        /// (The access scope is the struct itself)

        /// Note: This is no longer true since private methods and vars are now
        ///       accessible from within the same module

        //if(allTargetsResolved(struct_)) {
            // foreach(v; struct_.getMemberVariables()) {
            //     if(v.access.isPrivate) {
            //         tryToFold(v);
            //     }
            // }
        //     foreach(f; struct_.getMemberFunctions()) {
        //         if(f.access.isPrivate) {
        //             tryToFold(f);
        //         }
        //     }
        //     foreach(v; struct_.getStaticVariables()) {
        //         if(v.access.isPrivate) {
        //             tryToFold(v);
        //         }
        //     }
        //     foreach(f; struct_.getStaticFunctions()) {
        //         if(f.access.isPrivate) {
        //             tryToFold(f);
        //         }
        //     }
        // }
    }
    void processEnum(Enum enum_) {
        auto externallyVisible = enum_.isVisibleToOtherModules();
        auto scope_            = findAccessScope(enum_);

        if(externallyVisible==false) {

            /// If we find no references, remove it
            if(!typeHasReferencesInScope(enum_, scope_)) {
                fold(enum_);
                return;
            }
        }
    }
    void tryToFold(Function f) {
        /// Only remove private functions
        if(f.access.isPublic) return;

        if(f.numRefs==0) {
            fold(f);
        } else {

        }
    }
    void tryToFold(Variable v) {
        /// Only remove private variables
        if(v.access.isPublic) return;

        /// Don't remove struct properties
        if(v.isMember()) return;

        if(v.numRefs==0) {
            /// If numRefs==0 then remove it
            fold(v);

        } else if(v.numRefs==1) {
            /// If the only reference is the initialiser and the initialiser
            /// is a CompileTimeConstant then the Variable can be removed

            /// Variable[refs=1]
            ///     Initialiser
            ///       ASSIGN
            ///          Identifier
            ///          CompileTimeConstant

            if(v.hasInitialiser) {
                auto lit = v.initialiser().getExpr();
                auto ctc = lit.as!CompileTimeConstant;
                if(ctc) {
                    fold(v);
                }
            }
        }
    }
    void tryToFold(Call call) {
        //assert(call.target.isResolved, "target not resolved: %s %s".format(module_.canonicalName, call));

        /// Don't get rid of this importand call even if it is empty
        if(call.name=="__runModuleConstructors") return;

        /// If we get here and the target is not resolved then it must have
        /// been dereferenced in a previous folding
        if(!call.target.isResolved) {
            fold(call);
            return;
        }

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
}
