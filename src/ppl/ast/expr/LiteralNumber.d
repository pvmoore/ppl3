module ppl.ast.expr.LiteralNumber;

import ppl.internal;

final class LiteralNumber : Expression, CompileTimeConstant {
private:
    Type _type;
public:
    string str;
    Value value;

    this() {
        _type = TYPE_UNKNOWN;
    }

    Type type() {
        return _type;
    }

    void setType(Type t) {
        value.changeType(_type, t);
        _type = t;
    }

    static LiteralNumber makeConst(long num, Type t=TYPE_UNKNOWN) {
        auto lit  = makeNode!LiteralNumber;
        lit.str   = num.to!string;
        lit._type = t;
        if(t.isUnknown) {
            lit.determineType();
        } else {
            lit. value = Value(lit);
        }
        return lit;
    }
    /// <CompileTimeConstant>
    LiteralNumber copy() {
        auto c   = makeNode!LiteralNumber(this);
        c.line   = line;
        c.column = column;
        c.str    = str;
        c._type  = _type;
        c.value  = Value(c);
        return c;
    }
    bool isTrue() {
        return value.getBool() == true;
    }

/// ASTNode
    override bool isResolved()    { return _type.isKnown; }
    override NodeID id() const    { return NodeID.LITERAL_NUMBER; }
    override Type getType()       { return _type; }

/// Expression
    override int priority() const { return 15; }
    override CT comptime()        { return CT.YES; }


    void determineType() {
        From!"std.typecons".Tuple!(Type,string) r = parseNumberLiteral(str);
        _type  = r[0];
        str    = r[1];
        value  = Value(this);
    }
    override string toString() {
        string v = value.getString();
        //string v = value.lit && value.type && value.type.isKnown ? value.getString() : str;
        return "%s (type=const %s)".format(v, _type);
    }
}
//============================================================================================
struct Value {
    union {
        double f;
        long i;
    }
    LiteralNumber lit;

    this(LiteralNumber lit) {
        assert(lit);
        this.lit = lit;
        if(type().isBool) {
            i = lit.str.to!long == 0 ? FALSE : TRUE;
        } else if(type().isInteger) {
            i = lit.str.to!long;
        } else if(type().isReal) {
            f = lit.str.to!double;
        } else assert(false, "How did we get here? type is %s".format(type()));
    }
    void changeType(Type from, Type to) {
        if(to.isBool) {
            i = getLong() == 0 ? FALSE : TRUE;
        } else if(from.isReal && to.isInteger) {
            i = cast(long)f;
        } else if(from.isInteger && to.isReal) {
            f = cast(double)i;
        }
    }
    Type type()        { return lit._type; }
    bool getBool()     { return getLong() != FALSE; }
    int getInt()       { return cast(int)getLong(); }
    long getLong()     { if(type.isReal) return cast(long)f; return i; }
    double getDouble() { if(!type.isReal) return cast(double)i; return f; }
    string getString() { return type.isReal ? "%f".format(getDouble()) : "%s".format(getLong()); }

    bool applyUnary(Operator op) {

        switch(op.id) with(Operator) {
            case BOOL_NOT.id:
                if(type.isReal) return false;
                i = ~getLong();
                break;
            case BIT_NOT.id:
                if(type.isReal) return false;
                i = ~getLong();
                break;
            case NEG.id:
                if(type.isReal) {
                    f = -getDouble();
                } else {
                    i = -getLong();
                }
                break;
            default:
                return false;
        }
        return true;
    }

