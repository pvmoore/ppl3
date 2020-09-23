module ppl.resolve.ResolveBinary;

import ppl.internal;

final class ResolveBinary {
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
    void resolve(Binary n) {
        auto lt = n.leftType();
        auto rt = n.rightType();

        if(n.op==Operator.BOOL_AND) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_OR) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }
        if(n.op==Operator.BOOL_OR) {
            auto p = n.parent.as!Binary;
            if(p && p.op==Operator.BOOL_AND) {
                module_.addError(n, "Parenthesis required to disambiguate these expressions", true);
            }
        }

        /// We need the types before we can continue
        if(lt.isUnknown || rt.isUnknown) {
            return;
        }

        /// Handle enums
        if(handleEnums(n, lt, rt)) return;

        /// Handle operator overloading
        if((lt.isStruct) || (rt.isStruct)) {
            if(n.op.isOverloadable) {
                if(rewriteToOperatorOverloadCall(n)) {

                }
                return;
            }
        }

        /// ==
        if(n.op==Operator.BOOL_EQ) {
            bool bothValues = lt.isValue && rt.isValue;
            bool bothTuples = lt.isTuple && rt.isTuple;

            /// Rewrite tuple == tuple --> is_expr
            /// [int] a = [1]
            /// a == [1,2,3]
            if(bothValues && bothTuples) {
                auto isExpr = makeNode!Is;
                isExpr.add(n.left);
                isExpr.add(n.right);

                foldUnreferenced.fold(n, isExpr);
                return;
            }
        }

        if(n.type.isUnknown) {

            /// If we are assigning then take the type of the lhs expression
            if(n.op.isAssign) {
                n.type = lt;

                if(n.op.isPtrArithmetic && lt.isPtr && rt.isInteger) {
                    n.isPtrArithmetic = true;
                }

            } else if(n.op.isBool) {
                n.type = TYPE_BOOL;
            } else {

                if(n.op.isPtrArithmetic && lt.isPtr && rt.isInteger) {
                    /// ptr +/- integer
                    n.type = lt;
                    n.isPtrArithmetic = true;
                } else if(n.op.isPtrArithmetic && lt.isInteger && rt.isPtr) {
                    /// integer +/- ptr
                    n.type = rt;
                    n.isPtrArithmetic = true;
                } else {
                    /// Set to largest of left or right type



                    auto t = getBestFit(lt, rt);

                    if(!t) {
                        module_.addError(n, "Types are incompatible %s and %s".format(lt, rt), true);
                        return;
                    }

                    /// Promote byte, short to int
                    if(t.isValue && t.isInteger && t.category < TYPE_INT.category) {
                        n.type = TYPE_INT;
                    } else {
                        n.type = t;
                    }
                }
            }
        }

        /// If left and right expressions are const numbers then evaluate them now
        /// and replace the Binary with the result
        if(n.isResolved && n.comptime()==CT.YES) {

            // todo - make this work
            if(n.op.isAssign) return;

            // todo - make LiteralNull work

            auto leftLit  = n.left().as!LiteralNumber;
            auto rightLit = n.right().as!LiteralNumber;

            if(leftLit && rightLit) {

                auto lit = leftLit.copy();

                bool ok = lit.value.applyBinary(n.type, n.op, rightLit.value);
                if(ok) {
                    lit.str = lit.value.getString();

                    foldUnreferenced.fold(n, lit);
                    return;
                } else {
                    module_.addError(n, "(%s %s %s) is not supported".format(lt, n.op.value, rt), true);
                }
            }
        }
    }
