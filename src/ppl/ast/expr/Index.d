module ppl.ast.expr.Index;

import ppl.internal;

/**
 *  Index
 *      Expression  // index
 *      Expression  // ArrayType | Tuple | Pointer
 */
final class Index : Expression {

/// ASTNode
    override bool isResolved() {
        if(!expr().isResolved()) return false;
        if(isArrayIndex()) {
            return index().isResolved();
        }
        if(isPtrIndex()) {
            return true;
        }
        if(exprType().isStruct()) {
            /// Check if we are waiting to be rewritten to operator:
            auto ns = exprType().getStruct();
            assert(ns);
            if(ns.hasOperatorOverload(Operator.INDEX)) return false;
        }
        /// Struct index must be a const number
        return index().isResolved() && index().isA!LiteralNumber;
    }
    override NodeID id() const {
        return NodeID.INDEX;
    }
    override Type getType() {
        /// This might happen if an error is thrown
        if(numChildren() < 2) return TYPE_UNKNOWN;

        auto t       = exprType();
        auto struct_ = t.getStruct();
        auto tuple   = t.getTuple();
        auto array   = t.getArrayType();

        if(t.isPtr()) {
            return Pointer.of(t, -1);
        }
        if(t.isStruct()) {
            assert(struct_);

            if(struct_.hasOperatorOverload(Operator.INDEX)) {
                /// This will be replaced with an operator overload later
                return TYPE_UNKNOWN;
            }
            return TYPE_UNKNOWN;
        }
        if(array) {
            /// Check for bounds error
            if(array.isResolved() && index().isResolved() && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                if(i >= array.countAsInt()) {
                    getModule.addError(index(), "Array bounds error. %s >= %s".format(i, array.countAsInt()), true);
                    return TYPE_UNKNOWN;
                }
            }
            return array.subtype;
        }
        if(tuple) {
            if(index().isResolved() && index().isA!LiteralNumber) {
                auto i = getIndexAsInt();
                /// Check for bounds error
                if(i >= tuple.numMemberVariables()) {
                    getModule.addError(index(), "Array bounds error. %s >= %s".format(i, tuple.numMemberVariables()), true);
                    return TYPE_UNKNOWN;
                }
                return tuple.getMemberVariable(i).type;
            }
        }
        return TYPE_UNKNOWN;
    }

/// Expression
    override int priority() const {
        return 2;
    }
    override CT comptime() {
        // todo - this might be comptime
        return CT.NO;
    }


    bool isArrayIndex() { return exprType().isValue() && exprType().isArray(); }
    bool isTupleIndex() { return exprType().isValue() && exprType().isTuple(); }
    bool isPtrIndex()   { return exprType().isPtr(); }

    Expression expr()  { return cast(Expression)children[1]; }
    Expression index() { return cast(Expression)children[0]; }

    Type exprType() { return expr().getType(); }

    int getIndexAsInt() {
        assert(index().isA!LiteralNumber);
        return index().as!LiteralNumber.value.getInt();
    }

    override string toString() {
        /// Catch and ignore the exception that might be thrown by calling getType() here
        Type t = TYPE_UNKNOWN;
        try{
            t = getType();
        }catch(Exception e) {}

        return "Index (type=%s) [%s]".format(t, index());
    }
}