    /// return true if the operation was performed
    bool applyBinary(Type resultType, Operator op, Value right) {

        Type calcType = getBestFit(type, right.type);
        lit.setType(calcType);

        if(calcType.isInteger || calcType.isBool) {
            switch(op.id) with(Operator) {
                case DIV.id: i = getLong() / right.getLong(); break;
                case MUL.id: i = getLong() * right.getLong(); break;
                case MOD.id: i = getLong() % right.getLong(); break;
                case ADD.id: i = getLong() + right.getLong(); break;
                case SUB.id: i = getLong() - right.getLong(); break;

                case SHL.id: i  = getLong() << right.getLong(); break;
                case SHR.id:
                    switch(type.category) with(Type) {
                        case BYTE:  i = cast(byte) ((getLong() | 0xffffffff_ffffff00) >> right.getInt()); break;
                        case SHORT: i = cast(short)((getLong() | 0xffffffff_ffff0000) >> right.getInt()); break;
                        case INT:   i = cast(int)  ((getLong() | 0xffffffff_00000000) >> right.getInt()); break;
                        default:    i = getLong() >> right.getInt(); break;
                    }
                    break;
                case USHR.id:
                    switch(type.category) with(Type) {
                        case BYTE:  i = cast(ubyte) ((getLong() & 0xff)       >> right.getInt()); break;
                        case SHORT: i = cast(ushort)((getLong() & 0xffff)     >> right.getInt()); break;
                        case INT:   i = cast(uint)  ((getLong() & 0xffffffff) >> right.getInt()); break;
                        default:    i = cast(ulong) getLong() >>> right.getInt();
                    }
                    break;

                case LT.id:      i = (getLong() < right.getLong())  ? TRUE : FALSE; break;
                case GT.id:      i = (getLong() > right.getLong())  ? TRUE : FALSE; break;
                case LTE.id:     i = (getLong() <= right.getLong()) ? TRUE : FALSE; break;
                case GTE.id:     i = (getLong() >= right.getLong()) ? TRUE : FALSE; break;
                case BOOL_EQ.id: i = (getLong() == right.getLong()) ? TRUE : FALSE; break;
                case BOOL_NE.id: i = (getLong() != right.getLong()) ? TRUE : FALSE; break;

                case BIT_AND.id: i = getLong() & right.getLong(); break;
                case BIT_XOR.id: i = getLong() ^ right.getLong(); break;
                case BIT_OR.id:  i = getLong() | right.getLong(); break;

                case BOOL_AND.id: i = getBool() && right.getBool(); break;
                case BOOL_OR.id:  i = getBool() || right.getBool(); break;

                default: assert(false, "How did we get here? %s".format(op));
            }
        } else {
            switch (op.id) with(Operator) {
                case DIV.id: f = getDouble() / right.getDouble(); break;
                case MUL.id: f = getDouble() * right.getDouble(); break;
                case MOD.id: f = getDouble() % right.getDouble(); break;
                case ADD.id: f = getDouble() + right.getDouble(); break;
                case SUB.id: f = getDouble() - right.getDouble(); break;


                //case SHL.id:  f = getLong() << right.getLong(); break;
                //case SHR.id:
                //    /// special case
                //    switch(type.category) with(Type) {
                //        case BYTE:  f = cast(byte) (getLong()|0xffffffff_ffffff00) >> right.getInt(); break;
                //        case SHORT: f = cast(short)(getLong()|0xffffffff_ffff0000) >> right.getInt(); break;
                //        case INT:   f = cast(long) (getLong()|0xffffffff_00000000) >> right.getInt(); break;
                //        default:    f = cast(long)getLong() >> right.getInt(); break;
                //    }
                //    break;
                //case USHR.id: f = cast(ulong)getLong() >>> right.getLong(); break;

                case LT.id:      f = (getDouble() < right.getDouble())  ? TRUE : FALSE; break;
                case GT.id:      f = (getDouble() > right.getDouble())  ? TRUE : FALSE; break;
                case LTE.id:     f = (getDouble() <= right.getDouble()) ? TRUE : FALSE; break;
                case GTE.id:     f = (getDouble() >= right.getDouble()) ? TRUE : FALSE; break;
                case BOOL_EQ.id: f = (getDouble() == right.getDouble()) ? TRUE : FALSE; break;
                case BOOL_NE.id: f = (getDouble() != right.getDouble()) ? TRUE : FALSE; break;

                //case BIT_AND.id: f = (cast(ulong)getLong() & right.getLong()); break;
                //case BIT_XOR.id: f = (cast(ulong)getLong() ^ right.getLong()); break;
                //case BIT_OR.id:  f = (cast(ulong)getLong() | right.getLong()); break;

                //case BOOL_AND.id: f = getBool() && right.getBool(); break;
                //case BOOL_OR.id:  f = getBool() || right.getBool(); break;

                default:
                    /// Nope
                    return false;
            }
        }
        lit.setType(resultType);
        return true;
    }
    void as(Type t) {
        switch(t.category) with(Type) {
            case BOOL:  i = getLong() == 0 ? FALSE : TRUE; break;
            case BYTE:  i = cast(byte)getLong(); break;
            case SHORT: i = cast(short)getLong(); break;
            case INT:   i = cast(int)getLong(); break;
            case LONG:  i = cast(long)getLong(); break;
            case HALF:
            case FLOAT:
            case DOUBLE: f = getDouble(); break;
            default:
                assert(false, "How did we get here?");
        }
        /// Just set the type because we have handled the cast
        lit._type = t;
    }
}
