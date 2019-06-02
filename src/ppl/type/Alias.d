module ppl.type.Alias;

import ppl.internal;
/// STANDARD
///     type     = aliased type
///     children = type (if tuple or function)
/// INNER_TYPE
///     type     = start type
///     children = aliases of subsequent types (with templateParams if given)
/// TYPEOF
///     type     = not set
///     children = expression

final class Alias : Statement, Type {
private:
    Kind kind;
public:
    enum Kind : uint {
        STANDARD       = 0,     // alias = type
        TYPEOF         = 1<<0,  // @typeof(expr) alias
        INNER_TYPE     = 1<<1,  // inner type alias eg. type::type
        TEMPLATE_PROXY = 1<<2   // templateParams.length>0
    }
    string name;
    string moduleName;
    bool isImport;
    Access access = Access.PUBLIC;
    Type type;
    Type[] templateParams;

    bool isStandard()      { return kind == Kind.STANDARD; }
    bool isTypeof()        { return (kind & Kind.TYPEOF) != 0; }
    bool isInnerType()     { return (kind & Kind.INNER_TYPE) != 0; }
    bool isTemplateProxy() { return (kind & Kind.TEMPLATE_PROXY) !=0; }

    static Alias make(Tokens t, Kind kind = Kind.STANDARD) {
        auto a = makeNode!Alias(t);
        a.type = TYPE_UNKNOWN;
        a.kind = kind;
        return a;
    }
    static Alias make(ASTNode n, Kind kind = Kind.STANDARD) {
        auto a = makeNode!Alias(n);
        a.type = TYPE_UNKNOWN;
        a.kind = kind;
        return a;
    }
    void convertToStandard() {
        this.kind = Kind.STANDARD;
    }
    void setTemplateParams(Type[] p) {
        if(p) {
            this.templateParams = p;
            this.kind |= Kind.TEMPLATE_PROXY;
        }
    }

/// ASTNode
    override bool isResolved() { return false; }
    override NodeID id() const { return NodeID.ALIAS; }
    override Type getType()    { return type; }

/// Type
    final int category() const { return type.category(); }
    final bool isKnown()       { return false; }

    bool exactlyMatches(Type other)      { assert(false); }
    bool canImplicitlyCastTo(Type other) { assert(false); }
    LLVMTypeRef getLLVMType()            { assert(false); }

    override string toString() {
        string tt = templateParams ? "<%s>".format(templateParams.toString) : "";
        if(isInnerType) {
            return "alias inner (%s:: '%s'%s)".format(type, name, tt);
        }
        if(isTypeof) {
            return "@typeOf(%s%s)".format(type, tt);
        }
        return "alias '%s' = %s%s".format(name, type, tt);
    }
}
