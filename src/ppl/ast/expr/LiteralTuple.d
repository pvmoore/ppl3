module ppl.ast.expr.LiteralTuple;

import ppl.internal;
///
/// literal_tuple ::= "[" tuple_param { "," tuple_param } "]"
/// tuple_param   ::= expression | name "=" expression
///
/// LiteralTuple
///     expression
///     expression etc...
///
final class LiteralTuple : Expression {
    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

    override bool isResolved()    { return type.isKnown; }
    override NodeID id() const    { return NodeID.LITERAL_TUPLE; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }

    override CT comptime() { return CT.NO; }

    ///
    /// Try to infer the type based on the elements.
    ///
    Tuple getInferredType() {
        if(!areKnown(elementTypes())) return null;

        auto t = makeNode!Tuple(this);

        /// Create a child Variable for each member type
        foreach (ty; elementTypes) {
            auto v = makeNode!Variable(this);
            v.type = ty;
            t.add(v);
        }
        /// Add this Tuple at module scope because we need it to be in the AST
        /// but we don't want it as our own child node
        getModule.add(t);

        return t;
    }

    int numElements() {
        return children.length.toInt;
    }
    Expression[] elements() {
        return cast(Expression[])children[];
    }
    Type[] elementTypes() {
        return elements().map!(it=>it.getType).array;
    }
    bool allValuesSpecified() {
        assert(isResolved);
        return elements().length == type.getTuple.numMemberVariables;
    }

    override string toString() {
        return "[] %s".format(type);
    }
private:
}