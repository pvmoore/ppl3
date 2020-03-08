module ppl.parse.ParseFunction;

import ppl.internal;

final class ParseFunction {
private:
    Module module_;

    auto typeDetector()  { return module_.typeDetector; }
    auto typeParser()    { return module_.typeParser; }
    auto varParser()     { return module_.varParser; }
    auto literalParser() { return module_.literalParser; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// function::= [ "static" ] "fn" id [ template params] "(" params ")" returnType expr_function_literal
    ///
    void parse(Tokens t, ASTNode parent) {

        /// Check the scope
        ASTNode p = parent;
        Struct ns;

        while(true) {
            if(p.isModule) {
                break;
            }
            if(p.isA!Struct) {
                ns = p.as!Struct;
                break;
            }
            if(p.isComposite) {
                p = p.parent;
                continue;
            } else if(p.isLiteralFunction) {
                p = p.parent;
                continue;
            }
            if(p.isA!Placeholder) {
                p = p.parent;
                continue;
            }

            module_.addError(t, "Function must be at module or struct scope", true);
            break;
        }

        auto f = makeNode!Function(t);
        parent.add(f);

        f.access = t.access();

        if(t.value=="static") {
            f.isStatic = true;
            t.next;
        }

        /// "fn"
        t.skip("fn");

        /// name
        f.name       = t.value;
        f.moduleName = module_.canonicalName;
        t.next;

        if(f.isStatic && f.name=="new") {
            module_.addError(t, "Struct constructors cannot be static", true);
        }
        if(f.name.startsWith("__") && !module_.canonicalName.startsWith("core::")) {
            module_.addError(t, "Function names starting with __ are reserved", true);
        }
        //if(f.name=="main" && module_.config.getEntryFunctionName()!="main") {
        //    module_.addError(t, "'main' function found. Expecting %s".format(module_.config.getEntryFunctionName()), false);
        //    return;
        //}

        if(f.name=="operator" && ns) {
            /// Operator overload

            f.op = parseOperator(t);
            f.name ~= f.op.value;
            t.next;

            switch(f.op.id) with(Operator) {
                case BOOL_EQ.id:
                case BOOL_NE.id:
                case INDEX.id:
                    break;
                default:
                    module_.addError(f, "Cannot overload operator %s".format(f.op), true);
                    break;
            }
        }

        /// Function template
        if(t.type==TT.LANGLE) {
            /// Template function - just gather the args and tokens
            t.skip(TT.LANGLE);

            f.blueprint = new TemplateBlueprint(module_);
            string[] paramNames;

            /// < .. >
            while(t.type!=TT.RANGLE) {

                if(typeDetector().isType(t, f)) {
                    module_.addError(t, "Template param name cannot be a type", true);
                }

                paramNames ~= t.value;
                t.next;
                t.expect(TT.RANGLE, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            int start = t.index;
            int end;

            /// (
            t.expect(TT.LBRACKET);

            end = t.findEndOfBlock(TT.LBRACKET);
            end = t.findEndOfBlock(TT.LCURLY, end);

            f.blueprint.setFunctionTokens(ns, paramNames, t[start..start+end+1].dup, t.access.isPublic);

            t.next(end+1);

            //dd("Function template decl", f.name, f.blueprint.paramNames, f.blueprint.tokens);

        } else {
            /// (int a,int b) void {

            /// Parameters
            /// (
            t.skip(TT.LBRACKET);

            auto params = makeNode!Parameters(t);
            f.add(params);

            auto type   = makeNode!FunctionType(t);
            type.params = params;

            while(t.type!=TT.RBRACKET) {

                varParser().parseParameter(t, params);

                t.expect(TT.RBRACKET, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }
            /// )
            t.skip(TT.RBRACKET);

            /// Return type
            if(t.type==TT.LCURLY) {
                /// Assume void or inferred

            } else {
                type.returnType(typeParser.parse(t, f));
            }

            /// function literal
            t.expect(TT.LCURLY);
            literalParser.parseFunctionBody(t, f, params);

            /// Add implicit this* parameter if this is a non-static struct member function
            if(ns && !f.isStatic) {
                params.addThisParameter(ns);
            }

            auto body_ = f.getBody();
            body_.type = Pointer.of(type, 1);
        }
    }
    /// eg. extern fn putchar(int) int
    void parseExtern(Tokens t, ASTNode parent) {

        /// "extern"
        t.next;

        auto f = makeNode!Function(t);
        parent.add(f);
        f.moduleName = module_.canonicalName;
        f.isExtern   = true;
        f.access     = t.access;

        /// "fn" id
        f.name = t.peek(1).value;

        /// type
        f.externType = typeParser().parse(t, f);
    }
}