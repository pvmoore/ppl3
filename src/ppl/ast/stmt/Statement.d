module ppl.ast.stmt.Statement;

import ppl.internal;

abstract class Statement : ASTNode {

    /** True if this Statement is not used and can be removed */
    bool isZombie = false;  // todo - implement me
}