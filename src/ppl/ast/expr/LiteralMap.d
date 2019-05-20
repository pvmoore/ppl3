module ppl.ast.expr.LiteralMap;

import ppl.internal;

final class LiteralMap : Expression {
    Type type;

/// ASTNode
    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_MAP; }
    override Type getType()    { return type; }

/// Expression
    override int priority() const { return 15; }
    override CT comptime() {
        // todo - this might be comptime
        return CT.NO;
    }


    override string toString() {
        return "[:] %s".format(type);
    }
}