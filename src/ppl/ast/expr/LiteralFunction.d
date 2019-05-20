module ppl.ast.expr.LiteralFunction;

import ppl.internal;

///
/// literal_function::= "{" [ { arg_list } "->" ] { statement } "}"    
/// arg_list ::= type identifier { "," type identifier }               
///                                                                    
/// LiteralFunction                                                    
///     Parameters
///         Variable (0 - *)
///     Statement (0 - *)
///
class LiteralFunction : Expression, Container {
    Type type; /// Pointer -> FunctionType

    override bool isResolved()    { return type.isKnown; }
    override NodeID id() const    { return NodeID.LITERAL_FUNCTION; }
    override int priority() const { return 15; }
    override Type getType()       { return type; }

    override CT comptime() { return CT.NO; }

    LLVMValueRef getLLVMValue() {
        if(isLambda) return parent.as!Lambda.llvmValue;
        return getFunction().llvmValue;
    }

    Parameters params() {
        return children[0].as!Parameters;
    }

    bool isLambda() const {
        return parent.isA!Lambda;
    }

    bool isTemplate() { return false; }

    Lambda getLambda() {
        assert(isLambda);
        return parent.as!Lambda;
    }
    Function getFunction() {
        assert(parent.isA!Function);
        return parent.as!Function;
    }
    Return[] getReturns() {
        auto array = new DynamicArray!Return;
        selectDescendents!Return(array);
        return array[].filter!(it=>
            /// Don't include closure or inner struct
            it.getContainer().node.nid==nid
        ).array;
    }
    /// Returns true if there are no statements other than Parameters
    bool isEmpty() {
        if(numChildren==1) {
            assert(first().isA!Parameters);
            return true;
        }
        return false;
    }
    int numStatements() {
        /// Don't include Parameters
        return numChildren-1;
    }

    override string toString() {
        return "{} (type=%s)".format(type);
    }
}
