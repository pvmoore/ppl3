module ppl.ast.Placeholder;

import ppl.internal;

///
/// This node is a placeholder for an extracted template function or struct.
/// It will be replace once the extracted template has been parsed.
///
final class Placeholder : ASTNode {

/// ASTNode
    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.PLACEHOLDER; }
    override Type getType()    { return hasChildren() ? first().getType() : TYPE_VOID; }
}