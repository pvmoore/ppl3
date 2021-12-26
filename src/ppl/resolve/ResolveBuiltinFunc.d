module ppl.resolve.ResolveBuiltinFunc;

import ppl.internal;

final class ResolveBuiltinFunc {
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
    void resolve(BuiltinFunc n) {

        if(!n.exprTypes().areKnown()) return;

        int expectedNumExprs = 1;
        switch(n.name) {
            case "sizeOf":
                if(n.numExprs() > 0) {
                    int size = n.exprs()[0].getType().size();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(size.to!string, TYPE_INT));
                }
                break;
            case "alignOf":
                if(n.numExprs() > 0) {
                    int align_ = n.exprs()[0].getType().alignment();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(align_.to!string, TYPE_INT));
                }
                break;
            case "initOf":
                if(n.numExprs() > 0) {
                    auto ini = initExpression(n.exprs()[0].getType);
                    foldUnreferenced.fold(n, ini);
                }
                break;
            case "isPointer":
                if(n.numExprs() > 0) {
                    auto r = n.exprTypes()[0].isPtr();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(r ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "pointerDepth":
                if(n.numExprs() > 0) {
                    int r = n.exprTypes()[0].getPtrDepth();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(r.to!string, TYPE_INT));
                }
                break;
            case "isValue":
                if(n.numExprs() > 0) {
                    auto r = n.exprTypes()[0].isPtr();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(!r ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isInteger":
                if(n.numExprs() > 0) {
                    auto b = n.exprTypes()[0].isInteger();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(b ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isReal":
                if(n.numExprs() > 0) {
                    auto b = n.exprTypes()[0].isReal();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(b ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isStruct":
                if(n.numExprs() > 0) {
                    auto b = n.exprTypes()[0].isStruct();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(b ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isClass":
                if(n.numExprs() > 0) {
                    auto b = n.exprTypes()[0].isClass();
                    foldUnreferenced.fold(n, LiteralNumber.makeConst(b ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isFunction":
                if(n.numExprs() > 0) {
                    auto e      = n.exprs()[0];
                    auto ft     = e.getType.getFunctionType();
                    auto isFunc = false;

                    if(e.isIdentifier()) {
                        isFunc = e.getIdentifier().target.isFunction();
                    } else if(e.isTypeExpr()) {
                        isFunc = ft && !ft.isFunctionPtr;
                    } else {
                        /// Assume anything else is not a function
                    }

                    foldUnreferenced.fold(n, LiteralNumber.makeConst(isFunc ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "isFunctionPtr":
                if(n.numExprs > 0) {
                    auto e      = n.exprs()[0];
                    auto ft     = e.getType.getFunctionType();
                    auto isFunc = false;

                    if(e.isIdentifier()) {
                        isFunc = e.getIdentifier().target.isVariable();
                    } else if(e.isTypeExpr()) {
                        isFunc = ft && ft.isFunctionPtr;
                    } else {
                        /// Assume anything else is not a function
                    }

                    foldUnreferenced.fold(n, LiteralNumber.makeConst(isFunc ? TRUE_STR : FALSE_STR, TYPE_BOOL));
                }
                break;
            case "typeOf":
                if(n.numExprs > 0) {
                    auto e  = n.exprs()[0];
                    auto t  = n.exprs()[0].getType;
                    auto te = TypeExpr.make(t);

                    if(e.isTypeExpr) {
                        module_.addError(e, "Expression is already a type", true);
                    }

                    if(t.isFunction && e.isIdentifier && e.getIdentifier().target.isVariable) {
                        /// Set isFunctionPtr flag otherwise we won't be able to
                        /// differentiate this from a standard function
                        te.getType.getFunctionType.isFunctionPtr = true;
                    }
                    foldUnreferenced.fold(n, te);
                }
                break;
            case "arrayOf":
                expectedNumExprs = -1;

                if(n.numExprs < 1 || !n.first().isTypeExpr) {
                    module_.addError(n.hasChildren ? n.first : n, "Expecting array type as first argument", true);
                } else {

                    auto array = makeNode!LiteralArray;

                    array.type.subtype = n.first().getType;
                    array.type.setCount(LiteralNumber.makeConst((n.numExprs-1).to!string, TYPE_INT));

                    foreach(ch; n.children[1..$].dup) {
                        array.add(ch);
                    }
                    foldUnreferenced.fold(n, array);
                }

                break;
            case "structOf":
                expectedNumExprs = -1;

                if(n.numExprs==0) {
                    module_.addError(n, "Expecting at least one expression", true);
                }

                auto struct_ = makeNode!LiteralTuple;

                foreach(ch; n.children[].dup) {
                    struct_.add(ch);
                }
                foldUnreferenced.fold(n, struct_);

                break;
            case "expect":
                /// @expect(a, 10)
                /// Both expressions must be integers or bools
                /// Lowered to expr[0]
                /// expr[1] must be a const
                expectedNumExprs = 2;

                if(n.numExprs==2) {

                    auto exprs = n.exprs();

                    if(exprs[1].isResolved && !exprs[1].isA!CompileTimeConstant) {
                        module_.addError(exprs[1], "@expect argument 2 needs to be a const integer or bool", true);
                    }

                    if(exprs.areResolved && exprs[0].comptime()==CT.YES && exprs[1].comptime()==CT.YES) {
                        /// We can fold this because both expressions are const
                        auto left  = exprs[0].as!LiteralNumber;
                        auto right = exprs[1].as!LiteralNumber;

                        if(left && right) {
                            foldUnreferenced.fold(n, left);
                            return;
                        }
                    } else {
                        /// Set the type and propagate to the gen layer
                        if(!n.isResolved) {

                            auto types = n.exprTypes();

                            n.type = getBestFit(types[0], types[1]);
                            resolver.setModified(n);
                        }
                    }
                } else {
                    n.type = TYPE_INT;
                    resolver.setModified(n);
                }
                break;
            case "ctAssert":
                expectedNumExprs = 1;

                if(n.numExprs==1) {
                    auto cct = n.exprs()[0].as!CompileTimeConstant;

                    if(cct) {
                        if(cct.isTrue()) {
                            foldUnreferenced.fold(n);
                            return;
                        }

                        module_.addError(n, "Compile Time assertion failed", true);
                    } else if(resolver.isStalemate) {
                        module_.addError(n.exprs()[0], "@ctAssert argument needs to be a compile time constant", true);
                    }
                }
                break;
            case "ctUnreachable":
                expectedNumExprs = 0;

                /// Ignore this until the check phase

                break;
            case "ult":
            case "ulte":
            case "ugt":
            case "ugte":
                expectedNumExprs = 2;
                if(n.numExprs==2) {
                    auto a = n.exprs()[0];
                    auto b = n.exprs()[1];

                    Operator op =
                        n.name == "ult"  ? Operator.ULT :
                        n.name == "ulte" ? Operator.ULTE :
                        n.name == "ugt"  ? Operator.UGT :
                                           Operator.UGTE;

                    // Binary
                    //      a
                    //      b
                    auto bin = module_.nodeBuilder.binary(op, a, b);

                    foldUnreferenced.fold(n, bin);
                    return;
                }
                break;
            default:
                module_.addError(n, "Built-in function %s not found".format(n.name), true);
                break;
        }

        if(expectedNumExprs!=-1 && n.numExprs != expectedNumExprs) {
            module_.addError(n, "Expecting %s arguments, found %s".format(expectedNumExprs, n.numExprs), true);
        }
    }
private:
}