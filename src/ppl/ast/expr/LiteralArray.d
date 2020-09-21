module ppl.ast.expr.LiteralArray;

import ppl.internal;
///
/// literal_array  ::= "[" init_expr { "," init_expr } "]"
/// init_expr ::= [digits"="] expression | [digits"="] expression
///
/// LiteralArray
///     expr
///     expr etc...
final class LiteralArray : Expression {
    Array type;

    this() {
        type         = makeNode!Array;
        type.subtype = TYPE_UNKNOWN;
        type.add(LiteralNumber.makeConst(0, TYPE_INT));
    }

/// ASTNode
    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.LITERAL_ARRAY; }
    override Type getType() { return type; }

/// Expression
    override int priority() const { return 15; }
    override CT comptime() {
        // todo - this might be comptime
        return CT.NO;
    }


    int length() {
        return children.length.as!int;
    }

    string generateName() {
        string name = "literal_array";
        ASTNode node = parent;
        while(node) {
            if(node.id==NodeID.VARIABLE) {
                name ~= "_for_" ~ node.as!Variable.name;
                break;
            } else if(node.id==NodeID.IDENTIFIER) {
                name ~= "_for_" ~ node.as!Identifier.name;
                break;
            } else if(node.id==NodeID.LITERAL_FUNCTION) {
                break;
            }
            node = node.parent;
        }
        return name;
    }

    Expression[] elementValues() {
        return cast(Expression[])children[];
    }
    Type[] elementTypes() {
        return elementValues().map!(it=>it.getType).array;
    }

    override string toString() {
        return "[array] %s".format(type);
    }
private:
    int calculateCount() {
        return numChildren;
    }
    ///
    /// Get the largest type of all elements.
    /// If there is no super type then return null
    ///
    Type calculateCommonElementType() {
        if(numChildren==0) return TYPE_UNKNOWN;

        auto et = elementTypes();

        Type t = et[0];
        if(et.length==1) return t;

        foreach(e; et[1..$]) {
            t = getBestFit(t, e);
            if(t is null) {
                getModule.addError(this,"Array has no common type", true);
            }
        }
        return t;
    }
}