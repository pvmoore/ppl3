module ppl.ast.expr.Expression;

import ppl.internal;

enum CT { YES, UNRESOLVED, NO }

abstract class Expression : Statement {

    abstract int priority() const;

    CT comptime() { return CT.NO; }

    // todo - remove this in favour of comptime(). Keep for Variable
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