module ppl.ast.expr.Expression;

import ppl.internal;

enum CT { YES, UNRESOLVED, NO }

abstract class Expression : Statement {

    abstract int priority() const;
    abstract CT comptime();

    final bool isStartOfChain() {
        if(!parent.isDot()) return true;
        if(index()!=0) return false;

        return parent.as!Dot.isStartOfChain();
    }
    ///
    /// Get the previous link in the chain. Assumes there is one.
    ///
    final Expression prevLink() {
        if(!parent.isDot()) return null;
        if(isStartOfChain()) return null;

        auto prev = prevSibling();
        if(prev) {
            return prev.as!Expression;
        }
        assert(parent.parent.isDot());
        return parent.parent.as!Dot.left();
    }

    final string comptimeStr() {
        final switch(comptime()) with(CT) {
            case YES        : return "comptime";
            case UNRESOLVED : return "comptime?";
            case NO         : return "not comptime";
        }
        assert(false);
    }

    static CT mergeCT(Expression[] exprs...) {
        CT result = CT.YES;
        foreach(e; exprs) {
            auto ct = e.comptime();
            if(ct==CT.NO) return CT.NO;
            if(ct==CT.UNRESOLVED) result = ct;
        }
        return result;
    }
    static CT mergeCT(CT[] cts...) {
        CT result = CT.YES;
        foreach(ct; cts) {
            if(ct==CT.NO) return CT.NO;
            if(ct==CT.UNRESOLVED) result = ct;
        }
        return result;
    }
}

Call getCall(ASTNode n) {
    if(n.isA!Call) return n.as!Call;
    if(n.isA!ExpressionRef) return getCall(n.as!ExpressionRef.reference);
    return null;
}
Identifier getIdentifier(ASTNode n) {
    if(n.isA!Identifier) return n.as!Identifier;
    if(n.isA!ExpressionRef) return getIdentifier(n.as!ExpressionRef.reference);
    return null;
}