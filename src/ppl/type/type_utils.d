module ppl.type.type_utils;

import ppl.internal;


Type[] types(Expression[] e) {
    return e.map!(it=>it.getType).array;
}
bool areKnown(Type[] t) {
	return t.all!(it=>it !is null && it.isKnown);
}
bool areCompatible(Type a, Type b) {
    if(a.canImplicitlyCastTo(b)) return true;
    return b.canImplicitlyCastTo(a);
}


///
/// Return the largest type of a or b.
/// Return null if they are not compatible.
///
Type getBestFit(Type a, Type b) {
    if((a.isVoid && a.isValue) || (b.isVoid && b.isValue)) {
        return null;
    }

    if(a.exactlyMatches(b)) return a;

    if(a.isPtr || b.isPtr) {
        return null;
    }
    if(a.isTuple || b.isTuple) {
        // todo - some clever logic here
        return null;
    }
    if(a.isClass || b.isClass) {
        // todo - some clever logic here
        return null;
    }
    if(a.isStruct || b.isStruct) {
        // todo - some clever logic here
        return null;
    }
    if(a.isFunction || b.isFunction) {
        return null;
    }
    if(a.isArray || b.isArray) {
        return null;
    }

    if(a.isReal == b.isReal) {
        return a.category() > b.category() ? a : b;
    }
    if(a.isReal) return a;
    if(b.isReal) return b;
    return a;
}
///
/// Get the largest type of all elements.
/// If there is no common type then return null
///
Type getBestFit(Type[] types) {
    if(types.length==0) return TYPE_UNKNOWN;

    Type t = types[0];
    if(types.length==1) return t;

    foreach(e; types[1..$]) {
        t = getBestFit(t, e);
        if(t is null) {
            return null;
        }
    }
    return t;
}
//============================================================================================== exactlyMatch
bool exactlyMatch(Type[] a, Type[] b) {
    if(a.length != b.length) return false;
    foreach(i, left; a) {
        if(!left.exactlyMatches(b[i])) return false;
    }
    return true;
}
/// Do the common checks
bool prelimExactlyMatches(Type left, Type right) {
    if(left.isUnknown || right.isUnknown) return false;
    if(left.category() != right.category()) return false;
    if(left.getPtrDepth() != right.getPtrDepth()) return false;
    return true;
}
//====================================================================================== canImplicitlyCastTo
bool canImplicitlyCastTo(Type[] a, Type[] b) {
    if(a.length != b.length) return false;
    foreach(i, left; a) {
        if(!left.canImplicitlyCastTo(b[i])) return false;
    }
    return true;
}
/// Do the common checks
bool prelimCanImplicitlyCastTo(Type left, Type right) {
    if(left.isUnknown || right.isUnknown) return false;
    if(left.getPtrDepth() != right.getPtrDepth()) return false;
    if(left.isPtr()) {
        if(right.isVoid) {
            /// void* can contain any other pointer
            return true;
        }
        /// pointers must be exactly the same base type
        return left.category==right.category;
    }
    /// Do the base checks now
    return true;
}
int size(Type t) {
    if(t.isPtr) return 8;
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case FUNCTION: /// should always be a ptr
        case VOID:
            assert(false, "size - %s has no size".format(t));
        case BOOL:
        case BYTE: return 1;
        case SHORT: return 2;
        case INT: return 4;
        case LONG: return 8;
        case HALF: return 2;
        case FLOAT: return 4;
        case DOUBLE: return 8;
        case STRUCT:
        case CLASS:
            return t.getStruct.getSize();
        case TUPLE: return t.getTuple.getSize();
        case ARRAY: return t.getArrayType.countAsInt()*t.getArrayType.subtype.size();
        case ENUM: return t.getEnum().elementType.size();
    }
}
int alignment(Type t) {
    if(t.isPtr) return 8;
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case FUNCTION: /// should always be a ptr
        case VOID:
            assert(false, "size - %s has no size".format(t));
        case BOOL:
        case BYTE: return 1;
        case SHORT: return 2;
        case INT: return 4;
        case LONG: return 8;
        case HALF: return 2;
        case FLOAT: return 4;
        case DOUBLE: return 8;
        case STRUCT:
        case CLASS:
            return t.getStruct.getAlignment();
        case TUPLE: return t.getTuple.getAlignment();
        case ARRAY: return t.getArrayType().subtype.alignment();
        case ENUM: return t.getEnum().elementType.alignment();
    }
}
LLVMValueRef zeroValue(Type t) {
    if(t.isPtr) {
        return constNullPointer(t.getLLVMType());
    }
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case STRUCT:
        case CLASS: // class value
        case TUPLE:
        case ARRAY:
        case FUNCTION:
        case VOID:
            assert(false, "zeroValue - type is %s".format(t));
        case BOOL: return constI8(FALSE);
        case BYTE: return constI8(0);
        case SHORT: return constI16(0);
        case INT: return constI32(0);
        case LONG: return constI64(0);
        case HALF: return constF16(0);
        case FLOAT: return constF32(0);
        case DOUBLE: return constF64(0);
        case ENUM: return t.getEnum().elementType.zeroValue;
    }
}
Expression initExpression(Type t) {
    if(t.isPtr) {
        return LiteralNull.makeConst(t);
    }
    final switch(t.category) with(Type) {
        case UNKNOWN:
        case VOID:
            assert(false, "initExpression - type is %s".format(t));
        case STRUCT:
        case CLASS: // class value
        case TUPLE:
        case ARRAY:
        case FUNCTION:
            assert(false, "initExpression - implement me");
        case ENUM:
            return t.getEnum().firstValue();
        case BOOL:
        case BYTE:
        case SHORT:
        case INT:
        case LONG:
        case HALF:
        case FLOAT:
        case DOUBLE:
            return LiteralNumber.makeConst("0", t);
    }
}
string toString(Type[] types) {
    auto buf = new StringBuffer;
    foreach(i, t; types) {
        if(i>0) buf.add(",");
        buf.add("%s".format(t));
    }
    return buf.toString;
}

int calculateAggregateSize(Type[] types) {
    int offset  = 0;
    int largest = 1;

    foreach(t; types) {
        int align_    = t.alignment();
        int and       = (align_-1);
        int newOffset = (offset + and) & ~and;

        offset = newOffset + t.size;

        if(align_ > largest) largest = align_;
    }

    /// The final size must be a multiple of the largest alignment
    offset = (offset + (largest-1)) & ~(largest-1);

    return offset;
}