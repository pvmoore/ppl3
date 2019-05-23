module ppl.ast.expr.Binary;

import ppl.internal;
/**
 *  binary_expression ::= expression op expression
 */
public class Binary : Expression {
    Type type;
    Operator op;
    bool isPtrArithmetic;   /// ptr +/- integer

    this() {
        type = TYPE_UNKNOWN;
    }

/// ASTNode
    override bool isResolved()    { return type.isKnown && left().isResolved && right.isResolved; }
    override NodeID id() const    { return NodeID.BINARY; }
    override Type getType()       { return type; }
/// Expression
    override int priority() const { return op.priority; }
    override CT comptime()        { return mergeCT(mergeCT(left(), right())); }


    Expression left()  { return cast(Expression)children[0]; }
    Expression right() { return cast(Expression)children[1]; }
    Type leftType()    { assert(left()); return left().getType; }
    Type rightType()   { assert(right()); return right().getType; }

    Expression otherSide(Expression e) {
        if(left().nid==e.nid) return right();
        if(right().nid==e.nid) return left();
        return null;
    }

    override string toString() {

        return "%s (type=%s) [%s]".format(op, getType(), comptimeStr());
    }
}
