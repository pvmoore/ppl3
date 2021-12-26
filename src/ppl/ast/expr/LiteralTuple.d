module ppl.ast.expr.LiteralTuple;

import ppl.internal;

/**
 *  LiteralTuple
 *      { Expression }
 *
 *  literal_tuple ::= "[" tuple_param { "," tuple_param } "]"
 *  tuple_param   ::= Expression | name "=" Expression
 */
final class LiteralTuple : Expression {
    Type type;

    this() {
        type = TYPE_UNKNOWN;
    }

/// ASTNode
    override bool isResolved()    { return type.isKnown(); }
    override NodeID id() const    { return NodeID.LITERAL_TUPLE; }
    override Type getType()       { return type; }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime() {
        // todo - this probably should be comptime
        return CT.NO;
    }


    ///
    /// Try to infer the type based on the elements.
    ///
    Tuple getInferredType() {
        if(!areKnown(elementTypes())) return null;

        auto t = makeNode!Tuple;

        /// Create a child Variable for each member type
        foreach (ty; elementTypes) {
            auto v = makeNode!Variable;
            v.type = ty;
            t.add(v);
        }
        /// Add this Tuple at module scope because we need it to be in the AST
        /// but we don't want it as our own child node
        getModule.add(t);

        return t;
    }

    int numElements() {
        return children.length.as!int;
    }
    Expression[] elements() {
        return cast(Expression[])children[];
    }
    Type[] elementTypes() {
        return elements().map!(it=>it.getType()).array;
    }
    bool allValuesSpecified() {
        assert(isResolved());
        return elements().length == type.getTuple().numMemberVariables();
    }

    override string toString() {
        return "[] %s".format(type);
    }
private:
}