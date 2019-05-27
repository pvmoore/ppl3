module ppl.resolve.misc.FoldUnreferenced;

import ppl.internal;
/*
Scope:                  | Visible to scope:
0   1   2               |
=====================================================
Module                  |
    pub function        | 1 and external module
    function            | 1
                        |
    variable            | 1
                        |
    pub struct          | 1 and external module
        pub variable    | 1 and external module
        variable        | internal struct only
                        |
        pub function    |
        function        | internal struct only
                        |
    struct              | 1
        pub variable    |
        variable        |
*/
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

        /// Process function bodies
        foreach(f; module_.getFunctions()) {
            if(f.hasBody()) {
                processNode(f.getBody());
            }
        }
        /// Process structs
        foreach(s; module_.getStructs()) {
            processStruct(s);
        }

        /// Remove any Variable or Function that is not referenced
        if(allTargetsResolved(module_)) {
            foreach(v; module_.getVariables()) tryToFold(v);
            foreach(f; module_.getFunctions()) tryToFold(f);
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
    }
    void fold(ASTNode removeMe, bool dereference = true) {
        if(dereference) {
            recursiveDereference(removeMe);
        }
        resolveModule.setModified(removeMe);
        removeMe.detach();
    }
private:
    void processNode(ASTNode scope_) {
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

        assert(scope_.isLiteralFunction || scope_.isComposite);

        /// Remove Variable, Function, Call -> All targets must be known
        if(allTargetsResolved(scope_)) {
            scope_.recurse!Variable( (v) { tryToFold(v); });
            scope_.recurse!Call( (call)  { tryToFold(call); });
            scope_.recurse!Function( (f) { tryToFold(f);});
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

        bool _isStructRemovable(ASTNode scope_) {
            bool removable = true;

            scope_.recurse!ASTNode(
                n => removable &&
                (n !is s) &&
                (n.id!=NodeID.MODULE) &&
                (n.id!=NodeID.IMPORT) &&
                (n.parent.id!=NodeID.IMPORT),
                (n) {
                    auto type = n.getType;
                    if(type.isUnknown) {
                        removable = false;
                        //if(s.name=="S2") {
                        //    dd("unknown n=", n);
                        //    n.dumpToConsole();
                        //}
                    } else {
                        auto ns = n.getType.getStruct;
                        if(ns && ns is s) {
                            removable = false;
                            //if(s.name=="S2") {
                            //    dd("referenced n=", n.line+1, n);
                            //    n.dumpToConsole();
                            //}
                        }
                    }
                }
            );
            return removable;
        }

        if(s.isTemplateBlueprint) return;

        /// scope_
        ///     struct
        ///
        auto scope_ = s.getLogicalParent();

        /// If this struct is a private global or an inner struct then see if it can be removed
        if(s.access.isPrivate || !s.isAtModuleScope()) {

            if(_isStructRemovable(scope_)) {
                fold(s);
                return;
            }
        }

        /// We can't remove the struct. See if we can remove any
        /// Variables, Functions, Enums or Aliases declared at struct scope

        if(allTargetsResolved(scope_)) {
            foreach(v; s.getMemberVariables()) tryToFold(v);
            foreach(v; s.getStaticVariables()) tryToFold(v);

            foreach(f; s.getMemberFunctions()) tryToFold(f);
            foreach(f; s.getStaticFunctions()) tryToFold(f);
        }
        foreach(e; s.getEnums()) processEnum(e);
        // todo - aliases

        /// Recurse function bodies
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
    void tryToFold(Variable v) {
        /// Must be a local variable or a private global
        if(!v.isGlobal && !v.isLocalAlloc) return;

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
    void tryToFold(Function f) {

        /// Don't fold any module constructors
        if(f.name=="new" && f.isAtModuleScope()) return;

        /// Public module scope functions can not be folded yet
        if(f.access.isPublic && f.isAtModuleScope()) return;

        // todo - we should be able to fold some public struct members
        if(f.access.isPublic) return;

        if(f.numRefs==0) {
            fold(f);
        } else {

        }
    }
    /// Module
    ///     pub struct          | cannot be removed
    ///         pub variable    | cannot be removed
    ///         variable        | check targets within struct
    ///                         |
    ///         pub function    | cannot be removed
    ///         function        | check targets within struct
    ///                         |
    ///         pub struct|enum | cannot be removed
    ///         struct|enum     | check types within parent struct
    ///                         |
    ///     struct              | check types from parent scope
    ///         pub variable    | check targets of struct parent scope
    ///         variable        | check targets within struct
    ///
    ///     function
    ///         struct              | check types with parent scope
    ///             pub function    | check targets of struct parent scope
    ///             function        | check targets within struct
    ///                             |
    ///             pub variable    |
    ///             variable        |
    ///
    ///
    void tryToFoldStructMember(Function f) {
        assert(f.isStructFunc);

        if(f.access.isPublic) return;

        if(f.numRefs==0) {
            fold(f);
        } else {

        }
    }
    void tryToFold(Call call) {
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
