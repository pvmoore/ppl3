module ppl.ast.expr.BuiltinFunc;

import ppl.internal;
///
/// @alignOf    (expr)  // should work on TypeExpr only?
/// @sizeOf     (expr)  // should work on TypeExpr only?
/// @initOf     (expr)  // should work on TypeExpr only?
/// @isRef      (expr)  // should work on TypeExpr only?
/// @isValue    (expr)  // should work on TypeExpr only?
///
/// @isInteger  (expr)  // should work on TypeExpr only?
/// @isReal     (expr)  // should work on TypeExpr only?
/// @isStruct   (expr)  // should work on TypeExpr only?
/// @isFunction (expr)  // should work on TypeExpr only?
///
/// @expect     (expr, const expr)
///
/// @typeoOf     (expr)
///
/// @arrayOf(type, expr... )
/// @tupleOf( expr... )
///
///
/// @ctassert   (expr)  // compile time assert
///
/// To be added:
///     @assert     (expr)  // compile time or runtime assert
///     @as(typeexpr, expr)     ??
///     @listOf(type, expr... )
///     @mapOf(keytype, valuetype, key=value, key=value ...)

final class BuiltinFunc : Expression {
    string name;
    Type type;  // for "expect"

    override bool isResolved() {
        if(name=="expect") {
            /// If both expressions are const then we can fold this,
            /// otherwise it needs to be propagated down to the gen layer
            if(numExprs()<2) return true;
            auto e = exprs();

            /// Resolve both expressions
            if(!e[0].isResolved || !e[1].isResolved) return false;

            /// If expr[0] is not const then we need to propagate to the gen layer
            if(!e[0].isConst()) return type && type.isKnown;
        }
        if(name=="ctUnreachable") {
            return true;
        }
        /// Everything else is waiting to be folded
        return false;
    }
    override bool isConst() {
        if(name=="expect") return exprs()[0].isConst();
        return true;
    }
    override NodeID id() const    { return NodeID.BUILTIN_FUNC; }
    override int priority() const { return 2; }
    override Type getType() {
        if(name=="expect") {
            if(type) return type;
        }
        return TYPE_UNKNOWN;
    }

    override CT comptime() {
        if(name=="expect") return exprs()[0].comptime();
        return CT.YES;
    }

    int numExprs()       { return numChildren; }
    Expression[] exprs() { return children[].as!(Expression[]); }
    Type[] exprTypes()   { return exprs().types(); }

    override string toString() {
        return "@%s%s".format(name, type && type.isKnown ? " (type=%s)".format(type) : "");
    }
}