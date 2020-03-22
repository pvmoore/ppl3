module ppl.type.Class;

import ppl.internal;

final class Class : Struct {
private:
protected:
    //LLVMTypeRef _llvmType;
    //int _size      = -1;
    //int _alignment = -1;
    //bool _isPacked = false;
public:
    //string name;
    //string moduleName;
    //Access access = Access.PRIVATE;
    //bool isDeclarationOnly;
    //TemplateBlueprint blueprint;

/// ASTNode interface
    override bool isResolved() { return true; }
    override NodeID id() const { return NodeID.CLASS; }
    override Type getType()    { return this; }

/// Type interface
    override int category() const { return Type.CLASS; }
    override bool isKnown() { return true; }

    override bool exactlyMatches(Type other) {
        /// Do the common checks
        if(!prelimExactlyMatches(this, other)) return false;
        /// Now check the base type
        if(!other.isClass) return false;

        auto right = other.getClass;

        return name==right.name;
    }
    override bool canImplicitlyCastTo(Type other) {
        /// Do the common checks
        if(!prelimCanImplicitlyCastTo(this,other)) return false;

        /// Now check the base type
        if(!other.isClass) return false;

        auto right = other.getClass;

        return name==right.name;
    }
    override LLVMTypeRef getLLVMType() {
        if(!_llvmType) {
            _llvmType = struct_(name);
        }
        return _llvmType;
    }
//===================================================================================
    override bool isPacked() { return false; }
    override bool isPOD() { return false; }



    override string toString() const {
        return "%s".format(name);
    }
}