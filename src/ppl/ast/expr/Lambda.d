module ppl.ast.expr.Lambda;

import ppl.internal;
///
/// Lambda
///     LiteralFunction
///
final class Lambda : Expression {
    string name;

    LLVMValueRef llvmValue;

    override bool isResolved() { return true; }
    override bool isConst() { return false; }
    override NodeID id() const { return NodeID.LAMBDA; }
    override int priority() const { return 15; }
    override Type getType() { return getBody().getType(); }

    LiteralFunction getBody() {
        return first().as!LiteralFunction;
    }

    override string toString() {
        return "Lambda %s %s".format(nid, name);
    }
}