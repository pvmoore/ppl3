module ppl.ast.stmt.Loop;

import ppl.internal;

/**
 * Loop
 *    Composite init_stmts   // 0 or more
 *    Composite cond_expr    // 0 or 1
 *    Composite post_exprs   // 0 or more
 *    Composite body_stmts   // 0 or more
 *
 * While loop:
 *
 * loop_expr  ::= "loop" "(" init_stmts ";" cond_expr ";" post_exprs ")" "{" { body_stmts } "}"
 * init_exprs ::= [ statement { "," statement } ]
 * post_exprs ::= [ expression { "," expression } ]
 *
 */
final class Loop : Statement {

    LLVMBasicBlockRef continueBB;
    LLVMBasicBlockRef breakBB;

/// ASTNode
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.LOOP; }
    override Type getType()    { return TYPE_VOID; }


    Composite initStmts() { return children[0].as!Composite; }
    Composite condExpr()  { return children[1].as!Composite; }
    Composite postExprs() { return children[2].as!Composite; }
    Composite bodyStmts() { return children[3].as!Composite; }

    bool hasInitStmts() { return initStmts().hasChildren(); }
    bool hasCondExpr()  { return condExpr().hasChildren(); }
    bool hasBodyStmts() { return bodyStmts().hasChildren(); }
    bool hasPostExprs() { return postExprs().hasChildren(); }

    override string toString() {
        return "Loop";
    }
}