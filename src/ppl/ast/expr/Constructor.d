module ppl.ast.expr.Constructor;

import ppl.internal;

/**
 * AFTER PARSE :
 *
 *  Constructor
 *      Call new
 *          { args }
 *
 * AFTER RESOLVE :
 *
 * Constructor type = S or type = S*
 *    Variable _temp (type=S or S*)
 *    _temp = calloc    // if ptr
 *    Dot
 *       _temp
 *       Call new
 *          _temp | addressof(_temp)
 *          [ args ]                    // if non-POD
 *    _temp.name = arg                  // for each arg if POD
 *    _temp
 */
final class Constructor : Expression {
    Type type;               /// Struct/Class (or Alias resolved to Struct/Class)
    bool isRewritten = false;

/// ASTNode
    override bool isResolved() { return isRewritten && type.isKnown(); }
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
        return (type.isStructOrClass()) ? type.getStruct().name : type.getAlias().name;
    }
    override string toString() {
        return "Constructor %s%s".format(getName(), type.isPtr() ? "*":"");
    }
}