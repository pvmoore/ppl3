module ppl.Target;

import ppl.internal;
///
/// Call or Identifier target.
///
final class Target {
private:
    enum TargetType { NOTSET, FUNC, VAR, STRUCTVAR, STRUCTFUNC }

    Module module_;
    TargetType ttype;
    Variable var;
    Function func;
public:
    bool isSet = false;
    Module targetModule;

    this(Module module_) {
        this.module_ = module_;
    }

    void set(Variable v) {
        assert(v, "Variable should not be null");
        if(isSet && v==var) return;
        if(isSet) removeRef();
        this.isSet        = true;
        this.ttype        = v.isMember() && !v.isStatic ? TargetType.STRUCTVAR : TargetType.VAR;
        this.var          = v;
        this.targetModule = v.getModule;
        assert(targetModule);
        addRef();
    }
    void set(Function f) {
        assert(f, "Function should not be null");
        if(isSet && f==func) return;
        if(isSet) removeRef();
        this.isSet        = true;
        this.ttype        = f.isMember() && !f.isStatic ? TargetType.STRUCTFUNC : TargetType.FUNC;
        this.func         = f;
        this.targetModule = f.getModule;
        assert(targetModule);
        addRef();
    }
    //===========================================================
    void dereference() {
        if(isSet) {
            removeRef();
            isSet = false;
            var   = null;
            func  = null;
            ttype = TargetType.NOTSET;
        }
    }
    bool isResolved() {
        if(!isSet) return false;
        if(func) return func.getType.isKnown;
        if(var) return var.type.isKnown;
        return false;
    }
    Type getType() {
        if(func) return func.getType;
        if(var) return var.type;
        return TYPE_UNKNOWN;
    }
    Variable getVariable() { return var; }
    Function getFunction() { return func; }

    int getMemberIndex() {
        assert(isSet);
        assert(ttype==TargetType.STRUCTVAR || ttype==TargetType.STRUCTFUNC);

        if(var) {
            assert(var.isMember());
            return var.getMemberIndex();
        }
        auto parent = func.getLogicalParent;
        assert(parent.isA!Struct);
        return parent.as!Struct.getMemberIndex(func);
    }

    bool isFunction() const { return func !is null; }
    bool isVariable() const { return var !is null; }
    bool isMemberVariable() const { return ttype==TargetType.STRUCTVAR; }
    bool isMemberFunction() const { return ttype==TargetType.STRUCTFUNC; }

    LLVMValueRef llvmValue() {
        assert(isSet);
        if(isFunction) return func.llvmValue;
        if(isVariable) return var.llvmValue;
        return null;
    }
    Type returnType() {
        assert(isSet);
        assert(getType.isFunction);
        return getType.getFunctionType.returnType();
    }
    string[] paramNames() {
        assert(isSet);
        assert(getType.isFunction);
        return getType.getFunctionType.paramNames();
    }
    Type[] paramTypes() {
        assert(isSet);
        assert(getType.isFunction);
        return getType.getFunctionType.paramTypes();
    }
    override string toString() {
        if(isSet) {
            string s = targetModule.nid != module_.nid ? targetModule.canonicalName~"." : "";
            s ~= var?var.name : func?func.name: "";
            string i = module_.nid == targetModule.nid ? "" : " (import)";
            return "Target: %s %s %s%s".format(ttype, s, getType, i);
        }
        return "Target: not set";
    }
private:
    void addRef() {

        if(var) {
            var.numRefs++;
        } else {
            func.numRefs++;
        }
        if(targetModule.nid != module_.nid) {

            //if(targetModule.canonicalName=="core::core") { dd("------> plus"); }

            targetModule.numRefs++;
            if(func) func.numExternalRefs++;
        }
    }
    void removeRef() {
        if(var) {
            var.numRefs--;
        } else {
            func.numRefs--;
        }
        if(targetModule.nid != module_.nid) {

            //if(targetModule.canonicalName=="core::core") { dd("------> minus"); }

            targetModule.numRefs--;
            if(func) func.numExternalRefs--;
        }
    }
}