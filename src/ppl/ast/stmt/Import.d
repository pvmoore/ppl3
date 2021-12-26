module ppl.ast.stmt.Import;

import ppl.internal;

/**
 *  Import
 */
final class Import : Statement {
    string aliasName;   /// eg. cc
    string moduleName;  /// eg. core::c
    Module mod;

/// ASTNode
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.IMPORT; }
    override Type getType()    { return TYPE_VOID; }


    bool hasAliasName() { return aliasName !is null; }

    bool hasFunction(string name) {
        return children[].filter!(it=>it.id==NodeID.FUNCTION)
                         .map!(it=>cast(Function)it)
                         .any!(it=>it.name==name);
    }
    Function[] getFunctions(string name) {
        return children[].filter!(it=>it.id==NodeID.FUNCTION)
                         .map!(it=>cast(Function)it)
                         .filter!(it=>it.name==name)
                         .array;
    }
    Alias getAlias(string name) {
        foreach(c; children) {
            if(!c.isAlias()) continue;
            auto a = c.as!Alias;
            if(a.name==name) return a;
        }
        return null;
    }

    override string toString() {
        string n = hasAliasName() ? ("'"~aliasName~"' ") : "";

        return "Import %s%s".format(n, moduleName);
    }
}