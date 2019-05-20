module ppl.ast.expr.Expression;

import ppl.internal;

enum CT { YES, UNRESOLVED, NO }

CT mergeCT(Expression[] exprs...) {
    CT result = CT.YES;
    foreach(e; exprs) {
        auto ct = e.comptime();
        if(ct==CT.NO) return CT.NO;
        if(ct==CT.UNRESOLVED) result = ct;
    }
    return result;
}
CT mergeCT(CT[] cts...) {
    CT result = CT.YES;
    foreach(ct; cts) {
        if(ct==CT.NO) return CT.NO;
        if(ct==CT.UNRESOLVED) result = ct;
    }
    return result;
}

abstract class Expression : Statement {

    abstract int priority() const;
    abstract CT comptime();

    // todo - remove this in favour of comptime()
    bool isConst() { return false; }


    bool isStartOfChain() {
        if(!parent.isDot) return true;
        if(index()!=0) return false;

        return parent.as!Dot.isStartOfChain();
    }
    ///
    /// Get the previous link in the chain. Assumes there is one.
    ///
    Expression prevLink() {
        if(!parent.isDot) return null;
        if(isStartOfChain()) return null;

        auto prev = prevSibling();
        if(prev) {
            return prev.as!Expression;
        }
        assert(parent.parent.isDot);
        return parent.parent.as!Dot.left();
    }
}