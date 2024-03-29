module ppl.ast.stmt.Return;

import ppl.internal;

/**
 *  Return
 *      [ Expression ]
 */
final class Return : Statement {

/// ASTNode
    override bool isResolved() { return getType.isKnown(); }
    override NodeID id() const { return NodeID.RETURN; }
    override Type getType()    { return hasExpr ? expr().getType : TYPE_VOID; }


    bool hasExpr() {
        return numChildren() > 0;
    }
    Expression expr() {
        return cast(Expression)first();
    }
    Type getReturnType() {
        auto funcLit = getAncestor!LiteralFunction;
        assert(funcLit);

        auto type = funcLit.getType().getFunctionType();
        assert(type);

        return type.returnType();
    }
    LiteralFunction getLiteralFunction() {
        return getAncestor!LiteralFunction;
    }

    override string toString() {
        return "return";
    }
}