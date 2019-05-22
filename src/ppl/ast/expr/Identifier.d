module ppl.ast.expr.Identifier;

import ppl.internal;

final class Identifier : Expression {
    string name;
    Target target;

/// ASTNode
    override bool isResolved() { return target.isResolved; }
    override NodeID id() const { return NodeID.IDENTIFIER; }
    override Type getType() { return target.getType(); }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime() {

        if(!isResolved) return CT.UNRESOLVED;

        if(target.isVariable) {
            auto var = target.getVariable;
            if(var.isConst) {
                return var.initialiser().getExpr().comptime();
            }
        } else {
            // todo - function ptr could be comptime
        }

        return CT.NO;
    }


    override string toString(){
        return "ID:%s (type=%s) [%s] %s".format(name, getType(), comptimeStr(), target);
    }
}