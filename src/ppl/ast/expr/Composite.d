module ppl.ast.expr.Composite;

import ppl.internal;

/**
 *  Composite
 *
 *  Wrap one or more nodes to appear as one single node.
 */
final class Composite : Expression {
    /// INNER_*     -> The composite children are treated as if they are in an inner scope
    /// INLINE_*    -> The composite children are treated as if they are in the same scope
    enum Usage {
        INNER_KEEP,
        INLINE_KEEP,

        INNER_REMOVABLE,
        INLINE_REMOVABLE,
    }

    Usage usage = Usage.INNER_KEEP;


    static Composite make(Usage usage) {
        auto c  = makeNode!Composite;
        c.usage = usage;
        return c;
    }
    static Composite make(ASTNode node, Usage usage) {
        auto c  = makeNode!Composite;
        c.usage = usage;
        return c;
    }
    static Composite make(Tokens t, Usage usage) {
        auto c  = makeNode!Composite;
        c.usage = usage;
        return c;
    }

/// ASTNode
    override bool isResolved()    { return areResolved(children[]); }
    override NodeID id() const    { return NodeID.COMPOSITE; }
    /// The type is the type of the last element
    override Type getType() {
        if(hasChildren()) return last().getType();
        return TYPE_VOID;
    }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime() {
        auto e = expr();
        return e is null ? CT.YES :
                           e.comptime();
    }

    bool isInline() { return usage==Usage.INLINE_KEEP || usage==Usage.INLINE_REMOVABLE; }
    bool isInner()  { return !isInline(); }

    bool endsWithReturn() {
        return numChildren() > 0 && last().isReturn();
    }

    Expression expr() {
        if(!hasChildren()) return null;
        if(last().isExpression()) return last().as!Expression;
        return null;
    }

    override string toString() {
        return "Composite %s (type=%s)".format(usage, getType());
    }
}