module ppl.ast.expr.LiteralString;

import ppl.internal;
///
/// string ::= prefix '"' text '"'
/// prefix ::= nothing | "r" | "f" | "rf" | "fr"
///
/// All string literals are utf8 (logical length may be different to physical length)
///
/// r - regex string with no escapes eg. r"\bregex\w"
/// f - formatted string
///
/**
 *  LiteralString
 */
class LiteralString : Expression {
protected:
    LLVMValueRef  _llvmValue;
    LiteralString _original;
public:
    enum Encoding { UNKNOWN, UTF8, REGEX }

    Type type;
    string value;
    Encoding enc = Encoding.UNKNOWN;

    LLVMValueRef llvmValue() {
        if(_original) return _original._llvmValue;
        return _llvmValue;
    }
    void llvmValue(LLVMValueRef v) {
        _llvmValue = v;
    }

    this() {
        type = Pointer.of(new BasicType(Type.BYTE), 1);
        enc  = Encoding.UNKNOWN;
    }
    LiteralString copy() {
        auto c      = new LiteralString;
        c.line      = line;
        c.column    = column;
        c.nid       = nid;

        c.type      = type;
        c.value     = value;
        c.enc       = enc;
        c._original = _original ? _original : this;
        return c;
    }

/// ASTNode
    override bool isResolved()    { return type.isKnown(); }
    override NodeID id() const    { return NodeID.LITERAL_STRING; }
    override Type getType()       { return type; }

/// Expression
    override int priority() const {
        return 15;
    }
    override CT comptime()        {
        // todo - this probably should be comptime since we know what it is at compile time
        return CT.NO;
    }


    ///
    /// Fixme. These counts are probably wrong.
    ///
    int calculateLength() {
        final switch(enc) with(Encoding) {
            case UNKNOWN: assert(false);
            case UTF8: return value.length.as!int;
            case REGEX:  return value.length.as!int;
        }
    }

    override string toString() {
        string e = enc==Encoding.REGEX ? "r" : "";
        return "String: %s\"%s\" (type=%s)".format(e, value, type);
    }
}
