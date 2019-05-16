module ppl.ast.Assert;

import ppl.internal;

final class Assert : Statement {

    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.ASSERT; }
    override Type getType() { return expr().getType; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "Assert";
    }
}