module ppl.ast.stmt.Break;

import ppl.internal;

/**
 *  Break
 */
final class Break : Statement {
    Loop loop;

/// ASTNode
    override bool isResolved() { return loop !is null; }
    override NodeID id() const { return NodeID.BREAK; }
    override Type getType()    { return TYPE_VOID; }


    override string toString() {
        return "Break";
    }
}