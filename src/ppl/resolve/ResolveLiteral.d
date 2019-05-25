module ppl.resolve.ResolveLiteral;

import ppl.internal;

final class ResolveLiteral {
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
    void resolve(LiteralArray n) {

        /*if(n.type.isUnknown) {

            dd("!!!");

            Type parentType;
            switch(n.parent.id) with(NodeID) {
                case ADDRESS_OF:
                    break;
                case AS:
                    parentType = n.parent.as!As.getType;

                    //if(parentType.isArray && parentType.getArrayType.numChildren==0) {
                    //    dd("!!booo");
                    //}

                    break;
                case BINARY:
                    parentType = n.parent.as!Binary.otherSide(n).getType;
                    break;
                case BUILTIN_FUNC:
                    break;
                case CALL: {
                        auto call = n.parent.as!Call;
                        if(call.isResolved) {
                            parentType = call.target.paramTypes()[n.index()];
                        }
                        break;
                    }
                case DOT:
                    break;
                case INDEX:
                    break;
                case INITIALISER:
                    parentType = n.parent.as!Initialiser.getType;
                    break;
                case IS:
                    break;
                case LITERAL_FUNCTION:
                    break;
                case RETURN:
                    break;
                case VARIABLE:
                    parentType = n.parent.as!Variable.type;
                    break;
                default:
                    assert(false, "Parent of LiteralArray is %s".format(n.parent.id));
            }
            if(parentType && parentType.isKnown) {
                auto type = parentType.getArrayType;
                if(type) {
                    if(!type.isArray) {
                        module_.addError(n, "Cannot cast array literal to %s".format(type), true);
                        return;
                    }
                    n.type = type;
                }
            }

        } else {
            /// Make sure we have the same subtype as our parent
            if(n.parent.getType.isKnown) {
                //auto arrayStruct = n.parent.getType().getArrayStruct;
                //assert(arrayStruct, "Expecting ArrayStruct, got %s".format(n.parent.getType()));

                //n.type.subtype = arrayStruct.subtype;
            }
        }
        */
        //if(n.type.isKnown) {
        //    if(n.isArray) {
        //        /// Check that element type matches
        //
        //        auto eleType = n.type.getArrayStruct.subtype;
        //        //auto t       = n.calculateElementType(eleType);
        //
        //        foreach(i, t; n.elementTypes()) {
        //            if(!t.canImplicitlyCastTo(eleType)) {
        //                module_.addError(n.children[i],
        //                    "Expecting an array of %s. Cannot implicitly cast %s to %s".format(eleType, t, eleType));
        //                return;
        //            }
        //        }
        //
        //    } else {
        //
        //    }
        //}
    }
    void resolve(LiteralFunction n) {
        ///
        /// Look through returns. All returns must be implicitly castable to a single base type.
        /// If there are no returns then the return type is void.
        ///
        Type determineReturnType() {
            Type rt;

            void setTypeTo(ASTNode node, Type t) {
                if(rt is null) {
                    rt = t;
                } else {
                    auto combined = getBestFit(t, rt);
                    if(combined is null) {
                        module_.addError(node, "Return types are not compatible: %s and %s".format(t, rt), true);
                    }
                    rt = combined;
                }
            }

            foreach(r; n.getReturns()) {
                if(r.hasExpr) {
                    if(r.expr().getType.isUnknown) return TYPE_UNKNOWN;
                    setTypeTo(r, r.expr().getType);
                } else {
                    setTypeTo(n, TYPE_VOID);
                }
            }
            if(rt) return rt;
            return TYPE_VOID;
        }

        if(n.type.isUnknown) {

            auto ty = n.type.getFunctionType;
            if(ty.returnType.isUnknown) {
                ty.returnType = determineReturnType();
            }

            //if(n.type.isUnknown) {
            //    if(!n.isLambda && n.getFunction.name=="foobarbaz") {
            //        dd("!!unknown foobarbaz -> ", n, "params=", n.params().getParams());
            //
            //        auto params = n.params();
            //        if(params.isResolved) {
            //            dd("\t params are resolved");
            //        }
            //    }
            //}

            if(resolver.isStalemate) {
                module_.addError(n, "Cannot infer type", true);
            }
        }
    }
    void resolve(LiteralMap n) {
        assert(false, "Implement me");
    }
    void resolve(LiteralNull n) {
        if(n.type.isUnknown) {
            auto parent = n.getLogicalParent();

            Type type;
            /// Determine type from parent
            switch(parent.id()) with(NodeID) {
                case AS:
                    type = parent.as!As.getType;
                    break;
                case BINARY:
                    type = parent.as!Binary.leftType();
                    break;
                case CALL: {
                    auto call = parent.as!Call;
                    if(call.isResolved) {
                        type = call.target.paramTypes()[n.index()];
                    }
                    break;
                }
                case CASE:
                    auto c = parent.as!Case;
                    if(c.isCond(n)) {
                        type = c.getSelectType();
                    }
                    break;
                case IF:
                    auto if_ = parent.as!If;
                    if(n.isDescendentOf(if_.thenStmt())) {
                        type = if_.thenType();
                    } else if(if_.hasElse && n.isDescendentOf(if_.elseStmt())) {
                        type = if_.elseType();
                    }
                    break;
                case INITIALISER:
                    type = parent.as!Initialiser.getType;
                    break;
                case IS:
                    type = parent.as!Is.oppositeSideType(n);
                    break;
                case RETURN:
                    auto lf = parent.as!Return.getLiteralFunction();
                    if(lf.isResolved) {
                        type = lf.getType.getFunctionType.returnType();
                    }
                    break;
                case VARIABLE:
                    type = parent.as!Variable.type;
                    break;
                default:
                    assert(false, "parent is %s".format(parent.id()));
            }

            if(type && type.isKnown) {
                if(type.isPtr) {
                    n.type = type;
                } else {
                    module_.addError(n, "Cannot implicitly cast null to %s".format(type), true);
                }
            } else if(resolver.isStalemate) {
                module_.addError(n, "Ambiguous null requires explicit cast", true);
            }
        }
    }
    void resolve(LiteralNumber n) {
        if(n.type.isUnknown) {
            n.determineType();
        }
    }
    void resolve(LiteralString n) {
        if(n.type.isUnknown) {
            resolver.resolveAlias(n, n.type);
        }
    }
    void resolve(LiteralTuple n) {
        if(n.type.isUnknown) {

            /// Determine type from children
            if(!n.elementTypes().areKnown) return;

            n.type = n.getInferredType();
        }

        if(!n.isResolved && resolver.isStalemate) {
            module_.addError(n, "Ambiguous tuple literal requires explicit cast", true);
        }
    }
}