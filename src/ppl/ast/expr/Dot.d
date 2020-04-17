module ppl.ast.expr.Dot;

import ppl.internal;
///
/// dot ::= expression "." expression
///
final class Dot : Expression {
/// ASTNode
    override bool isResolved()    { return getType.isKnown && left().isResolved && right().isResolved; }
    override NodeID id() const    { return NodeID.DOT; }
    override Type getType() {
        if(right() is null) return TYPE_UNKNOWN;
        return right().getType;
    }

/// Expression
    override int priority() const {
        return 2;
    }
    override CT comptime() {
        // todo - can we make this comptime?
        return CT.NO;
    }


    Expression left()  { return cast(Expression)first(); }
    Expression right() { return cast(Expression)last(); }

    Type leftType()  { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return "Dot (type=%s)".format(getType);
    }
}