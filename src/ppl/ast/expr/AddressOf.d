module ppl.ast.expr.AddressOf;

import ppl.internal;

///
/// AddressOf ::= "&" expression
///
final class AddressOf : Expression {
private:
    Type type;
public:
/// ASTNode
    override bool isResolved()    { return expr.isResolved; }
    override NodeID id() const    { return NodeID.ADDRESS_OF; }
    override Type getType() {
        if(!expr().isResolved) return TYPE_UNKNOWN;

        if(type) {
            assert(type.getPtrDepth==expr().getType.getPtrDepth+1);
            return type;
        }

        auto t = expr().getType();
        type = Pointer.of(t, 1);
        return type;
    }

/// Expression
    override int priority() const { return 3; }
    override CT comptime()        { return expr().comptime(); }


    Expression expr() { return children[0].as!Expression; }

    override string toString() {
        return "AddressOf (%s)".format(getType());
    }
}