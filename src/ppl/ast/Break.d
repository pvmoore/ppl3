module ppl.ast.Break;

import ppl.internal;

final class Break : Statement {
    Loop loop;

/// ASTNode
    override bool isResolved() { return loop !is null; }
    override NodeID id() const { return NodeID.BREAK; }
///

    override string toString() {
        return "Break";
    }
}