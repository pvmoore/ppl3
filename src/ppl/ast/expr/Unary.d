module ppl.ast.expr.Unary;

import ppl.internal;
/**
 *  Unary
 *      Expression
 */
final class Unary : Expression {
    Operator op;

/// ASTNode
    override bool isResolved()    { return expr.isResolved(); }
    override NodeID id() const    { return NodeID.UNARY; }
    override Type getType() {
        if(op.isBool()) return TYPE_BOOL;
        return expr().getType();
    }

/// Expression
    override int priority() const { return op.priority; }
    override CT comptime() { return expr().comptime(); }


    Expression expr() { return children[0].as!Expression; }

    override string toString() {
        return "%s (%s)".format(op, getType());
    }
}