module ppl.resolve.ResolveBuiltinFunc;

import ppl.internal;

final class ResolveBuiltinFunc {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(BuiltinFunc n) {

        if(!n.exprTypes().areKnown) return;

        int expectedNumExprs = 1;
        switch(n.name) {
            case "sizeOf":
                if(n.numExprs > 0) {
                    int size = n.exprs()[0].getType().size();
                    resolver.fold(n, LiteralNumber.makeConst(size, TYPE_INT));
                }
                break;
            case "alignOf":
                if(n.numExprs > 0) {
                    int align_ = n.exprs()[0].getType().alignment();
                    resolver.fold(n, LiteralNumber.makeConst(align_, TYPE_INT));
                }
                break;
            case "initOf":
                if(n.numExprs > 0) {
                    auto ini = initExpression(n.exprs()[0].getType);
                    resolver.fold(n, ini);
                }
                break;
            case "isRef":
                if(n.numExprs > 0) {
                    auto r = n.exprTypes()[0].isPtr;
                    resolver.fold(n, LiteralNumber.makeConst(r, TYPE_BOOL));
                }
                break;
            case "isValue":
                if(n.numExprs > 0) {
                    auto r = n.exprTypes()[0].isPtr;
                    resolver.fold(n, LiteralNumber.makeConst(!r, TYPE_BOOL));
                }
                break;
            case "isInteger":
                if(n.numExprs > 0) {
                    auto b = n.exprTypes()[0].isInteger;
                    resolver.fold(n, LiteralNumber.makeConst(b, TYPE_BOOL));
                }
                break;
            case "isReal":
                if(n.numExprs > 0) {
                    auto b = n.exprTypes()[0].isReal;
                    resolver.fold(n, LiteralNumber.makeConst(b, TYPE_BOOL));
                }
                break;
            case "isStruct":
                if(n.numExprs > 0) {
                    auto b = n.exprTypes()[0].isStruct;
                    resolver.fold(n, LiteralNumber.makeConst(b, TYPE_BOOL));
                }
                break;
            case "isFunction":
                if(n.numExprs > 0) {
                    auto e      = n.exprs()[0];
                    auto ft     = e.getType.getFunctionType;
                    auto isFunc = false;

                    if(e.isIdentifier) {
                        isFunc = e.as!Identifier.target.isFunction;
                    } else if(e.isTypeExpr) {
                        isFunc = ft && !ft.isFunctionPtr;
                    } else {
                        /// Assume anything else is not a function
                    }

                    resolver.fold(n, LiteralNumber.makeConst(isFunc, TYPE_BOOL));
                }
                break;
            case "isFunctionPtr":
                if(n.numExprs > 0) {
                    auto e      = n.exprs()[0];
                    auto ft     = e.getType.getFunctionType;
                    auto isFunc = false;

                    if(e.isIdentifier) {
                        isFunc = e.as!Identifier.target.isVariable;
                    } else if(e.isTypeExpr) {
                        isFunc = ft && ft.isFunctionPtr;
                    } else {
                        /// Assume anything else is not a function
                    }

                    resolver.fold(n, LiteralNumber.makeConst(isFunc, TYPE_BOOL));
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

                    if(t.isFunction && e.isIdentifier && e.as!Identifier.target.isVariable) {
                        /// Set isFunctionPtr flag otherwise we won't be able to
                        /// differentiate this from a standard function
                        te.getType.getFunctionType.isFunctionPtr = true;
                    }
                    resolver.fold(n, te);
                }
                break;
            case "arrayOf":
                expectedNumExprs = -1;

                if(n.numExprs < 1 || !n.first().isTypeExpr) {
                    module_.addError(n.hasChildren ? n.first : n, "Expecting array type as first argument", true);
                } else {

                    auto array = makeNode!LiteralArray(n);

                    array.type.subtype = n.first().getType;
                    array.type.setCount(LiteralNumber.makeConst(n.numExprs-1, TYPE_INT));

                    foreach(ch; n.children[1..$].dup) {
                        array.add(ch);
                    }
                    resolver.fold(n, array);
                }

                break;
            case "structOf":
                expectedNumExprs = -1;

                if(n.numExprs==0) {
                    module_.addError(n, "Expecting at least one expression", true);
                }

                auto struct_ = makeNode!LiteralTuple(n);

                foreach(ch; n.children[].dup) {
                    struct_.add(ch);
                }
                resolver.fold(n, struct_);

                break;
            case "expect":
                /// @expect(a, 10)
                /// Both expressions must be integers or bools
                /// Lowered to expr[0]
                /// expr[1] must be a const
                expectedNumExprs = 2;

                if(n.numExprs==2) {

                    auto exprs = n.exprs();

                    if(!exprs[1].isConst()) {
                        module_.addError(exprs[1], "@expect argument 2 needs to be a const integer or bool", true);
                    }

                    if(exprs.areResolved && exprs[0].isConst() && exprs[1].isConst()) {
                        /// We can fold this because both expressions are const
                        auto left  = exprs[0].as!LiteralNumber;
                        auto right = exprs[1].as!LiteralNumber;

                        if(left && right) {
                            resolver.fold(n, left);
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

                    if(cct is null) {
                        if(!n.exprs()[0].isConst()) {
                            module_.addError(n.exprs()[0], "@ctAssert argument needs to be a compile time constant", true);
                        }
                    } else {

                        if(cct.isTrue()) {
                            resolver.fold(n);
                            return;
                        }

                        module_.addError(n, "Compile Time assertion failed", true);
                    }
                }
                break;
            case "ctUnreachable":
                expectedNumExprs = 0;

                /// Ignore this until the check phase

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