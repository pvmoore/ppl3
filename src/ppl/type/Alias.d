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

public:
    string name;
    string moduleName;
    bool isImport;
    Access access = Access.PUBLIC;
    Type type;
    Type[] templateParams;

    bool isTypeof;      /// true if this is a @typeof(expr) alias
    bool isInnerType;   /// true if this is an inner type alias eg. type::type

    this() {
        type = TYPE_UNKNOWN;
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

    bool isStandard()      { return !isTypeof && !isInnerType && !isTemplateProxy(); }
    bool isTemplateProxy() { return templateParams.length>0; }

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
