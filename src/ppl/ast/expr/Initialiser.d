module ppl.ast.expr.Initialiser;

import ppl.internal;
///
/// Variable initialiser.
///
final class Initialiser : Expression {
private:
    bool astGenerated;
    LiteralNumber _literal;
public:
    Variable var;

/// ASTNode
    override bool isResolved() { return astGenerated; }
    override NodeID id() const { return NodeID.INITIALISER; }
    override Type getType() {
        assert(var);

        if(var.type.isKnown) return var.type;
        if(hasChildren && last().isResolved) {
            return last().getType;
        }
        return TYPE_UNKNOWN;
    }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime() {
        return getExpr().comptime();
    }


    Expression getExpr() {
        if(astGenerated) {
            auto b = last().as!Binary;
            assert(b);
            return b.right();
        } else {
            return last().as!Expression;
        }
    }

    void resolve() {
        assert(var);
        if(astGenerated) return;
        if(!areResolved(children[])) return;

        /// Generate initialisation AST for our parent Variable
        assert(numChildren==1);

        convertToAssignment();

        astGenerated = true;
    }

    override string toString() {
        assert(var);
        return "Initialiser var=%s, type=%s".format(var.name, getType);
    }
private:
    void convertToAssignment() {
        _literal = last().as!LiteralNumber;
        auto b      = getModule.builder(var);
        auto assign = b.binary(Operator.ASSIGN, b.identifier(var), last().as!Expression, var.type);
        add(assign);
    }
}