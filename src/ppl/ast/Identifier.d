module ppl.ast.Identifier;

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
            auto lit  = init.getLiteral();

            return lit !is null;
        }
        return r;
    }
    override NodeID id() const { return NodeID.IDENTIFIER; }
    override int priority() const { return 15; }
    override Type getType() { return target.getType(); }

    override string toString(){
        string c = isConst ? "const ":"";
        return "ID:%s (type=%s%s) %s".format(name, c, getType(), target);
    }
}