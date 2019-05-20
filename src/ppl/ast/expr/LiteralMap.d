module ppl.ast.expr.LiteralMap;

import ppl.internal;

final class LiteralMap : Expression {
    Type type;

    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_MAP; }
    override int priority() const { return 15; }
    override Type getType() { return type; }

    override CT comptime() { return CT.NO; }

    override string toString() {
        return "[:] %s".format(type);
    }
}