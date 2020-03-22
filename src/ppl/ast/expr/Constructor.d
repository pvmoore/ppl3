module ppl.ast.expr.Constructor;

import ppl.internal;

/// S(...)
///    Variable _temp (type=S)
///    Dot
///       _temp
///       Call new
///          addressof(_temp)
///    _temp

/// S*(...)
///    Variable _temp (type=S*)
///    _temp = calloc
///    Dot
///       _temp
///       Call new
///          _temp
///    _temp
///
final class Constructor : Expression {
    Type type;               /// Struct (or Alias resolved to Struct)

/// ASTNode
    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.CONSTRUCTOR; }
    override Type getType()    { return type; }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime() {
        // todo - this might be made comptime
        return CT.NO;
    }


    string getName() {
        return (type.isStruct() || type.isClass()) ? type.getStruct.name : type.getAlias.name;
    }
    override string toString() {
        return "Constructor %s%s".format(getName(), type.isPtr ? "*":"");
    }
}