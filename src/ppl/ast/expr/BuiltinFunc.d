module ppl.ast.expr.BuiltinFunc;

import ppl.internal;

/**
 *  BuiltinFunc
 *      { Expression }   // args
 *
 *  @alignOf        (expr)
 *  @sizeOf         (expr)
 *  @initOf         (expr)
 *
 *  @isPointer      (expr)
 *  @pointerDepth   (expr)
 *  @isValue        (expr)
 *  @isInteger      (expr)
 *  @isReal         (expr)
 *  @isStruct       (expr)
 *  @isClass        (expr)
 *  @isFunction     (expr)
 *  @isFunctionPtr  (expr)
 *
 *  @ult            (expr, expr)
 *  @ulte           (expr, expr)
 *  @ugt            (expr, expr)
 *  @ugte           (expr, expr)
 *  @udiv           (expr, expr)
 *  @umod           (expr, expr)
 *
 *  @expect         (expr, const expr)
 *
 *  @typeOf         (expr)
 *
 *  @arrayOf        (type, expr... )
 *  @structOf       (expr... )
 *
 *  @ctAssert       (expr)  // compile time assert
 *  @ctUnreachable
 *
 *  To be added:
 *      @assert(expr)  // compile time or runtime assert
 *      @as(typeexpr, expr)     ??
 *      @listOf(type, expr... )
 *      @mapOf(keytype, valuetype, key=value, key=value ...)
 *      @stringOf(expr...)
 */
final class BuiltinFunc : Expression {
public:
    string name;
    Type type;              /// for "expect"
    bool errorsRemoved;     /// for "ctAssertError"

/// ASTNode
    override bool isResolved() {
        switch(name) {
            case "expect":
                /// If both expressions are const then we can fold this,
                /// otherwise it needs to be propagated down to the gen layer
                if(numExprs()<2) return true;
                auto e = exprs();

                /// Resolve both expressions
                if(!e[0].isResolved() || !e[1].isResolved()) return false;

                if(e[0].comptime()==CT.UNRESOLVED) return false;

                /// If expr[0] is not comptime then we need to propagate to the gen layer
                if(e[0].comptime()==CT.NO) return type && type.isKnown();

                break;
            case "ctUnreachable":
                return true;
            default:
                break;
        }
        /// Everything else is waiting to be folded
        return false;
    }
    override NodeID id() const { return NodeID.BUILTIN_FUNC; }
    override Type getType() {
        if(name=="expect") {
            if(type) return type;
        }
        return TYPE_UNKNOWN;
    }
/// Expression
    override int priority() const { return 2; }
    override CT comptime() {
        if(name=="expect") return exprs()[0].comptime();
        return CT.YES;
    }


    int numExprs()       { return numChildren(); }
    Expression[] exprs() { return children[].as!(Expression[]); }
    Type[] exprTypes()   { return exprs().types(); }

    override string toString() {
        return "@%s%s".format(name, type && type.isKnown() ? " (type=%s)".format(type) : "");
    }
}