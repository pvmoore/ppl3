module ppl.ast.expr.Is;

import ppl.internal;

/**
 *  Is
 *      Expression
 *      Expression
 *
 * TypeExpr   is TypeExpr
 * Identifier is TypeExpr
 * Identifier is Identifier
 */
final class Is : Expression {
private:

public:
    bool negate;

/// ASTNode
    override bool isResolved() {
        /// Everything other than ptr is ptr will be rewritten to some other node
        return leftType.isPtr() && rightType.isPtr();
    }
    override NodeID id() const { return NodeID.IS; }
    override Type getType() { return TYPE_BOOL; }

/// Expression
    override int priority() const { return 9; }
    override CT comptime() { return mergeCT(left(), right()); }


    Expression left()  { return children[0].as!Expression; }
    Expression right() { return children[1].as!Expression; }

    Type leftType() { return left().getType(); }
    Type rightType() { return right().getType(); }

    Type oppositeSideType(Expression node) {
        if(left().nid==node.nid) {
            return rightType();
        } else if(right().nid==node.nid) {
            return leftType();
        }
        assert(false);
    }

    override string toString() {
        string neg = negate ? " not" : "";
        return "Is%s (%s)".format(neg, getType());
    }
private:
}