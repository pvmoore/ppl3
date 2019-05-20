module ppl.ast.expr.Parenthesis;

import ppl.internal;

final class Parenthesis : Expression  {

    override bool isResolved() { return expr.isResolved; }
    override bool isConst() { return expr().isConst(); }
    override NodeID id() const { return NodeID.PARENTHESIS; }
    override int priority() const { return 15; }
    override Type getType() { return expr().getType(); }

    override CT comptime() { return expr().comptime(); }

    Expression expr() {
        return cast(Expression)first();
    }
    Type exprType() {
        return expr().getType;
    }

    override string toString() {
        return "() %s".format(getType());
    }
}