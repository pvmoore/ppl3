module ppl.Operator;

import ppl.internal;

Operator parseOperator(Tokens t) {
    /// '>' is tokenised to separate tokens to ease parsing of nested parameterised templates.
    /// Account for this here:
    if(t.type==TT.RANGLE) {
        if(t.peek(1).type==TT.RANGLE) {
            if(t.peek(2).type==TT.RANGLE) {
                t.next(2);
                return Operator.USHR;
            }
            t.next;
            return Operator.SHR;
        }
    }
    if(t.type==TT.LSQBRACKET) {
        if(t.peek(1).type==TT.RSQBRACKET) {
            t.next;
            return Operator.INDEX;
        }
    }
    auto p = t.type in g_ttToOperator;
    if(p) return *p;
    switch(t.value) {
        case "and": return Operator.BOOL_AND;
        case "or":  return Operator.BOOL_OR;
        case "neg": return Operator.NEG;
        default: break;
    }
    return Operator.NOTHING;
}
struct Op {
    int id;
    int priority;
    string value;
}
enum Operator : Op {
    NOTHING  = Op(0, 0,null),

    /// Dot   = 2
    /// Index = 2

    INDEX    = Op(1, 2, "[]"),

    /// Call        = 2
    /// BuiltinFunc = 2

    /// As    = 3

    NEG      = Op(2, 5, "neg"),
    BIT_NOT  = Op(3, 5, "~"),
    BOOL_NOT = Op(4, 5, "not"),

    /// & addressof = 3
    /// * valueof   = 3

    DIV      = Op(5, 6, "/"),
    MUL      = Op(6, 6, "*"),
    MOD      = Op(7, 6, "%"),

    UDIV     = Op(8, 6, "%"),
    UMOD     = Op(9, 6, "%"),

    ADD      = Op(10, 7, "+"),
    SUB      = Op(11, 7, "-"),
    SHL      = Op(12, 7, "<<"),
    SHR      = Op(13, 7, ">>"),
    USHR     = Op(14, 7, ">>>"),
    BIT_AND  = Op(15, 7, "&"),
    BIT_XOR  = Op(16, 7, "^"),
    BIT_OR   = Op(17, 7, "|"),

    LT        = Op(18, 9, "<"),
    GT        = Op(19, 9, ">"),
    LTE       = Op(20, 9, "<="),
    GTE       = Op(21, 9, ">="),

    ULT       = Op(22, 9, "u<"),
    UGT       = Op(23, 9, "u>"),
    ULTE      = Op(24, 9, "u<="),
    UGTE      = Op(25, 9, "u>="),

    BOOL_EQ   = Op(26, 9, "=="),
    BOOL_NE   = Op(27, 9, "!="),
    /// Is = 9

    BOOL_AND    = Op(28, 11, "and"),
    BOOL_OR     = Op(29, 11, "or"),

    /// assignments below here
    ADD_ASSIGN     = Op(30, 14, "+="),
    SUB_ASSIGN     = Op(31, 14, "-="),
    MUL_ASSIGN     = Op(32, 14, "*="),
    DIV_ASSIGN     = Op(33, 14, "/="),
    MOD_ASSIGN     = Op(34, 14, "%="),
    BIT_AND_ASSIGN = Op(35, 14, "&="),
    BIT_XOR_ASSIGN = Op(36, 14, "^="),
    BIT_OR_ASSIGN  = Op(37, 14, "|="),

    SHL_ASSIGN     = Op(38, 14, "<<="),
    SHR_ASSIGN     = Op(39, 14, ">>="),
    USHR_ASSIGN    = Op(40, 14, ">>>="),
    ASSIGN         = Op(41, 14, "="),
    REASSIGN       = Op(42, 14, ":=")

    /// Calloc      = 15
    /// Lambda      = 15
    /// Composite   = 15
    /// Constructor = 15
    /// Identifier  = 15
    /// If          = 15
    /// Initialiser = 15
    /// Literals    = 15
    /// ModuleAlias = 15
    /// Parenthesis = 15
    /// Select      = 15
    /// TypeExpr    = 15
}
//===========================================================================
Operator removeAssign(Operator o) {
    switch(o.id) with(Operator) {
        case ADD_ASSIGN.id:     return ADD;
        case SUB_ASSIGN.id:     return SUB;
        case MUL_ASSIGN.id:     return MUL;
        case DIV_ASSIGN.id:     return DIV;
        case MOD_ASSIGN.id:     return MOD;
        case BIT_AND_ASSIGN.id: return BIT_AND;
        case BIT_XOR_ASSIGN.id: return BIT_XOR;
        case BIT_OR_ASSIGN.id:  return BIT_OR;
        case SHL_ASSIGN.id:     return SHL;
        case SHR_ASSIGN.id:     return SHR;
        case USHR_ASSIGN.id:    return USHR;
        default:
            assert(false, "not an assign operator %s".format(o));
    }
}
bool isAssign(Operator o) {
    return o.id >= Operator.ADD_ASSIGN.id && o.id <= Operator.REASSIGN.id;
}
bool isBool(Operator o) {
    switch(o.id) with(Operator) {
        case BOOL_AND.id:
        case BOOL_OR.id:
        case BOOL_NOT.id:
        case BOOL_EQ.id:
        case BOOL_NE.id:

        case LT.id:
        case GT.id:
        case LTE.id:
        case GTE.id:

        case ULT.id:
        case UGT.id:
        case ULTE.id:
        case UGTE.id:
            return true;
        default:
            return false;
    }
}
Operator switchLeftRightBool(Operator o) {
    switch(o.id) with(Operator) {
        case BOOL_EQ.id: return BOOL_EQ;
        case BOOL_NE.id: return BOOL_NE;
        case LT.id: return GTE;
        case GT.id: return LTE;
        case LTE.id: return GT;
        case GTE.id: return LT;

        case ULT.id: return UGTE;
        case UGT.id: return ULTE;
        case ULTE.id: return UGT;
        case UGTE.id: return ULT;

        default:
            assert(false, "not a bool");
    }
}
bool isUnary(Operator o) {
    switch(o.id) with(Operator) {
        case NEG.id:
        case BIT_NOT.id:
        case BOOL_NOT.id:
            return true;
        default:
            return false;
    }
}
bool isCommutative(Operator o) {
    switch(o.id) with(Operator) {
        case ADD.id:
        case MUL.id:
        case BIT_AND.id:
        case BIT_OR.id:
        case BIT_XOR.id:
            return true;
        default:
            return false;
    }
}
bool isOverloadable(Operator o) {
    switch(o.id) with(Operator) {
        case BOOL_EQ.id:    /// ==
        case BOOL_NE.id:    /// !=
        case INDEX.id:      /// []
            return true;
        default:
            return false;
    }
}
// bool isComparison(Operator o) {
//     switch(o.id) with(Operator) {
//         case LT.id:
//         case LTE.id:
//         case GT.id:
//         case GTE.id:
//         case BOOL_EQ.id:
//         case BOOL_NE.id:
//             return true;
//         default:
//             return false;
//     }
// }
bool isPtrArithmetic(Operator o) {
    switch(o.id) with(Operator) {
        case ADD.id:
        case SUB.id:
        case ADD_ASSIGN.id:
        case SUB_ASSIGN.id:
            return true;
        default:
            return false;
    }
}
