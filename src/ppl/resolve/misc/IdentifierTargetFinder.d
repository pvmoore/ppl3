module ppl.resolve.misc.IdentifierTargetFinder;

import ppl.internal;

final class IdentifierTargetFinder {
private:
    Module module_;
    BuildState state;
public:
    this(Module module_) {
        this.module_ = module_;
        this.state   = module_.buildState;
    }

    VariableOrFunction find(string name, ASTNode node) {
        VariableOrFunction res = null;

        state.log(Logging.ID_TARGET_FINDER, "  %s %s", name, node.id);

        /// Check previous siblings at current level
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res !is null) return res;
        }

        auto p = node.parent;
        if(p.isComposite) p = p.previous();

        /// Recurse up the tree
        findRecurse(name, p, res);

        return res;
    }
private:
    void findRecurse(string name, ASTNode node, ref VariableOrFunction res) {

        isThisIt(name, node, res);
        if(res !is null) return;

        auto nid = node.id();

        switch(nid) with(NodeID) {
            case MODULE:
            case TUPLE:
            case STRUCT:
                /// Check all variables at this level
                foreach(n; node.children) {
                    isThisIt(name, n, res);
                    if(res !is null) return;
                }

                if(nid==MODULE) return;

                /// Go to module scope
                findRecurse(name, node.getModule(), res);
                return;
            case LITERAL_FUNCTION:
                if(!node.as!LiteralFunction.isLambda) {
                    /// Go to containing struct if there is one
                    auto ns = node.getAncestor!Struct();
                    if(ns) {
                        findRecurse(name, ns, res);
                        return;
                    }
                }
                /// Go to module scope
                findRecurse(name, node.getModule(), res);
                return;
            default:
                break;
        }

        /// Check variables that appear before this in the tree
        foreach(n; node.prevSiblings()) {
            isThisIt(name, n, res);
            if(res !is null) return;
        }

        findRecurse(name, node.parent, res);
    }
    void isThisIt(string name, ASTNode n, ref VariableOrFunction res) {

        switch(n.id) with(NodeID) {
            case COMPOSITE:
                switch(n.as!Composite.usage) with(Composite.Usage) {
                    case INNER_KEEP:
                    case INNER_REMOVABLE:
                        /// This scope is indented
                        return;
                    default:
                        /// Treat children as if they were in the same scope
                        foreach(n2; n.children) {
                            isThisIt(name, n2, res);
                            if(res !is null) return;
                        }
                        break;
                }
                break;
            case VARIABLE: {
                auto v = n.as!Variable;
                if(v.name==name) res = v;
                break;
            }
            case PARAMETERS: {
                auto v = n.as!Parameters.getParam(name);
                if(v) res = v;
                break;
            }
            case FUNCTION: {
                auto f = n.as!Function;
                if(f.name==name) {
                    res = f;
                }
                break;
            }
            default:
                break;
        }
    }
}