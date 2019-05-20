module ppl.ast.expr.ModuleAlias;

import ppl.internal;

final class ModuleAlias : Expression {
    Module mod;
    Import imp;

/// ASTNode
    override bool isResolved()    { return mod.isParsed; }
    override NodeID id() const    { return NodeID.MODULE_ALIAS; }
    override Type getType()       { return TYPE_VOID; }

/// Expression
    override int priority() const { return 15; }
    override CT comptime()        { return CT.YES; }


    override string toString() {
        return "ModuleAlias (%s)".format(mod.canonicalName);
    }
}