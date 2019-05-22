module ppl.resolve.ResolveAs;

import ppl.internal;

final class ResolveAs {
private:
    Module module_;
    ResolveModule resolver;
public:
    this(ResolveModule resolver, Module module_) {
        this.resolver = resolver;
        this.module_  = module_;
    }
    void resolve(As n) {

        auto lt      = n.leftType();
        auto rt      = n.rightType();
        auto builder = module_.builder(n);

        if(!lt.isKnown || !rt.isKnown) return;

        /// If cast is unnecessary then just remove the As
        if(lt.exactlyMatches(rt)) {
            resolver.fold(n, n.left);
            return;
        }

        /// enum as enum (they must be different enums because they didn't exactly match)
        if(lt.isEnum && rt.isEnum) {
            /// eg. A.VAL as B
            errorBadExplicitCast(module_, n, lt, rt);
            return;
        }

        /// enum as non-enum
        /// eg. E1 as 4
        if(lt.isEnum && !rt.isEnum) {
            /// Rewrite to left.value as right

            auto value = builder.enumMemberValue(lt.getEnum, n.left());

            n.addToFront(value);

            resolver.setModified(n);
            return;
        }

        /// non-enum as enum
        /// eg. 4 as E1
        if(!lt.isEnum && rt.isEnum) {
            /// Create new EnumMember to represent this value
            auto member = builder.enumMember(rt.getEnum, n.left());

            resolver.fold(n, member);
            return;
        }

        /// If left is a literal number then do the cast now
        auto lit = n.left().as!LiteralNumber;
        if(lit && rt.isValue) {

            lit.value.as(rt);
            lit.str = lit.value.getString();

            resolver.fold(n, lit);
            return;
        }

        bool isValidRewrite(Type t) {
            return t.isValue && (t.isTuple || t.isArray || t.isStruct);
        }

        if(isValidRewrite(lt) && isValidRewrite(rt)) {
            /// Tuple value -> Tuple value

            /// This is a reinterpret cast

            /// Rewrite:
            ///------------
            /// As
            ///    left
            ///    right
            ///------------
            /// ValueOf type=rightType
            ///    As
            ///       AddressOf
            ///          left
            ///       AddressOf
            ///          right

            auto p = n.parent;

            auto value = makeNode!ValueOf(n);

            auto left  = builder.addressOf(n.left);
            auto right = builder.addressOf(n.right);
            n.add(left);
            n.add(right);

            resolver.fold(n, value);

            value.add(n);

            return;
        }
    }
}