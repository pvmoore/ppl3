module ppl.global;
///
/// Handle all global shared initialisation and storage.
///
import ppl.internal;

public:

__gshared LLVMWrapper g_llvmWrapper;

__gshared int g_nodeid      = 1;
__gshared int g_callableID  = 1;
__gshared int g_errorIDs    = 1;

//__gshared FileLogger g_logger;

__gshared int[string] g_builtinTypes;
__gshared string[int] g_typeToString;

__gshared Operator[TT] g_ttToOperator;

__gshared Token NO_TOKEN = Token.make(TT.NONE, null, 0, INVALID_POSITION, INVALID_POSITION);

enum INVALID_POSITION = Position(-1,-1);

__gshared Type TYPE_UNKNOWN = new BasicType(Type.UNKNOWN);
__gshared Type TYPE_BOOL    = new BasicType(Type.BOOL);
__gshared Type TYPE_BYTE    = new BasicType(Type.BYTE);
__gshared Type TYPE_INT     = new BasicType(Type.INT);
__gshared Type TYPE_LONG    = new BasicType(Type.LONG);
__gshared Type TYPE_FLOAT   = new BasicType(Type.FLOAT);
__gshared Type TYPE_DOUBLE  = new BasicType(Type.DOUBLE);
__gshared Type TYPE_VOID    = new BasicType(Type.VOID);

__gshared const TRUE  = -1;
__gshared const FALSE = 0;
enum TRUE_STR  = "-1";
enum FALSE_STR = "0";

__gshared Callable CALLABLE_NOT_READY;

__gshared Set!string g_keywords;

shared static ~this() {
    if(g_llvmWrapper) g_llvmWrapper.destroy();
}

shared static this() {
    g_llvmWrapper = new LLVMWrapper;
    //g_logger = new FileLogger(".logs/log.log");

    g_builtinTypes["var"]    = Type.UNKNOWN;
    g_builtinTypes["bool"]   = Type.BOOL;
    g_builtinTypes["byte"]   = Type.BYTE;
    g_builtinTypes["short"]  = Type.SHORT;
    g_builtinTypes["int"]    = Type.INT;
    g_builtinTypes["long"]   = Type.LONG;
    g_builtinTypes["half"]   = Type.HALF;
    g_builtinTypes["float"]  = Type.FLOAT;
    g_builtinTypes["double"] = Type.DOUBLE;
    g_builtinTypes["void"]   = Type.VOID;

    g_typeToString[Type.UNKNOWN]  = "?";
    g_typeToString[Type.BOOL]     = "bool";
    g_typeToString[Type.BYTE]     = "byte";
    g_typeToString[Type.SHORT]    = "short";
    g_typeToString[Type.INT]      = "int";
    g_typeToString[Type.LONG]     = "long";
    g_typeToString[Type.HALF]     = "half";
    g_typeToString[Type.FLOAT]    = "float";
    g_typeToString[Type.DOUBLE]   = "double";
    g_typeToString[Type.VOID]     = "void";
    g_typeToString[Type.TUPLE]    = "tuple";
    g_typeToString[Type.STRUCT]   = "named_struct";
    g_typeToString[Type.CLASS]    = "class";
    g_typeToString[Type.ARRAY]    = "array";
    g_typeToString[Type.FUNCTION] = "function";

    // unary
    //ttOperator[NEG] =
    //g_ttToOperator[TT.BIT_NOT] = Operator.BIT_NOT;
    //g_ttToOperator[TT.BOOL_NOT] = Operator.BOOL_NOT;

    g_ttToOperator[TT.DIV] = Operator.DIV;
    g_ttToOperator[TT.ASTERISK] = Operator.MUL;
    g_ttToOperator[TT.PERCENT] = Operator.MOD;

    g_ttToOperator[TT.PLUS] = Operator.ADD;
    g_ttToOperator[TT.MINUS] = Operator.SUB;

    g_ttToOperator[TT.SHL] = Operator.SHL;
    g_ttToOperator[TT.SHR] = Operator.SHR;
    g_ttToOperator[TT.USHR] = Operator.USHR;

    g_ttToOperator[TT.LANGLE] = Operator.LT;
    g_ttToOperator[TT.RANGLE] = Operator.GT;
    g_ttToOperator[TT.LTE] = Operator.LTE;
    g_ttToOperator[TT.GTE] = Operator.GTE;

    g_ttToOperator[TT.BOOL_EQ] = Operator.BOOL_EQ;
    g_ttToOperator[TT.BOOL_NE] = Operator.BOOL_NE;

    g_ttToOperator[TT.AMPERSAND] = Operator.BIT_AND;
    g_ttToOperator[TT.HAT] = Operator.BIT_XOR;
    g_ttToOperator[TT.PIPE] = Operator.BIT_OR;

    //g_ttToOperator[TT.BOOL_AND] = Operator.BOOL_AND;
    //g_ttToOperator[TT.BOOL_OR] = Operator.BOOL_OR;

    g_ttToOperator[TT.ADD_ASSIGN] = Operator.ADD_ASSIGN;
    g_ttToOperator[TT.SUB_ASSIGN] = Operator.SUB_ASSIGN;
    g_ttToOperator[TT.MUL_ASSIGN] = Operator.MUL_ASSIGN;
    g_ttToOperator[TT.DIV_ASSIGN] = Operator.DIV_ASSIGN;
    g_ttToOperator[TT.MOD_ASSIGN] = Operator.MOD_ASSIGN;
    g_ttToOperator[TT.BIT_AND_ASSIGN] = Operator.BIT_AND_ASSIGN;
    g_ttToOperator[TT.BIT_XOR_ASSIGN] = Operator.BIT_XOR_ASSIGN;
    g_ttToOperator[TT.BIT_OR_ASSIGN] = Operator.BIT_OR_ASSIGN;
    g_ttToOperator[TT.SHL_ASSIGN] = Operator.SHL_ASSIGN;
    g_ttToOperator[TT.SHR_ASSIGN] = Operator.SHR_ASSIGN;
    g_ttToOperator[TT.USHR_ASSIGN] = Operator.USHR_ASSIGN;
    g_ttToOperator[TT.EQUALS] = Operator.ASSIGN;
    g_ttToOperator[TT.COLON_EQUALS] = Operator.REASSIGN;

    g_keywords = new Set!string;
    g_keywords.add([
        //"#alignof", "#isptr", "#isvalue", "#initof", "#sizeof", "#typeof",
        "alias", "and", "as", "assert",
        "bool", "break", "byte",
        "class", "const", "continue",
        "double",
        "else", "enum", "extern",
        "false", "float",
        "half",
        "if", "import", "int", "is",
        "long", "loop", "lstring",
        "not", "null",
        "operator", "or",
        "private", "public",
        "readonly", "return",
        "select", "short", "static", "string", "struct",
        "this", "true", "tuple",
        "var", "void"
    ]);
}