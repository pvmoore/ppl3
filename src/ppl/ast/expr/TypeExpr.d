module ppl.ast.expr.TypeExpr;

import ppl.internal;

final class TypeExpr : Expression {
    Type type;

    static TypeExpr make(Type t) {
        auto e = makeNode!TypeExpr;
        e.type = t;
        return e;
    }

/// ASTNode
    override bool isResolved()    { return type && type.isKnown; }
    override NodeID id() const    { return NodeID.TYPE_EXPR; }
    override Type getType()       { return type; }

/// Expression
    override int priority() const { return 15; }
    override CT comptime()        { return CT.YES; }


    override string toString() {
        return "Type:%s".format(type);
    }
}