module ppl.ast.expr.Unary;

import ppl.internal;
///
/// Unary
///     expr
///
final class Unary : Expression {
    Operator op;

    override bool isResolved() { return expr.isResolved; }
    override bool isConst() { return expr().isConst(); }
    override NodeID id() const { return NodeID.UNARY; }
    override int priority() const { return op.priority; }
    override Type getType() {
        if(op.isBool) return TYPE_BOOL;
        return expr().getType;
    }

    override CT comptime() { return expr().comptime(); }

    Expression expr() { return children[0].as!Expression; }

    override string toString() {
        return "%s (%s)".format(op, getType());
    }
}