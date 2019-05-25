module ppl.ast.Continue;

import ppl.internal;

final class Continue : Statement {
    Loop loop;

/// ASTNode
    override bool isResolved() { return loop !is null; }
    override NodeID id() const { return NodeID.CONTINUE; }
    override Type getType()    { return TYPE_VOID; }


    override string toString() {
        return "Continue";
    }
}