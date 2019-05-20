module ppl.ast.expr.Calloc;

import ppl.internal;
///
/// Allocate a type on the heap
///
final class Calloc : Expression {
private:
    Type ptrType;
public:
    Type valueType;

/// ASTNode
    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.CALLOC; }
    override Type getType() {
        if(!ptrType) {
            auto t = Pointer.of(valueType, 1);
            if(!valueType.isAlias) ptrType = t;
            return t;
        }
        return ptrType;
    }
/// Expression
    override int priority() const { return 15; }
    override CT comptime() {
        // todo - this might be comptime since we know the size and that it is all zeroes
        return CT.NO;
    }


    override string toString() {
        return "Calloc (%s)".format(getType());
    }
}