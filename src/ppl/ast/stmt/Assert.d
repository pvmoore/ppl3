module ppl.ast.stmt.Assert;

import ppl.internal;

/// Assert
///     expr
///
final class Assert : Statement {

    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.ASSERT; }
    override Type getType()    { return TYPE_VOID; }

    Expression expr() { return first().as!Expression; }

    override string toString() {
        return "Assert";
    }
}