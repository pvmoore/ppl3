module ppl.ast.expr.Identifier;

import ppl.internal;

final class Identifier : Expression {
    string name;
    Target target;

    override bool isResolved() { return target.isResolved; }
    override bool isConst() {

        /// variable must have resolved initialiser which is a LiteralNumber or LiteralNull

        bool r = target.isResolved &&
                 target.isVariable &&
                 target.getVariable.isConst;

        if(r) {
            auto init = target.getVariable.initialiser();
            auto lit  = init.getExpr();

            return lit !is null;
        }
        return r;
    }
    override NodeID id() const { return NodeID.IDENTIFIER; }
    override int priority() const { return 15; }
    override Type getType() { return target.getType(); }

    override CT comptime() {

        if(!isResolved) return CT.UNRESOLVED;

        if(target.isVariable) {
            auto var = target.getVariable;
            if(var.isConst) {
                return var.initialiser().getExpr().comptime();
            }
        } else {
            // todo - function ptr
        }

        return CT.NO;
    }

    override string toString(){
        string c = isConst() ? "const ":"";
        return "ID:%s (type=%s%s) %s".format(name, c, getType(), target);
    }
}