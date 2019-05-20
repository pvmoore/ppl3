module ppl.ast.expr.LiteralNull;

import ppl.internal;

final class LiteralNull : Expression, CompileTimeConstant {
    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

    static LiteralNull makeConst(Type t=TYPE_UNKNOWN) {
        auto lit = makeNode!LiteralNull;
        lit.type = t;
        return lit;
    }

    /// <CompileTimeConstant>
    LiteralNull copy() {
        auto c = makeNode!LiteralNull(this);
        c.type = type;
        return c;
    }
    bool isTrue() {
        return false;
    }

    override bool isResolved()    { return type.isKnown; }
    override bool isConst()       { return true; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }
    override NodeID id() const    { return NodeID.LITERAL_NULL; }

    override string toString() {
        return "null (type=const %s)".format(type);
    }
}