module ppl.eval.EvalBinaryUnary;

import ppl.internal;

final class EvalBinaryUnary {
private:
    ResolveModule resolver;
    Module mod;
    NodeBuilder nodeBuilder;
    FoldUnreferenced folder;
public:
    this(ResolveModule resolver) {
        this.resolver = resolver;
        this.folder = resolver.foldUnreferenced;
        this.mod = resolver.module_;
        this.nodeBuilder = mod.nodeBuilder;
    }

    void eval(Unary u) {
        // todo - check types before getting here. bool_not and bit_not cannot be applied to
        //        float/double. maybe auto convert them to integers first.
        //        Also, should we auto promote to int here?

        LiteralNumber lit = u.expr().as!LiteralNumber;

        // Cannot evaluate
        if(lit is null) return;

        Operator op = u.op;

        Type type = lit.getType();
        string result;

        switch(op.id) with(Operator) {
            case BOOL_NOT.id:
                result = getBool(lit) ? FALSE_STR : TRUE_STR;
                break;
            case BIT_NOT.id:
                if(type.isInt()) result = (~getInt(lit)).to!string;
                else result = (~getLong(lit)).to!string;
                break;
            case NEG.id:
                if(type.isFloat()) result = (-getFloat(lit)).to!string;
                else if(type.isDouble()) result = (-getDouble(lit)).to!string;
                else if(type.isInt()) result = (-getInt(lit)).to!string;
                else result = (-getLong(lit)).to!string;
                break;
            default:
                assert(false);
        }

        // Replace Unary with LiteralNumber result
        auto lit2 = nodeBuilder.makeNumber(result, u.getType());
        folder.fold(u, lit2);
    }

    void eval(Binary binary) {
        LiteralNumber leftLiteral = binary.left().as!LiteralNumber;
        LiteralNumber rightLiteral = binary.right().as!LiteralNumber;

        // Cannot evaluate
        if(leftLiteral is null || rightLiteral is null) return;

        auto resultType = binary.getType();
        auto op = binary.op;

        auto leftType = leftLiteral.getType();
        auto rightType = rightLiteral.getType();

        string result;
        Type operandType =
            (op == Operator.BOOL_AND || op == Operator.BOOL_OR) ? TYPE_BOOL
            : getBestFit(leftType, rightType);

        // Promote to int
        if(operandType.isInteger() && operandType.size() < 4) {
            operandType = TYPE_INT;
        }

        assert(operandType !is null, "Operand type is null (%s, %s)".format(leftType, rightType));

        if(operandType.isBool()) {
            result = apply(getBool(leftLiteral), getBool(rightLiteral), op);
        } else if(operandType.isLong()) {
            result = apply(getLong(leftLiteral), getLong(rightLiteral), op);
        } else if(operandType.isInt()) {
            result = apply(getInt(leftLiteral), getInt(rightLiteral), op);
        } else if(operandType.isFloat()) {
            result = apply(getFloat(leftLiteral), getFloat(rightLiteral), op);
        } else if(operandType.isDouble()) {
            result = apply(getDouble(leftLiteral), getDouble(rightLiteral), op);
        } else assert(false, "Unsupported calculation %s %s %s".format(leftLiteral, rightLiteral, op));

        // Replave Binary with LiteralNumber result
        auto lit = nodeBuilder.makeNumber(result, resultType);
        folder.fold(binary, lit);
    }
private:
    string apply(T)(T left, T right, Operator op)
        if(is(T==bool) || is(T==int) || is(T==long) || is(T==float) || is(T==double))
    {
        T result;
        switch(op.id) with(Operator) {

        static if(is(T==bool)) {
            case BOOL_AND.id: result = (left && right); break;
            case BOOL_OR.id:  result = (left || right); break;
        } else {
            case DIV.id: result = left / right; break;
            case MUL.id: result = left * right; break;
            case MOD.id: result = left % right; break;
            case ADD.id: result = left + right; break;
            case SUB.id: result = left - right; break;

            case LT.id:      result = (left <  right) ? TRUE : FALSE; break;
            case GT.id:      result = (left >  right) ? TRUE : FALSE; break;
            case LTE.id:     result = (left <= right) ? TRUE : FALSE; break;
            case GTE.id:     result = (left >= right) ? TRUE : FALSE; break;
            case BOOL_EQ.id: result = (left == right) ? TRUE : FALSE; break;
            case BOOL_NE.id: result = (left != right) ? TRUE : FALSE; break;
        }

        static if(is(T==int) || is(T==long)) {
            case SHL.id: result = (left << right); break;
            case SHR.id: result = (left >> right); break;
            case USHR.id:
                static if(is(T==int)) {
                    result = (left.as!uint >>> right);
                } else {
                    result = (left.as!ulong >>> right);
                }
                break;
            case BIT_AND.id: result = (left & right); break;
            case BIT_XOR.id: result = (left ^ right); break;
            case BIT_OR.id:  result = (left | right); break;
        }
            default: assert(false, "Unsupported op %s".format(op));
        }

        return result.to!string;
    }

    bool getBool(LiteralNumber n) {
        if(n.type().isReal()) {
            return getDouble(n) != 0;
        }
        return getLong(n) != 0;
    }
    int getInt(LiteralNumber n) {
        if(n.type().isReal()) {
            return n.str.to!double.as!int;
        }
        return n.str.to!int;
    }
    long getLong(LiteralNumber n) {
        if(n.type().isReal()) {
            return n.str.to!double.as!long;
        }
        return n.str.to!long;
    }
    float getFloat(LiteralNumber n) {
        return n.str.to!float;
    }
    double getDouble(LiteralNumber n) {
        return n.str.to!double;
    }
}