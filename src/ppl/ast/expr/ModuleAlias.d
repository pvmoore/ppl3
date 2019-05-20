module ppl.ast.expr.ModuleAlias;

import ppl.internal;

final class ModuleAlias : Expression {
    Module mod;
    Import imp;

    override bool isResolved() { return mod.isParsed; }
    override bool isConst() { return true; }
    override NodeID id() const { return NodeID.MODULE_ALIAS; }
    override int priority() const { return 15; }
    override Type getType() { return TYPE_VOID; }

    override CT comptime() { return CT.YES; }

    override string toString() {
        return "ModuleAlias (%s)".format(mod.canonicalName);
    }
}