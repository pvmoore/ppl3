module ppl.lex.token;

import ppl.internal;

struct Token {
    TT type;
    string value;
    int length;
    Position start;
    Position end;
    Type templateType;

    int line()         { return start.line; }
    int column()       { return start.column; }
    bool isGenerated() { return start==INVALID_POSITION; }

    static Token make(TT type, string value, int length, Position start, Position end) {
        return Token(type, value, length, start, end, null);
    }

    string toString() {
        string t   = type==TT.IDENTIFIER ? "'"~value~"'" : "%s".format(type);
        string pos = !isGenerated() ? "(%s to %s  len %s)".format(start, end, length) : "(GENERATED)";
        string tt  = templateType ? " (%s)".format(templateType) : "";
        return "%s %s%s".format(t, pos, tt);
    }
}

Token copy(Token t, string value) {
    t.type  = TT.IDENTIFIER;
    t.value = value;
    return t;
}
Token copy(Token t, TT e) {
    t.type  = e;
    t.value = "";
    return t;
}
Token copy(Token t, string value, Type templateType) {
    t.type         = TT.IDENTIFIER;
    t.value        = value;
    t.templateType = templateType;
    return t;
}
string toSimpleString(Token t) {
    return t.type==TT.IDENTIFIER ? t.value  :
           t.type==TT.NUMBER ? t.value      : t.type.toString;
}
string toSimpleString(Token[] tokens) {
    auto buf = new StringBuffer;
    foreach(i, t; tokens) {
        if(i>0) buf.add(" ");
        buf.add(toSimpleString(t));
    }
    return buf.toString();
}

string toString(TT[] tt) {
    auto buf = new StringBuffer;
    foreach(i, t; tt) {
        if(i>0) buf.add(" ");
        buf.add(toString(t));
    }
    return buf.toString();
}

enum TT {
    NONE,
    IDENTIFIER,
    STRING,
    CHAR,
    NUMBER,
    LINE_COMMENT,
    MULTILINE_COMMENT,

    LCURLY,
    RCURLY,
    LSQBRACKET,
    RSQBRACKET,
    LBRACKET,
    RBRACKET,
    LANGLE,
    RANGLE,

    DBL_LSQBRACKET, // [[
    DBL_RSQBRACKET, // ]]
    DBL_EXCLAMATION, // !!
    DBL_HYPHEN,     // --

    LTE,            // <=
    GTE,            // >=

    SHL,
    SHR,
    USHR,

    COLON,          // :
    DBL_COLON,      // ::
    PLUS,           // +
    MINUS,          // -
    DIV,            // /
    ASTERISK,       // *
    PERCENT,        // %
    RT_ARROW,       // ->
    COMMA,          // ,
    SEMICOLON,      // ;
    EXCLAMATION,    // !
    AMPERSAND,      // &
    HAT,            // ^
    PIPE,           // |
    DOT,            // .
    QMARK,          // ?
    TILDE,          // ~
    HASH,           // #
    DOLLAR,         // $
    AT,             // @

    EQUALS,         // =
    ADD_ASSIGN,     // +=
    SUB_ASSIGN,     // -=
    MUL_ASSIGN,     // *=
    MOD_ASSIGN,     // %=
    DIV_ASSIGN,     // /=
    BIT_AND_ASSIGN, //  &=
    BIT_XOR_ASSIGN, // ^=
    BIT_OR_ASSIGN,  // |=
    COLON_EQUALS,   // :=

    SHL_ASSIGN,     // <<=
    SHR_ASSIGN,     // >>=
    USHR_ASSIGN,    // >>>=

    BOOL_EQ,        // ==
    BOOL_NE,        // !=
}
bool isComment(TT t) {
    return t==TT.LINE_COMMENT || t==TT.MULTILINE_COMMENT;
}
bool isString(TT t) {
    return t==TT.STRING;
}
string toString(TT t) {
    __gshared static string[TT] map;

    if(map.length==0) with(TT) {
        map[LCURLY] = "{";
        map[RCURLY] = "}";
        map[LBRACKET] = "(";
        map[RBRACKET] = ")";
        map[LSQBRACKET] = "[";
        map[RSQBRACKET] = "]";
        map[LANGLE] = "<";
        map[RANGLE] = ">";

        map[DBL_LSQBRACKET] = "[[";
        map[DBL_RSQBRACKET] = "]]";
        map[DBL_EXCLAMATION] = "!!";
        map[DBL_HYPHEN] = "--";

        map[LTE] = "<=",
        map[GTE] = ">=",

        map[SHL] = "<<",
        map[SHR] = ">>",
        map[USHR] = ">>>",

        map[EQUALS] = "=";
        map[COLON] = ":";
        map[DBL_COLON] = "::";
        map[PLUS] = "+";
        map[MINUS] = "-";
        map[DIV] = "/";
        map[ASTERISK] = "*";
        map[PERCENT] = "%";
        map[RT_ARROW] = "->";
        map[COMMA] = ",";
        map[SEMICOLON] = ";";
        map[EXCLAMATION] = "!";
        map[AMPERSAND] = "&";
        map[HAT] = "^";
        map[PIPE] = "|";
        map[DOT] = ".";
        map[QMARK] = "?";
        map[TILDE] = "~";
        map[HASH] = "#";
        map[DOLLAR] = "$";
        map[AT] = "@";

        map[ADD_ASSIGN] = "+=";
        map[SUB_ASSIGN] = "-=";
        map[MUL_ASSIGN] = "*=";
        map[MOD_ASSIGN] = "%=";
        map[DIV_ASSIGN] = "/=";
        map[BIT_AND_ASSIGN] = "&=";
        map[BIT_XOR_ASSIGN] = "^=";
        map[BIT_OR_ASSIGN] = "|=";
        map[SHL_ASSIGN] = "<<=";
        map[SHR_ASSIGN] = ">>=";
        map[USHR_ASSIGN] = ">>>=";

        map[BOOL_EQ] = "==";
        map[BOOL_NE] = "!=";
    }
    return map.get(t, "%s".format(t));
}
