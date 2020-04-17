module ppl.ast.expr.Call;

import ppl.internal;

/**
 *  Call
 *      [ args ]
 */
final class Call : Expression {
    string name;
    Target target;
    string[] paramNames;        /// optional. eg. name:value

/// Template stuff
    Type[] templateTypes;       /// optional. eg. func<int,bool>
/// end of template stuff

    bool implicitThisArgAdded;  /// true if 1st arg thisptr has been added

    int numArgs() {
        return numChildren();
    }
    Expression arg(int index) {
        assert(index<numChildren);
        return args()[index];
    }
    Expression[] args() {
        return children[].as!(Expression[]);
    }
    Type[] argTypes() {
        return types(args());
    }
    bool isTemplated() { return templateTypes.length>0 ;}

/// ASTNode
    override bool isResolved() { return target.isResolved; }
    override NodeID id() const { return NodeID.CALL; }
    override Type getType() {
        if(!target.isResolved) return TYPE_UNKNOWN;
        return target.getType().getFunctionType.returnType;
    }
/// Expression
    override int priority() const { return 2; }
    override CT comptime() {
        // todo - the function or function ptr might be comptime
        return CT.NO;
    }

    void addImplicitThisArg(Variable this_) {
        import std.array : insertInPlace;
        assert(this_);
        assert(!implicitThisArgAdded);

        auto b = getModule().nodeBuilder;
        auto id = b.identifier(this_);
        this.insertAt(0, id);

        if(paramNames.length>0) {
            paramNames.insertInPlace(0, "this");
        }

        implicitThisArgAdded = true;
    }

    override string toString() {
        if(target.isResolved){
            return "Call %s %s".format(name, target);
        }
        return "Call %s".format(name);
    }
}