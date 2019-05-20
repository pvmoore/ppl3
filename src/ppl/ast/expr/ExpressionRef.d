module ppl.ast.expr.ExpressionRef;

import ppl.internal;
///
/// Points to another Expression node so that we don't have to clone expression nodes.
///
final class ExpressionRef : Expression {
    Expression reference;

    static Expression make(Expression r) {
        auto ref_ = makeNode!ExpressionRef(r);
        ref_.reference = r;
        return ref_;
    }

/// ASTNode
    override bool isResolved()    { return reference.isResolved(); }
    override NodeID id() const    { return reference.id(); }
    override Type getType()       { return reference.getType; }

/// Expression
    override int priority() const { return reference.priority(); }
    override CT comptime()        { return reference.comptime(); }


    Expression expr() { return reference; }

    override string toString() {
        return "ref to %s".format(reference);
    }
}