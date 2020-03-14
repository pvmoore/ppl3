module ppl.ast.stmt.Variable;

import ppl.internal;

///
/// variable ::= type identifier [ "=" expression ]
///
/// Possible children: 0, 1 or 2:
///
/// Variable
///     Initialiser
///
final class Variable : Statement {
    Type type;
    string name;
    bool isConst;
    bool isStatic;
    Access access = Access.PRIVATE;

    int numRefs;

    LLVMValueRef llvmValue;

/// ASTNode
    override bool isResolved() { return type.isKnown; }
    override NodeID id() const { return NodeID.VARIABLE; }
    override Type getType()    { return type; }


    bool isLocalAlloc() {
        return !isParameter &&
               !isTupleVar &&
               cast(Type)parent is null &&
               getContainer().id()==NodeID.LITERAL_FUNCTION;
    }

    bool isStructVar() {
        return getLogicalParent().id==NodeID.STRUCT;
    }
    bool isClassVar() {
        return getLogicalParent().id==NodeID.CLASS;
    }
    bool isTupleVar() {
        return getLogicalParent().id==NodeID.TUPLE;
    }

    bool isMember() {
        return getLogicalParent().id.isOneOf(NodeID.TUPLE, NodeID.STRUCT, NodeID.CLASS);
    }
    bool isGlobal() {
        return isAtModuleScope();
    }
    bool isParameter() {
        return parent.isA!Parameters;
    }
    bool isFunctionPtr() {
        return type.isKnown && type.isFunction;
    }


    int getMemberIndex() {
        if(isStructVar() || isClassVar()) return parent.as!Struct.getMemberIndex(this);
        if(isTupleVar()) return parent.as!Tuple.getMemberIndex(this);
        assert(false, "Not a member");
    }

    bool hasInitialiser() {
        return children[].any!(it=>it.isInitialiser);
    }
    Initialiser initialiser() {
        assert(numChildren>0);

        foreach(ch; children) {
            if(ch.isInitialiser) {
                return ch.as!Initialiser;
            }
        }
        assert(false, "Where is our Initialiser?");
    }
    Type initialiserType() {
        return hasInitialiser() ? initialiser().getType() : null;
    }

    Tuple getTuple() {
        assert(parent.isA!Tuple, "parent is not a tuple %s %s %s".format(getModule(), line+1, name));
        return parent.as!Tuple;
    }
    Struct getStruct() {
        assert(parent.isA!Struct, "parent is not a struct %s %s %s".format(getModule(), line+1, name));
        return parent.as!Struct;
    }
    Class getClass() {
        assert(parent.isA!Class, "parent is not a class %s %s %s".format(getModule(), line+1, name));
        return parent.as!Class;
    }
    Statement getFunctionOrLambda() {
        assert(isParameter());
        auto bd = getAncestor!LiteralFunction();
        assert(bd);
        if(bd.isLambda) return bd.getLambda();
        return bd.getFunction();
    }

    void setType(Type t) {
        this.type = t;

        if(first().isA!Type) {
            removeAt(0);
        }
    }

    override string toString() {
        string mod = isStatic ? "static " : "";
        mod ~= isConst ? "const ":"";

        string loc = isParameter  ? "PARAM" :
                     isLocalAlloc ? "LOCAL" :
                     isGlobal     ? "GLOBAL" :
                                    "STRUCT";

        if(name) {
            return "'%s' Variable[refs=%s] (type=%s%s) %s %s".format(name, numRefs, mod, type, loc, access);
        }
        return "Variable[refs=%s] (type=%s%s) %s %s".format(numRefs, mod, type, loc, access);
    }
}