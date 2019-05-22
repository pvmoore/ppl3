module ppl.ast.expr.As;

import ppl.internal;
///
/// As
///    expr
///    type
///
final class As : Expression {
/// ASTNode
    override bool isResolved()    { return left().isResolved && getType.isKnown; }
    override NodeID id() const    { return NodeID.AS; }
    override Type getType()       { return rightType(); }
/// Expression
    override int priority() const { return 3; }
    override CT comptime()        { return left().comptime(); }


    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType()  { return left().getType; }
    Type rightType() { return right().getType; }

    override string toString() {
        return "As (%s)".format(getType());
    }
}