module ppl.templates.blueprint;

import ppl.internal;

final class TemplateBlueprint {
private:
    Module module_;
    Tokens nav;
    ParamTokens paramTokens;
    bool isPub;
public:
    Token[] tokens;
    string[] paramNames;

    bool isFunction;
    Set!string extracted;

    this(Module module_) {
        this.module_   = module_;
        this.nav       = new Tokens(null, null);
        this.extracted = new Set!string;
    }

    int numTemplateParams() {
        return paramNames.length.toInt;
    }
    int numFuncParams() {
        return paramTokens.numParams;
    }
    ParamTokens getParamTokens() {
        return paramTokens;
    }
    int indexOf(string paramName) {
        foreach(i, n; paramNames) {
            if(n==paramName) return i.toInt;
        }
        return -1;
    }
    void setStructTokens(Struct ns, string[] paramNames, Token[] tokens, bool isPub) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LCURLY);
        assert(tokens[$-1].type==TT.RCURLY);

        this.paramNames = paramNames;
        this.tokens     = tokens;
        this.isPub      = isPub;
    }
    ///
    /// tokens::= "(" [ params ] ")" [type] "{" {statment} "}"
    ///
    void setFunctionTokens(Struct ns, string[] paramNames, Token[] tokens, bool isPub) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LBRACKET);
        assert(tokens[$-1].type==TT.RCURLY);

        this.isFunction  = true;
        this.paramNames  = paramNames;
        this.tokens      = tokens;
        this.paramTokens = new ParamTokens(ns, paramNames, tokens);
        this.isPub       = isPub;
    }
    Token[] extractStruct(string mangledName, Type[] types) {
        /// struct mangledName
        Token[] tokens;

        if(isPub) tokens ~= this.tokens[0].copy("pub");

        tokens ~= [
            this.tokens[0].copy("struct"),
            this.tokens[0].copy(mangledName)
        ] ~ this.tokens.dup;

        foreach(ref t; tokens) {
            if(t.type==TT.IDENTIFIER) {
                int i = indexOf(t.value);
                if(i!=-1) {
                    t.templateType = types[i];
                }
            }
        }
        return tokens;
    }
    Token[] extractFunction(string mangledName, Type[] types, bool isStatic) {
        /// [pub] [static] mangledName { ... }

        /// new style:
        /// [pub] [static] "fn" mangledName ( params ) [type] { ... }

        bool newStyle = this.tokens[0].type==TT.LBRACKET;

        Token[] tokens;

        if(isPub) tokens ~= this.tokens[0].copy("pub");
        if(isStatic) tokens ~= this.tokens[0].copy("static");

        if(newStyle) tokens ~= this.tokens[0].copy("fn");

        tokens ~= [
            this.tokens[0].copy(mangledName)
        ] ~ this.tokens.dup;

        foreach(ref t; tokens) {
            if(t.type==TT.IDENTIFIER) {
                int i = indexOf(t.value);
                if(i!=-1) {
                    t.templateType = types[i];
                }
            }
        }

        //if(newStyle) {
        //    dd("extractFunction:", tokens.toSimpleString);
        //}

        return tokens;
    }
    Type[] getFuncParamTypes(Module module_, Call call, Type[] templateTypes) {
        assert(templateTypes.length==paramNames.length);

        Type[] paramTypes;
        foreach(at; paramTokens.getTokensForAllParams()) {
            auto tokens = at.dup;

            nav.reuse(module_, tokens);

            applyTypes(tokens, templateTypes);

            paramTypes ~= module_.typeParser.parse(nav, call, false);
        }
        return paramTypes;
    }
    override string toString() {
        if(isFunction) {
            return "(%s)".format(paramTokens.getTokensForAllParams().map!(it=>"%s".format(it)).join(", "));
        }
        return super.toString();
    }
private:
    void applyTypes(Token[] tokens, Type[] types) {
        foreach(ref tok; tokens) {
            if(tok.type==TT.IDENTIFIER) {
                long index = indexOf(tok.value);
                if(index!=-1) {
                    tok.templateType = types[index];
                }
            }
        }
    }
}