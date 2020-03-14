module ppl.type.IType;

import ppl.internal;

interface Type {
    /// Category
    enum : int {
        UNKNOWN = 0,
        BOOL, BYTE, SHORT, INT, LONG, HALF, FLOAT, DOUBLE,
        VOID,
        /// All lower than STRUCT are BasicTypes
        STRUCT,
        CLASS,
        TUPLE,
        ENUM,
        ARRAY,
        FUNCTION
    }
/// Override these
    int category() const;
    bool isKnown();
    bool exactlyMatches(Type other);
    bool canImplicitlyCastTo(Type other);
    LLVMTypeRef getLLVMType();
///
    //-------------------------------------
    final bool isFloat() const    { return category()==FLOAT; }
    final bool isDouble() const   { return category()==DOUBLE; }
    final bool isInt() const      { return category()==INT; }
    final bool isLong() const     { return category()==LONG; }
    final bool isPtr() const      { return this.isA!Pointer; }
    final bool isValue() const    { return !isPtr; }
    final bool isUnknown()        { return !isKnown(); }
    final bool isVoid() const     { return category()==VOID; }
    final bool isBool() const     { return category()==BOOL; }
    final bool isReal() const     { int e = category(); return e==HALF || e==FLOAT || e==DOUBLE; }
    final bool isInteger() const  { int e = category(); return e==BYTE || e==SHORT || e==INT || e==LONG; }
    final bool isBasicType()      { return category() <= VOID && category()!=UNKNOWN; }
    final bool isStruct() const   { return category()==STRUCT; }
    final bool isClass() const    { return category()==CLASS; }
    final bool isArray() const    { return category()==ARRAY; }
    final bool isEnum() const     { return category()==ENUM; }
    final bool isFunction() const { return category()==FUNCTION; }
    final bool isTuple() const    { return category()==TUPLE; }

    final bool isAlias() const {
        if(this.as!Alias !is null) return true;
        auto ptr = this.as!Pointer;
        return ptr && ptr.decoratedType.isAlias;
    }

    final getBasicType() {
        auto basic = this.as!BasicType; if(basic) return basic;
        auto def   = this.as!Alias;     if(def) return def.type.getBasicType;
        auto ptr   = this.as!Pointer;   if(ptr) return ptr.decoratedType().getBasicType;
        return null;
    }
    final Alias getAlias() {
        auto alias_ = this.as!Alias;   if(alias_) return alias_;
        auto ptr    = this.as!Pointer; if(ptr) return ptr.decoratedType().getAlias;
        return null;
    }
    final Enum getEnum() {
        auto e   = this.as!Enum;    if(e) return e;
        auto ptr = this.as!Pointer; if(ptr) return ptr.decoratedType().getEnum();
        return null;
    }
    final FunctionType getFunctionType() {
        if(category != Type.FUNCTION) return null;
        auto f      = this.as!FunctionType; if(f) return f;
        auto alias_ = this.as!Alias;        if(alias_) return alias_.type.getFunctionType;
        auto ptr    = this.as!Pointer;      if(ptr) return ptr.decoratedType().getFunctionType;
        assert(false, "How did we get here?");
    }
    final Struct getStruct() {
        if(!isStruct) return null;
        auto ns     = this.as!Struct;      if(ns) return ns;
        auto alias_ = this.as!Alias;       if(alias_) return alias_.type.getStruct;
        auto ptr    = this.as!Pointer;     if(ptr) return ptr.decoratedType.getStruct;
        assert(false, "How did we get here?");
    }
    final Class getClass() {
        if(!isClass) return null;
        auto ns     = this.as!Class;       if(ns) return ns;
        auto alias_ = this.as!Alias;       if(alias_) return alias_.type.getClass;
        auto ptr    = this.as!Pointer;     if(ptr) return ptr.decoratedType.getClass;
        assert(false, "How did we get here?");
    }
    final Tuple getTuple() {
        if(!isTuple) return null;
        auto st     = this.as!Tuple;      if(st) return st;
        auto alias_ = this.as!Alias;      if(alias_) return alias_.type.getTuple;
        auto ptr    = this.as!Pointer;    if(ptr) return ptr.decoratedType.getTuple;
        assert(false, "How did we get here?");
    }
    final Array getArrayType() {
        if(category != Type.ARRAY) return null;
        auto a      = this.as!Array; if(a) return a;
        auto alias_ = this.as!Alias;     if(alias_) return alias_.type.getArrayType;
        auto ptr    = this.as!Pointer;   if(ptr) return ptr.decoratedType().getArrayType;
        assert(false, "How did we get here?");
    }
    /// Return the non pointer version of this type
    final Type getValueType() {
        auto ptr = this.as!Pointer; if(ptr) return ptr.decoratedType;
        return this;
    }
    final int getPtrDepth() {
        if(this.isPtr) return this.as!Pointer.getPtrDepth;
        return 0;
    }
}
