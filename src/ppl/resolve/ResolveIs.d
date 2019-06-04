module ppl.resolve.ResolveIs;

import ppl.internal;

final class ResolveIs {
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
    void resolve(Is n) {
        auto leftType  = n.leftType();
        auto rightType = n.rightType();

        /// Both sides must be resolved
        if(leftType.isUnknown || rightType.isUnknown) return;

        /// Type is Type
        if(n.left().isTypeExpr && n.right().isTypeExpr) {
            rewriteToConstBool(n, leftType.exactlyMatches(rightType));
            return;
        }

        /// Type is expr
        /// expr is Type
        if(n.left().isTypeExpr || n.right().isTypeExpr) {
            auto offendingExpr = n.left().isTypeExpr ? n.right() : n.left();
            module_.addError(offendingExpr, "Comparing type to non-type. Did you mean @typeOf() ?", true);
            return;
        }

        /// Identifier IS Identifier

        if(leftType.isValue && rightType.isValue) {
            /// value IS value

            /// If the sizes are different then the result must be false
            if(leftType.size != rightType.size) {
                rewriteToConstBool(n, false);
                return;
            }

            /// If one side is a struct then the other must be too
            if(leftType.isStruct != rightType.isStruct) {
                rewriteToConstBool(n, false);
                return;
            }
            /// If one side is a tuple then the other side must be too
            if(leftType.isTuple != rightType.isTuple) {
                rewriteToConstBool(n, false);
                return;
            }
            /// If one side is an array then the other must be too
            if(leftType.isArray != rightType.isArray) {
                rewriteToConstBool(n, false);
                return;
            }
            /// If one side is a function then the other side must be too
            if(leftType.isFunction != rightType.isFunction) {
                rewriteToConstBool(n, false);
                return;
            }
            /// If one side is an enum then the other side must be too
            if(leftType.isEnum != rightType.isEnum) {
                rewriteToConstBool(n, false);
                return;
            }

            /// Two structs
            if(leftType.isStruct) {

                /// Must be the same type
                if(leftType.getStruct != rightType.getStruct) {
                    rewriteToConstBool(n, false);
                    return;
                }

                rewriteToMemcmp(n);
                return;
            }

            /// Two tuples
            if(leftType.isTuple) {
                rewriteToMemcmp(n);
                return;
            }

            /// Two enums
            if(leftType.isEnum) {
                auto leftEnum  = leftType.getEnum;
                auto rightEnum = rightType.getEnum;

                /// Must be the same enum type
                if (!leftEnum.exactlyMatches(rightEnum)) {
                    rewriteToConstBool(n, false);
                    return;
                }

                rewriteToEnumMemberValues(n, leftEnum);
                return;
            }

            /// Two arrays
            if(leftType.isArray) {

                /// Must be the same subtype
                if(!leftType.getArrayType.subtype.exactlyMatches(rightType.getArrayType.subtype)) {
                    rewriteToConstBool(n, false);
                    return;
                }

                rewriteToMemcmp(n);
                return;
            }

            /// Two functions
            if(leftType.isFunction) {
                assert(false, "implement me");
            }

            assert(leftType.isBasicType);
            assert(rightType.isBasicType);

            rewriteToBoolEquals(n);
            return;

        }

        if(leftType.isPtr != rightType.isPtr) {
            module_.addError(n, "Both sides if 'is' expression should be pointer types", true);
            return;
        }

        /// ptr is ptr
        assert(leftType.isPtr && rightType.isPtr);

        /// null is null
        if(n.left().isA!LiteralNull && n.right().as!LiteralNull) {
            rewriteToConstBool(n, true);
            return;
        }

        /// This is the only one that stays as an Is
    }
private:
    void rewriteToConstBool(Is n, bool result) {
        result ^= n.negate;

        auto lit = LiteralNumber.makeConst(result ? TRUE : FALSE, TYPE_BOOL);

        foldUnreferenced.fold(n, lit);
    }
    ///
    /// Binary (EQ)
    ///     call memcmp
    ///         Addressof
    ///             left
    ///         Addressof
    ///             right
    ///         long numBytes
    /// 0
    void rewriteToMemcmp(Is n) {
        assert(n.leftType.isValue);
        assert(n.rightType.isValue);

        auto builder = module_.builder(n);

        auto call = builder.call("memcmp", null);
        call.add(builder.addressOf(n.left()));
        call.add(builder.addressOf(n.right()));
        call.add(LiteralNumber.makeConst(n.leftType.size, TYPE_INT));

        auto op = n.negate ? Operator.BOOL_NE : Operator.BOOL_EQ;
        auto ne = builder.binary(op, call, LiteralNumber.makeConst(0, TYPE_INT));

        foldUnreferenced.fold(n, ne);
    }
    void rewriteToBoolEquals(Is n) {
        auto builder = module_.builder(n);

        auto op = n.negate ? Operator.BOOL_NE : Operator.BOOL_EQ;

        auto binary = builder.binary(op, n.left, n.right, TYPE_BOOL);

        foldUnreferenced.fold(n, binary);
    }
    void rewriteToEnumMemberValues(Is n, Enum enum_) {
        auto builder = module_.builder(n);
        auto lemv    = builder.enumMemberValue(enum_, n.left());
        auto remv    = builder.enumMemberValue(enum_, n.right());

        n.add(lemv);
        n.add(remv);
        resolver.setModified(n);
    }
}