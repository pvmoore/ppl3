module ppl.ast.expr.Parenthesis;

import ppl.internal;

/**
 *  Parenthesis
 *      Expression
 */
final class Parenthesis : Expression  {
/// ASTNode
    override bool isResolved()    { return expr.isResolved(); }
    override NodeID id() const    { return NodeID.PARENTHESIS; }
    override Type getType()       { return expr().getType(); }

/// Expression
    override int priority() const { return 15; }
    override CT comptime()        { return expr().comptime(); }


    Expression expr() {
        return cast(Expression)first();
    }
    Type exprType() {
        return expr().getType();
    }

    override string toString() {
        return "() %s".format(getType());
    }
}