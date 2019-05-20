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

    override bool isResolved() { return false; }
    override bool isConst() { return false; }
    override NodeID id() const { return NodeID.CALLOC; }
    override int priority() const { return 15; }
    override Type getType() {
        if(!ptrType) {
            auto t = Pointer.of(valueType, 1);
            if(!valueType.isAlias) ptrType = t;
            return t;
        }
        return ptrType;
    }

    override string toString() {
        return "Calloc (%s)".format(getType());
    }
}