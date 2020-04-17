module ppl.resolve.ResolveCall;

import ppl.internal;
import common : contains;

///
/// Resolve a call.
///
/// - The target may be either a Function or a Variable (of function ptr type)
/// - The target may be in any module, not just the current one
///
/// - If we find a Function match that is a proxy for one or more external functions of
///   a given name then we need to pull in the external module
///

final class CallResolver {
private:
    Module module_;
    ResolveModule resolver;
    FunctionFinder functionFinder;
    FoldUnreferenced foldUnreferenced;
public:
    this(ResolveModule resolver) {
        this.resolver          = resolver;
        this.module_           = resolver.module_;
        this.foldUnreferenced  = resolver.foldUnreferenced;
        this.functionFinder    = new FunctionFinder(module_);
    }
    void resolve(Call n) {

        void _setFuncTarget(Function f) {
            n.target.set(f);
            resolver.setModified(n);
        }
        void _setVarTarget(Variable v) {
            n.target.set(v);
            resolver.setModified(n);
        }

        if(!n.target.isResolved) {
            bool isTemplated = n.isTemplated;
            Expression prev  = n.prevLink();

            if(n.isStartOfChain()) {

                // Wait for the Constructor to be rewritten
                if(n.name=="new" && n.parent.isA!Constructor) {
                    return;
                }

                auto callable = functionFinder.standardFind(n);
                if(callable.resultReady) {
                    /// If we get here then we have 1 good match
                    if(callable.isFunction) {
                        _setFuncTarget(callable.func);
                    }
                    if(callable.isVariable) {
                        _setVarTarget(callable.var);
                    }
                }

            } else if(prev.id==NodeID.MODULE_ALIAS) {
                ///
                auto modAlias = prev.as!ModuleAlias;

                auto callable = functionFinder.standardFind(n, modAlias);
                if(callable.resultReady) {
                    /// If we get here then we have 1 good match
                    assert(callable.isFunction);
                    _setFuncTarget(callable.func);
                }
            } else {
                assert(prev);
                Type prevType = prev.getType;
                assert(prevType);

                if(!prevType.isKnown) return;

                auto dot = n.parent.as!Dot;
                assert(dot);

                if(!prevType.isStructOrClass()) {
                    module_.addError(prev, "Left of call '%s' must be a struct type not a %s".format(n.name, prevType), true);
                    return;
                }

                //dd("module:", module_.canonicalName, "call:", n, "prevType:", prevType);

                Struct ns = prevType.getStruct;
                assert(ns);


                bool isStaticAccess = resolver.isAStaticTypeExpr(prev);

                //if(dot.isStaticAccess!=isStaticAccess) {
                    //dd("!!!!!!!!!!!!!!!!!!!", isStaticAccess, dot.isStaticAccess,
                    //    module_.canonicalName, n.line+1, n.name, "prev:", prev.id);
                    //warn(n, "Deprecated :: found");
                //}

                ////////////////////////

                if(isStaticAccess) {
                    auto callable = functionFinder.structFind(n, ns, true);
                    if(callable.resultReady) {
                        /// If we get here then we have 1 good match
                        if(callable.isFunction) {
                            _setFuncTarget(callable.func);
                        }
                        if(callable.isVariable) {
                            _setVarTarget(callable.var);
                        }
                    }
                } else {

                    if(n.name!="new" && !n.implicitThisArgAdded) {

                        /// Rewrite this call so that prev becomes the 1st argument (this*)

                        /// Make a dummy TypeExpr to insert in the hole we are going to make
                        /// by moving prev to the first child of Call

                        /// Dot
                        ///     Identifier (prev)
                        ///     Call
                        ///         args

                        /// Dot
                        ///     TypeExpr(this)  <---|
                        ///     Call                |
                        ///         Identifier  <---|
                        ///         args

                        auto dummy = TypeExpr.make(
                            prevType.isPtr ? prevType : Pointer.of(prevType,1)
                        );

                        /// Fold but don't dereference 'prev'
                        foldUnreferenced.fold(prev, dummy, false);

                        if(prevType.isValue) {
                            auto ptr = makeNode!AddressOf;
                            ptr.add(prev);
                            n.insertAt(0, ptr);
                        } else {
                            n.insertAt(0, prev);
                        }

                        if(n.paramNames.length>0) n.paramNames = "this" ~ n.paramNames;

                        n.implicitThisArgAdded = true;
                    }

                    auto callable = functionFinder.structFind(n, ns, false);

                    if(callable.resultReady) {
                        /// If we get here then we have 1 good match

                        if(callable.isFunction) {
                            _setFuncTarget(callable.func);
                        }
                        if(callable.isVariable) {
                            _setVarTarget(callable.var);
                        }
                    }
                }
            }

            /// We added template params
            if(isTemplated != n.isTemplated) {
                resolver.setModified(n);
            }
        }

        if(n.target.isResolved && n.argTypes.areKnown) {
            /// We have a target and all args are known

            /// Check to see whether we need to add an implicit "this." prefix
            // if(n.isStartOfChain() &&
            //    n.argTypes.length == n.target.paramTypes.length.toInt-1 &&
            //   !n.implicitThisArgAdded)
            // {
            //     auto ns = n.getAncestor!Struct;
            //     if(ns) {
            //         auto r = resolver.identifierResolver.find("this", n);
            //         if(r.found) {
            //             n.addImplicitThisArg(r.var);
            //             resolver.setModified(n);
            //         }
            //     }
            // }

            /// Rearrange the args to match the parameter order
            if(n.paramNames.length>0) {

                //dd("!!!", n.target, n.paramNames, n.target.paramNames());

                if(n.paramNames.length != n.target.paramNames().length) {
                    module_.addError(n, "Expecting %s arguments, not %s".format(n.target.paramNames().length, n.paramNames.length), true);
                    return;
                }

                import common : indexOf;
                auto targetNames = n.target.paramNames();
                auto args        = new Expression[n.numArgs];

                foreach(i, name; n.paramNames) {
                    auto index = targetNames.indexOf(name);
                    if(index==-1) {
                        module_.addError(n, "Parameter name %s not found".format(name), true);
                        return;
                    }
                    args[index] = n.arg(i.toInt);
                }
                assert(args.length==n.numArgs);

                foreach(a; args) {
                    a.detach();
                }
                foreach(a; args) {
                    n.add(a);
                }

                /// We don't need the param names any more
                n.paramNames = null;
                resolver.setModified(n);
            } else {
                if(n.numArgs != n.target.paramTypes.length) {
                    module_.addError(n, "Expecting %s arguments, not %s".format(n.target.paramTypes.length, n.numArgs), true);
                }
            }

            if(!n.argTypes.canImplicitlyCastTo(n.target.paramTypes)) {
                module_.addError(n, "Cannot implicitly cast arguments (%s) to params (%s)".format(n.argTypes.toString, n.target.paramTypes.toString), true);
            }
        }
    }
private:
    void chat(A...)(lazy string fmt, lazy A args) {
        //if(module_.canonicalName=="test") {
        //    dd(format(fmt, args));
        //}
    }
}
