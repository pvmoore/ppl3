module ppl.ast.expr.Initialiser;

import ppl.internal;

/**
 *  Initialiser
 *      Expression
 */
final class Initialiser : Expression {
private:
    bool astGenerated;
    //LiteralNumber _literal;
public:
    Variable var;

/// ASTNode
    override bool isResolved() { return astGenerated; }
    override NodeID id() const { return NodeID.INITIALISER; }
    override Type getType() {
        assert(var);

        if(var.type.isKnown()) return var.type;
        if(hasChildren() && last().isResolved()) {
            return last().getType();
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
        assert(numChildren()==1);

        convertToAssignment();

        astGenerated = true;
    }

    override string toString() {
        assert(var);
        return "Initialiser var=%s, type=%s".format(var.name, getType());
    }
private:
    ///
    /// Convert:
    ///
    /// Initialiser
    ///     LiteralNumber
    ///
    /// to (for local or global vars):
    ///
    /// Initialiser
    ///     Binary =
    ///         identifier (var.name)
    ///         LiteralNumber
    ///
    /// to (for struct member vars):
    ///
    /// Initialiser
    ///     Binary =
    ///         Dot
    ///             identifier "this"
    ///             identifer (var.name)
    ///         LiteralNumber
    ///
    /// to (for struct static vars):
    ///
    /// Initialiser
    ///     Binary =
    ///         Dot
    ///             TypeExpr (struct)
    ///             identifer (var.name)
    ///         LiteralNumber
    ///
    void convertToAssignment() {
        //_literal = last().as!LiteralNumber;

        auto b = getModule.nodeBuilder;

        Expression left  = b.identifier(var);
        auto right = last().as!Expression;

        if(var.isMember()) {
            if(var.isStatic) {
                assert(var.isStructVar() || var.isClassVar());

                Type nn = var.isStructVar() ? var.getStruct() : var.getClass();
                left = b.dot(b.typeExpr(nn), left);
            } else {
                left = b.dot(b.identifier("this"), left);
            }
        }

        auto assign = b.binary(Operator.ASSIGN, left, right, var.type);
        add(assign);
    }
}