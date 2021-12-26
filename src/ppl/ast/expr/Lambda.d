module ppl.ast.expr.Lambda;

import ppl.internal;

/**
 *  Lambda
 *      LiteralFunction
 */
final class Lambda : Expression {
    string name;

    LLVMValueRef llvmValue;

/// ASTNode
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.LAMBDA; }
    override Type getType() { return getBody().getType(); }

/// Expression
    override int priority() const { return 15; }
    override CT comptime() {
        // todo - this might be comptime if it returns a comptime value
        return CT.NO;
    }


    LiteralFunction getBody() {
        return first().as!LiteralFunction;
    }

    override string toString() {
        return "Lambda %s %s".format(nid, name);
    }
}