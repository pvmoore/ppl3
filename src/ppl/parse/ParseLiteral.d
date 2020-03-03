module ppl.parse.ParseLiteral;

import ppl.internal;

final class ParseLiteral {
private:
    Module module_;

    auto stmtParser()   { return module_.stmtParser; }
    auto exprParser()   { return module_.exprParser; }
    //auto typeParser()   { return module_.typeParser; }
    //auto typeDetector() { return module_.typeDetector; }
    auto typeFinder()    { return module_.typeFinder; }
    auto varParser()    { return module_.varParser; }
    //auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    /// lambda     ::= [ params ] statements
    ///
    /// params     ::= "| params "|"
    /// statements ::= "{" { Statement } "}"
    ///
    void parseLambda(Tokens t, ASTNode parent) {

        LiteralFunction lit = makeNode!LiteralFunction(t);
        parent.add(lit);

        auto params = makeNode!Parameters(t);
        lit.add(params);

        auto type   = makeNode!FunctionType(t);
        type.params = params;
        lit.type = Pointer.of(type, 1);

        string name = module_.makeTemporary("lambda");
        auto var = lit.getAncestor!Variable;
        if(var) {
            name ~= "_" ~ var.name;
        }

        /// Params
        if(t.type==TT.PIPE) {
            t.skip(TT.PIPE);

            while(t.type!=TT.PIPE) {

                varParser().parseParameter(t, params);

                t.expect(TT.PIPE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.PIPE);
        }

        /// {
        t.skip(TT.LCURLY);

        /// Statements
        while(t.type != TT.RCURLY) {
            stmtParser().parse(t, lit);
        }

        /// }
        t.skip(TT.RCURLY);

        auto lambda = makeNode!Lambda(t);
        lambda.name = name;
        lambda.add(lit);

        module_.addLambda(lambda);

        parent.add(lambda);
    }
    ///
    /// literal_function ::= "{" { statement } "}"
    ///
    void parseFunctionBody(Tokens t, Function parent, Parameters params) {

        LiteralFunction lit = makeNode!LiteralFunction(t);
        parent.add(lit);

        lit.add(params);

        /// {
        t.skip(TT.LCURLY);

        /// statements
        while(t.type != TT.RCURLY) {
            stmtParser().parse(t, lit);
        }

        /// }
        t.skip(TT.RCURLY);
    }
    ///
    /// literal_string ::= prefix quote { char } quote
    /// quote          ::= '"' | '"""'
    /// prefix         ::= nothing | "r" | "u8"
    ///
    void parseLiteralString(Tokens t, ASTNode parent) {

        auto composite = makeNode!Composite(t);
        parent.add(composite);

        auto s = makeNode!LiteralString(t);

        string text = t.value;
        t.next;

        if(text[0]=='\"') {
            s.enc  = LiteralString.Encoding.UTF8;
            text = parseStringLiteral(text[1..$-1]);

        } else if(text[0]=='r') {
            s.enc  = LiteralString.Encoding.RAW;
            text = text[2..$-1];

        } else {
            module_.addError(t, "Unknown string encoding", false);
        }

        s.value = text;

        module_.addLiteralString(s);

        auto b = module_.builder(parent);

        /// Create an alloca
        auto var = makeNode!Variable(t);
        var.name = module_.makeTemporary("str");
        var.type = typeFinder.findType("string", parent);
        composite.add(var);

        /// Call string.new(this, byte*, int, int)

        Call call    = b.call("new", null);
        auto thisPtr = b.addressOf(b.identifier(var.name));
        call.add(thisPtr);
        call.add(s);
        call.add(LiteralNumber.makeConst(0, TYPE_INT));
        call.add(LiteralNumber.makeConst(s.calculateLength(), TYPE_INT));

        auto dot = b.dot(b.identifier(var.name), call);

        auto valueof = b.valueOf(dot);
        composite.add(valueof);

        if(t.type==TT.STRING && t.onSameLine) {
            errorBadSyntax(module_, t, "These strings need to be concatenated");
        }
    }
    ///
    /// literal_number |
    /// literal_string |
    /// literal_char
    ///
    void parseLiteral(Tokens t, ASTNode parent) {
        Expression e;

        if(t.type==TT.NUMBER || t.type==TT.CHAR || t.value=="true" || t.value=="false") {
            auto lit = makeNode!LiteralNumber(t);
            lit.str = t.value;
            e = lit;
            parent.add(e);
            lit.determineType();
            t.next;
        } else if("null"==t.value) {
            e = makeNode!LiteralNull(t);
            parent.add(e);
            t.next;
        } else {
            assert(false, "How did we get here?");
        }
    }
}