private:
    /// Return true if we modified something
    bool handleEnums(Binary n, Type lt, Type rt) {
        if(!lt.isEnum && !rt.isEnum) return false;

        /// Either left or right or both are enums

        /// No special handling for = :=
        if(n.op==Operator.ASSIGN || n.op==Operator.REASSIGN) return false;

        auto builder = module_.nodeBuilder;
        Enum enum_;

        /// eg. +=
        if(n.op.isAssign) {
            /// Rewrite:
            ///
            /// a += expr
            /// to:
            /// a := a + expr

            /// If left is not an identifier then bail out
            if(!n.left().isIdentifier) return false;

            auto id   = n.left().getIdentifier();
            auto id2  = builder.identifier(id.name);
            auto bin2 = builder.binary(n.op.removeAssign(), id2, n.right());
            n.add(bin2);

            n.op = Operator.REASSIGN;

            resolver.setModified(n);
            return true;

        } else {
            /// Rewrite these as .value

            if(lt.isEnum && lt.isValue) {
                enum_ = lt.getEnum;
                auto value = builder.enumMemberValue(enum_, n.left());
                n.addToFront(value);
                resolver.setModified(n);
            }
            if(rt.isEnum && rt.isValue) {
                enum_ = rt.getEnum;
                auto value = builder.enumMemberValue(enum_, n.right());
                n.add(value);
                resolver.setModified(n);
            }
            if(enum_) {
                if(!n.op.isBool) {
                    /// Rewrite to:
                    /// As enum
                    ///     Binary
                    auto as = makeNode!As;
                    foldUnreferenced.fold(n, as);

                    as.add(n);
                    as.add(TypeExpr.make(enum_));
                }
                return true;
            }
        }
        //if(lt.isEnum) {
        //    if(n.op.isOverloadable || n.op.isComparison) {
        //        // todo - call enum operator overload ?
        //    }
        //}
        return false;
    }
    /// @return true if we modified something
    bool rewriteToOperatorOverloadCall(Binary n) {
        Struct leftStruct  = n.leftType.getStruct;
        Struct rightStruct = n.rightType.getStruct;

        assert(leftStruct || rightStruct);

        /// Swap left and right if the struct is on the rhs
        if(!leftStruct) {
            /// eg.
            /// 1 == struct

            if(n.op==Operator.BOOL_EQ || n.op==Operator.BOOL_NE) {

                /// Reverse the operation
                auto op = n.op.switchLeftRightBool();

                /// Swap left and right
                auto left = n.left();
                left.detach();
                n.add(left);

                leftStruct  = rightStruct;
                rightStruct = null;

                n.op = op;

            } else {
                module_.addError(n, "Invalid overload %s.operator%s(%s)"
                                    .format(n.leftType, n.op.value, n.rightType), true);
                return true;
            }
        }

        auto b = module_.nodeBuilder;

        Expression expr;

        /// Try to call the requested operator overload if it is defined.

        if(leftStruct.hasOperatorOverload(n.op)) {
            if(n.op.isAssign) {
                auto leftPtr = leftStruct.isValue ? b.addressOf(n.left) : n.left;
                expr = b.dot(leftPtr, b.call("operator"~n.op.value).add(n.right));
            } else {
                expr = b.dot(n.left, b.call("operator"~n.op.value).add(n.right));
            }
            foldUnreferenced.fold(n, expr);
            return true;
        }

        /// The specific operator overload is not defined.
        /// We can still continue if it is a bool operation
        /// and we can make it work using other defined operators

        /// Missing op | Rewrite to
        /// -----------------------------------------
        ///    ==      | not left.operator!=(right)
        ///    !=      | not left.operator==(right)

        switch(n.op.id) with(Operator) {
            case BOOL_EQ.id:
                if(leftStruct.hasOperatorOverload(BOOL_NE)) {
                    expr = b.dot(n.left, b.call("operator!=").add(n.right));
                    expr = b.not(expr);
                    foldUnreferenced.fold(n, expr);
                    return true;
                }
                break;
            case BOOL_NE.id:
                if(leftStruct.hasOperatorOverload(Operator.BOOL_EQ)) {
                    expr = b.dot(n.left, b.call("operator==").add(n.right));
                    expr = b.not(expr);
                    foldUnreferenced.fold(n, expr);
                    return true;
                }
                break;
            default:
                break;
        }

        return false;
    }
}