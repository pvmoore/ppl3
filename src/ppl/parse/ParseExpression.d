module ppl.parse.ParseExpression;

import ppl.internal;

private const string VERBOSE_MODULE = null; //"test";

final class ParseExpression {
private:
    Module module_;

    auto typeParser()    { return module_.typeParser; }
    auto typeDetector()  { return module_.typeDetector; }
    auto stmtParser()    { return module_.stmtParser; }
    auto varParser()     { return module_.varParser; }
    auto attrParser()    { return module_.attrParser; }
    auto typeFinder()    { return module_.typeFinder; }
    auto literalParser() { return module_.literalParser; }
    auto builder()       { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(Tokens t, ASTNode parent) {
        //dd("expression", t.get);

        parseLHS(t, parent);
        parseRHS(t, parent);
    }
private:
    void parseLHS(Tokens t, ASTNode parent) {
        static if(VERBOSE_MODULE) {
            if(module_.canonicalName==VERBOSE_MODULE) {
                dd("lhs", t.get, "parent=", parent.id);
            }
        }
        //scope(exit) dd("woops", t.get);

        consumeAttributes(t, parent);

        /// Simple tokens
        switch(t.type) with(TT) {
            case AT:
                parseBuiltinFunc(t, parent);
                return;
            case PIPE:
                literalParser().parseLambda(t, parent);
                return;
            case NUMBER:
            case CHAR:
                literalParser().parseLiteral(t, parent);
                return;
            case STRING:
                literalParser().parseLiteralString(t, parent);
                return;
            case LCURLY:
                errorBadSyntax(module_, t, "Expecting lambda parameters here eg. |int a|");
                break;
            default:
                break;
        }

        /// Simple identifiers
        if(t.type==TT.IDENTIFIER) {
            switch(t.value) {
                case "if":
                    parseIf(t, parent);
                    return;
                case "select":
                    parseSelect(t, parent);
                    return;
                case "not":
                    parseUnary(t, parent);
                    return;
                case "operator":
                    parseCall(t, parent);
                    return;
                case "true":
                case "false":
                case "null":
                    literalParser().parseLiteral(t, parent);
                    return;
                default:
                    break;
            }
        }

        /// Handle Enum members. Do this before type detection because the member
        /// value may look like a type eg. Enum::Thing (where Thing is also a type declared elsewhere)
        if(parent.isDot && t.type==TT.IDENTIFIER) {
            assert(parent.hasChildren);

            auto type = parent.first().getType;
            if(type.isEnum && parent.first.id==NodeID.TYPE_EXPR) {
                parseIdentifier(t, parent);
                return;
            }
        }

        /// type
        /// type (
        int eot = typeDetector().endOffset(t, parent);
        if(eot!=-1) {
            auto nextTok = t.peek(eot+1);

            if(nextTok.type==TT.LBRACKET && t.onSameLine(eot+1)) {
                /// type(
                parseConstructor(t, parent);
                return;
            }

            parseTypeExpr(t, parent);
            return;
        }

        /// More complex identifiers:

        /// name (          // call
        /// name |          // call with lambda arg
        /// name<...> (     // call
        /// name<...> |     // call with lambda arg
        /// name<...> {     // call with lambda arg         !! nope
        /// name <
        /// name::
        /// name
        if(t.type==TT.IDENTIFIER) {

            // name (
            if(t.peek(1).type==TT.LBRACKET && t.onSameLine(1)) {
                parseCall(t, parent);
                return;
            }
            // name {
            if(t.peek(1).type==TT.LCURLY) {
                errorBadSyntax(module_, t, "Function call with lambda arg should be eg. %s() || or %s || {}".format(t.value, t.value));
            }
            // name |
            if(t.peek(1).type==TT.PIPE) {
                /// Call with lambda arg
                /// name |...| {
                if(ParseHelper.isLambdaParams(t, parent, 1)) {
                    parseCall(t, parent);
                    return;
                }
            }
            // name <
            if(t.peek(1).type==TT.LANGLE) {
                /// Could be a call or identifier < expr
                int end;
                if(ParseHelper.isTemplateParams(t, 1, end)) {
                    parseCall(t, parent);
                    return;
                }
            }
            // name .
            if(t.peek(1).type==TT.DOT) {
                auto node = parent.hasChildren ? parent.last : parent;
                auto imp  = findImportByAlias(t.value, node);
                if(imp) {
                    parseModuleAlias(t, parent, imp);
                    return;
                }
            }
            // name ::
            if(t.peek(1).type==TT.DBL_COLON) {
                auto node = parent.hasChildren ? parent.last : parent;
                auto imp  = findImportByAlias(t.value, node);
                if(imp) {
                    parseModuleAlias(t, parent, imp);
                    return;
                }
            }

            parseIdentifier(t, parent);
            return;
        }

        /// Everything else
        switch(t.type) with(TT) {

            case LBRACKET:
                parseParenthesis(t, parent);
                return;
            case MINUS:
            case TILDE:
                parseUnary(t, parent);
                return;
            case AMPERSAND:
                parseAddressOf(t, parent);
                return;
            case ASTERISK:
                parseValueOf(t, parent);
                return;
            case EXCLAMATION:
                errorBadSyntax(module_, t, "Did you mean 'not'");
                return;
            default:
                //errorBadSyntax(t, "Syntax error");
                //writefln("BAD LHS %s", t.get);
                //parent.getModule.dumpToConsole();
                //module_.addError(t, "Bad LHS", false);
                errorBadSyntax(module_, t, "Syntax error at %s".format(t.type));
                return;
        }
    }
    void parseRHS(Tokens t, ASTNode parent) {

        while(true) {
            //dd("rhs", t.get, "parent=", parent.id);

            if("is"==t.value) {
                parent = attachAndRead(t, parent, parseIs(t));
            } else if("as"==t.value) {
                parent = attachAndRead(t, parent, parseAs(t));
            } else if("and"==t.value || "or"==t.value) {
                parent = attachAndRead(t, parent, parseBinary(t));
            } else switch(t.type) {
                case TT.NONE:
                case TT.LCURLY:
                case TT.RCURLY:
                case TT.LBRACKET:
                case TT.RBRACKET:
                case TT.RSQBRACKET:
                case TT.DBL_LSQBRACKET:
                case TT.DBL_RSQBRACKET:
                case TT.NUMBER:
                case TT.COMMA:
                case TT.SEMICOLON:
                case TT.COLON:
                case TT.AT:
                case TT.DOLLAR:
                    /// end of expression
                    return;
                case TT.PLUS:
                case TT.MINUS:
                case TT.DIV:
                case TT.PERCENT:
                case TT.HAT:
                case TT.SHL:
                case TT.SHR:
                case TT.USHR:
                case TT.LANGLE:
                case TT.RANGLE:
                case TT.LTE:
                case TT.GTE:
                case TT.EQUALS:
                case TT.ADD_ASSIGN:
                case TT.SUB_ASSIGN:
                case TT.MUL_ASSIGN:
                case TT.MOD_ASSIGN:
                case TT.DIV_ASSIGN:
                case TT.BIT_AND_ASSIGN:
                case TT.BIT_XOR_ASSIGN:
                case TT.BIT_OR_ASSIGN:
                case TT.SHL_ASSIGN:
                case TT.SHR_ASSIGN:
                case TT.USHR_ASSIGN:
                case TT.BOOL_EQ:
                case TT.BOOL_NE:
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.ASTERISK:
                    /// Must be on the same line as LHS otherwise will look like deref *
                    if(!t.onSameLine) return;

                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.AMPERSAND:
                    if(t.peek(1).type==TT.AMPERSAND) errorBadSyntax(module_, t, "Did you mean 'and'");
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.PIPE:
                    if(t.peek(1).type==TT.PIPE) errorBadSyntax(module_, t, "Did you mean 'or'");
                    parent = attachAndRead(t, parent, parseBinary(t));
                    break;
                case TT.LSQBRACKET:
                    /// array literal
                    if(t.peek(1).type==TT.COLON) return;

                    /// Tuple or Array
                    if(typeDetector().isType(t, parent, 1)) {
                        return;
                    }
                    parent = attachAndRead(t, parent, parseIndex(t, parent), false);
                    break;
                case TT.DBL_COLON:
                    errorBadSyntax(module_, t, "Not expecting :: Did you mean . ?");
                    break;
                case TT.DOT:
                    parent = attachAndRead(t, parent, parseDot(t));
                    break;
                case TT.IDENTIFIER:
                    if(t.value=="and" || t.value=="or") {
                        parent = attachAndRead(t, parent, parseBinary(t));
                        break;
                    }
                    /// end of expression
                    return;
                default:
                    writefln("BAD RHS %s", t.get);
                    parent.getModule.dumpToConsole();
                    module_.addError(t, "Bad RHS", false);
            }
        }
    }
    void consumeAttributes(Tokens t, ASTNode parent) {
        while(t.type==TT.DBL_HYPHEN) {
            attrParser().parse(t, parent);
        }
    }
    Expression attachAndRead(Tokens t, ASTNode parent, Expression newExpr, bool andRead = true) {
        //dd("attach", newExpr.id, "to", parent.id);

        ASTNode prev = parent;

        ///
        /// Swap expressions according to operator precedence
        ///
        const doPrecedenceCheck = prev.isA!Expression;
        if(doPrecedenceCheck) {

            /// Adjust to account for operator precedence
            Expression prevExpr = prev.as!Expression;
            while(prevExpr.parent &&
                  newExpr.priority >= prevExpr.priority)
            {

                if(!prevExpr.parent.isExpression) {
                    prev = prevExpr.parent;
                    break;
                }

                prevExpr = prevExpr.parent.as!Expression;
                prev     = prevExpr;
            }
        }

        newExpr.add(prev.last);
        prev.add(newExpr);

        if(andRead) {
            parseLHS(t, newExpr);
        }

        return newExpr;
    }
    ///
    /// binary_expr ::= expression operator expression
    /// operator ::= "=" | "+" | "-" etc...
    ///
    ///
    Expression parseBinary(Tokens t) {

        auto b = makeNode!Binary(t);

        if("and"==t.value) {
            b.op = Operator.BOOL_AND;
        } else if("or"==t.value) {
            b.op = Operator.BOOL_OR;
        } else {
            b.op = parseOperator(t);
            if(b.op==Operator.NOTHING) {
                module_.addError(t, "Invalid operator", true);
            }
        }

        t.next;

        return b;
    }
    ///
    /// dot_expr ::= expression ("." | "::") expression
    ///
    Expression parseDot(Tokens t) {

        auto d = makeNode!Dot(t);

        if(t.type==TT.DOT) {
            t.skip(TT.DOT);
        } else {
            t.skip(TT.DBL_COLON);
        }

        return d;
    }
    Expression parseIndex(Tokens t, ASTNode parent) {

        auto i = makeNode!Index(t);
        parent.add(i);

        t.skip(TT.LSQBRACKET);

        auto parens = makeNode!Parenthesis(t);
        i.add(parens);

        parse(t, parens);

        t.skip(TT.RSQBRACKET);

        i.detach();

        return i;
    }
    ///
    /// expression "as" type
    ///
    Expression parseAs(Tokens t) {

        auto a = makeNode!As(t);

        t.skip("as");

        return a;
    }
    Expression parseIs(Tokens t) {
        auto i = makeNode!Is(t);

        t.skip("is");

        if(t.value=="not") {
            t.skip("not");
            i.negate = true;
        }

        return i;
    }
    void parseTypeExpr(Tokens t, ASTNode parent) {
        auto e = makeNode!TypeExpr(t);
        parent.add(e);

        e.type = typeParser().parse(t, e);

        if(e.type is null) {
            errorMissingType(module_, t, t.value);
        }
    }
    ///
    /// call_expression::= identifier [template args] "(" [ expression ] { "," expression } ")"
    ///
    void parseCall(Tokens t, ASTNode parent) {

        auto c = makeNode!Call(t);
        parent.add(c);

        c.target = new Target(module_);
        c.name = t.value;
        t.next;

        if(c.name=="new") {
            ///
            /// This is a construtor call. We don't currently allow this
            ///
            module_.addError(c, "Explicit constructor calls not allowed", true);
        }

        if(c.name=="operator") {
            /// Call to operator overload

            auto op = parseOperator(t);
            switch(op.id) with(Operator) {
                case BOOL_EQ.id:
                case BOOL_NE.id:
                case INDEX.id:
                    break;
                default:
                    module_.addError(c, "%s is not an overloadable operator".format(op.value), true);
                    break;
            }

            c.name ~= op.value;
            t.next;

            if(op==Operator.NOTHING) errorBadSyntax(module_, t, "Expecting an overloadable operator");
        }

        /// template args
        if(t.type==TT.LANGLE) {
            t.next;

            while(t.type!=TT.RANGLE) {

                t.markPosition();

                auto tt = typeParser().parse(t, c);
                if(!tt) {
                    t.resetToMark();
                    errorMissingType(module_, t);
                }
                t.discardMark();

                c.templateTypes ~= tt;

                t.expect(TT.COMMA, TT.RANGLE);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RANGLE);

            //dd("Function template call", c.name, c.templateTypes);
        }

        if(t.type==TT.LBRACKET) {
            t.skip(TT.LBRACKET);

            import common : contains;

            /// Add args to a Parenthesis to act as a ceiling so that
            /// the operator precedence never moves them above the call
            auto parens = makeNode!Parenthesis(t);
            c.add(parens);

            while(t.type!=TT.RBRACKET) {

                if(t.peek(1).type==TT.COLON) {
                    /// paramname = expr
                    if(parens.numChildren>1 && c.paramNames.length==0) {
                        module_.addError(c, "Mixing named and un-named constructor arguments", true);
                    }
                    if(c.paramNames.contains(t.value)) {
                        module_.addError(t, "Duplicate call param name", true);
                    }
                    if(t.value=="this") {
                        module_.addError(t, "'this' cannot be used as a parameter name", true);
                    }
                    c.paramNames ~= t.value;
                    t.next;

                    /// :
                    t.skip(TT.COLON);

                    parse(t, parens);

                } else {
                    if (c.paramNames.length>0) {
                        module_.addError(c, "Mixing named and un-named constructor arguments", true);
                    }

                    parse(t, parens);
                }

                t.expect(TT.RBRACKET, TT.COMMA);
                if (t.type==TT.COMMA) t.next;
            }
            t.skip(TT.RBRACKET);

            /// Move args to call and discard parenthesis
            while(parens.hasChildren) {
                c.add(parens.first());
            }
            parens.detach();
        }

        if(t.type==TT.LCURLY) {
            // name() {
            // name {
            module_.addError(c, "Missing lambda parameters eg. ||", true);
        }

        if(t.type==TT.PIPE) {
            /// Groovy-style with closure arg at end:
            /// func |int a| {}
            /// func<..> |int a| {}
            /// func() |int a| {}

            parse(t, c);
        }
    }
    void parseIdentifier(Tokens t, ASTNode parent) {

        auto id = makeNode!Identifier(t);
        parent.add(id);

        /// Two identifiers in a row means one was probably a type that we don't know about
        auto prev = id.prevSibling;
        if(prev && prev.isA!Identifier && parent.id==NodeID.TUPLE) {
            errorMissingType(module_, prev, prev.as!Identifier.name);
        }

        id.target = new Target(module_);
        id.name = t.value;
        t.next;
    }
    void parseParenthesis(Tokens t, ASTNode parent) {
        auto p = makeNode!Parenthesis(t);
        parent.add(p);

        t.skip(TT.LBRACKET);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Empty parenthesis");

        parse(t, p);

        t.skip(TT.RBRACKET);
    }
    void parseUnary(Tokens t, ASTNode parent) {

        auto u = makeNode!Unary(t);
        parent.add(u);

        /// - ~ not
        if("not"==t.value) {
            u.op = Operator.BOOL_NOT;
        } else if(t.type==TT.TILDE) {
            u.op = Operator.BIT_NOT;
        } else if(t.type==TT.MINUS) {
            u.op = Operator.NEG;
        } else assert(false, "How did we get here?");

        t.next;

        parse(t, u);
    }
    ///
    /// constructor ::= type "(" { cexpr [ "," cexpr ] } ")"
    /// cexpr       :: expression | paramname ":" expression
    ///
    void parseConstructor(Tokens t, ASTNode parent) {
        import common : contains;

        /// Convert this:
        ///
        /// type(...)
        ///
        /// To one of these (depending on whether the type is a pointer) :

        /// S(...)
        ///    Variable _temp (type=S)
        ///    Dot
        ///       _temp
        ///       Call new
        ///          AddressOf(_temp)
        ///          [ optional args ]
        ///    _temp

        /// S*(...)
        ///    Variable _temp (type=S*)
        ///    _temp = calloc
        ///    Dot
        ///       _temp
        ///       Call new
        ///          _temp
        ///          [ optional args ]
        ///    _temp
        ///
        auto con = makeNode!Constructor(t);
        parent.add(con);

        auto b = module_.builder(con);

        /// type
        con.type = typeParser().parse(t, parent);

        if(!con.type) {
            errorMissingType(module_, t, t.value);
        }
        if(!con.type.isAlias && !con.type.isStructOrClass()) {
            errorBadSyntax(module_, t, "Expecting a struct name here");
        }

        Variable makeVariable() {
            auto prefix = con.getName();
            if(prefix.contains("__")) prefix = "constructor";
            return b.variable(module_.makeTemporary(prefix), con.type, false);
        }

        /// Prepare the call to new(this, ...)
        auto call       = b.call("new", null);
        Expression expr = call;
        Variable var    = makeVariable();

        /// variable _temp
        con.add(var);

        /// allocate memory
        if(con.type.isPtr) {
            /// Heap calloc

            /// _temp = calloc
            auto calloc  = makeNode!Calloc(t);
            calloc.valueType = con.type.getValueType;
            con.add(b.assign(b.identifier(var.name), calloc));

            call.add(b.identifier(var.name));
        } else {
            /// Stack alloca
            call.add(b.addressOf(b.identifier(var.name)));
        }
        /// Dot
        ///    _temp
        ///    Call new
        ///       _temp
        auto dot = b.dot(b.identifier(var), call);
        con.add(dot);

        /// _temp
        con.add(b.identifier(var));

        /// (
        t.skip(TT.LBRACKET);

        /// Add args to a Parenthesis to act as a ceiling so that
        /// the operator precedence never moves them above the call
        auto parens = makeNode!Parenthesis(t);
        call.add(parens);

        while(t.type!=TT.RBRACKET) {

            if(t.peek(1).type==TT.COLON) {
                /// paramname = expr

                if(parens.numChildren>1 && call.paramNames.length==0) {
                    module_.addError(con, "Mixing named and un-named constructor arguments", true);
                }

                /// Add the implicit 'this' param
                if(parens.numChildren==0) {
                    call.paramNames ~= "this";
                }

                if(call.paramNames.contains(t.value)) {
                    module_.addError(t, "Duplicate call param name", true);
                }
                if(t.value=="this") {
                    module_.addError(t, "'this' cannot be used as a parameter name", true);
                }

                call.paramNames ~= t.value;
                t.next;

                t.skip(TT.COLON);

                parse(t, parens);

            } else {
                if(call.paramNames.length>0) {
                    module_.addError(con, "Mixing named and un-named constructor arguments", true);
                }
                parse(t, parens);
            }

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        /// )
        t.skip(TT.RBRACKET);

        /// Move args to con and discard parens
        while(parens.hasChildren) {
            call.add(parens.first());
        }
        parens.detach();
    }
    void parseAddressOf(Tokens t, ASTNode parent) {

        auto a = makeNode!AddressOf(t);
        parent.add(a);

        t.skip(TT.AMPERSAND);

        parse(t, a);
    }
    void parseValueOf(Tokens t, ASTNode parent) {

        auto v = makeNode!ValueOf(t);
        parent.add(v);

        t.skip(TT.ASTERISK);

        parse(t, v);
    }
    ///
    /// if   ::= "if" "(" [ var  ";" ] expression ")" then [ else ]
    /// then ::= [ "{" ] {statement} [ "}" ]
    /// else ::= "else" [ "{" ] {statement}  [ "}" ]
    ///
    void parseIf(Tokens t, ASTNode parent) {
        auto i = makeNode!If(t);
        parent.add(i);

        /// if
        t.skip("if");

        /// (
        t.skip(TT.LBRACKET);

        /// possible init expressions
        auto inits = Composite.make(t, Composite.Usage.INLINE_KEEP);
        i.add(inits);

        bool hasInits() {
            auto end = t.findInScope(TT.RBRACKET);
            auto sc  = t.findInScope(TT.SEMICOLON);
            return sc!=-1 && end!=-1 && sc < end;
        }

        if(hasInits()) {
            while(t.type!=TT.SEMICOLON) {

                stmtParser().parse(t, inits);

                t.expect(TT.COMMA, TT.SEMICOLON);
                if(t.type==TT.COMMA) t.next;
            }
            t.skip(TT.SEMICOLON);
        }
        /// condition
        parse(t, i);

        /// )
        t.skip(TT.RBRACKET);

        auto then = Composite.make(t, Composite.Usage.INNER_KEEP);
        i.add(then);

        /// then block
        if(t.type==TT.LCURLY) {
            t.skip(TT.LCURLY);

            while(t.type!=TT.RCURLY) {
                stmtParser().parse(t, then);
            }
            t.skip(TT.RCURLY);

        } else {
            stmtParser().parse(t, then);
        }

        /// else block
        if(t.isKeyword("else")) {
            t.skip("else");

            auto else_ = Composite.make(t, Composite.Usage.INNER_KEEP);
            i.add(else_);

            if(t.type==TT.LCURLY) {
                t.skip(TT.LCURLY);

                while(t.type!=TT.RCURLY) {
                    stmtParser().parse(t, else_);
                }
                t.skip(TT.RCURLY);

            } else {
                stmtParser().parse(t, else_);
            }
        }
    }
    ///
    /// select_expr ::= "select" "(" [ { stmt } ";" ] expr ")" "{" { case } else_case "}"
    /// case        ::= const_expr ":" (expr | "{" expr "}" )
    /// else_case   ::= "else"     ":" (expr | "{" expr "}" )
    ///
    /// select    ::= "select" "{" { case } else_case "}"
    /// case      ::= expr   ":" ( expr | "{" expr "}" )
    /// else_case ::= "else" ":" ( expr | "{" expr "}" )
    ///
    void parseSelect(Tokens t, ASTNode parent) {
        auto s = makeNode!Select(t);
        parent.add(s);

        /// select
        t.skip("select");

        if(t.type==TT.LBRACKET) {
            ///
            /// select switch
            ///
            s.isSwitch = true;

            /// (
            t.skip(TT.LBRACKET);

            /// possible init expressions
            auto inits = Composite.make(t, Composite.Usage.INLINE_KEEP);
            s.add(inits);

            bool hasInits() {
                auto end = t.findInScope(TT.RBRACKET);
                auto sc  = t.findInScope(TT.SEMICOLON);
                return sc!=-1 && end!=-1 && sc < end;
            }

            if(hasInits()) {
                while(t.type!=TT.SEMICOLON) {

                    stmtParser().parse(t, inits);

                    t.expect(TT.COMMA, TT.SEMICOLON);
                    if(t.type==TT.COMMA) t.next;
                }
                t.skip(TT.SEMICOLON);
            }

            /// value
            parse(t, s);

            /// )
            t.skip(TT.RBRACKET);
        }
        /// {
        t.skip(TT.LCURLY);

        int countDefaults = 0;
        int countCases    = 0;

        ///
        /// Cases
        ///
        void parseCase() {
            auto comp = Composite.make(t, Composite.Usage.INNER_KEEP);

            if(t.isKeyword("else")) {
                t.next;
                s.add(comp);
                countDefaults++;
                t.skip(TT.COLON);
            } else {
                countCases++;
                auto case_ = makeNode!Case(t);
                s.add(case_);

                while(t.type!=TT.COLON) {
                    /// expr
                    parse(t, case_);

                    t.expect(TT.COMMA, TT.COLON);
                    if(t.type==TT.COMMA) {
                        if(!s.isSwitch) {
                            module_.addError(t, "Boolean-style Select can not have multiple expressions", true);
                        }
                        t.next;
                    }
                }

                t.skip(TT.COLON);

                case_.add(comp);
            }

            if(t.type==TT.LCURLY) {
                /// Multiple statements
                t.skip(TT.LCURLY);

                while(t.type!=TT.RCURLY) {
                    stmtParser().parse(t, comp);
                }
                t.skip(TT.RCURLY);
            } else {
                /// Must be just a single statement
                stmtParser().parse(t, comp);
            }
        }
        while(t.type!=TT.RCURLY) {
            parseCase();
        }
        /// }
        t.skip(TT.RCURLY);

        if(countDefaults == 0) {
            module_.addError(s, "Select must have an else clause", true);
        } else if(countDefaults > 1) {
            module_.addError(s, "Select can only have one else clause", true);
        }
        if(countCases==0) {
            module_.addError(s, "Select must have at least one non-default clause", true);
        }
    }
    void parseModuleAlias(Tokens t, ASTNode parent, Import imp) {

        auto alias_ = makeNode!ModuleAlias(t);
        alias_.mod  = imp.mod;
        alias_.imp  = imp;

        parent.add(alias_);

        t.next;
    }
    /// @typeOf, @sizeOf etc...
    ///
    void parseBuiltinFunc(Tokens t, ASTNode parent) {
        // @
        t.skip(TT.AT);

        auto bif = makeNode!BuiltinFunc(t);
        parent.add(bif);

        bif.name = t.value;
        t.next;

        /// ( or {
        if(t.type==TT.LBRACKET) {
            t.skip(TT.LBRACKET);

            /// Add args to a Parenthesis to act as a ceiling so that
            /// the operator precedence never moves them above the call
            auto parens = makeNode!Parenthesis(t);
            bif.add(parens);

            while(t.type!=TT.RBRACKET) {
                parse(t, parens);

                t.expect(TT.RBRACKET, TT.COMMA);
                if(t.type==TT.COMMA) t.next;
            }

            /// Extract children from the parens
            while(parens.hasChildren) {
                bif.add(parens.first());
            }
            parens.detach();

            /// )
            t.skip(TT.RBRACKET);

        } else if(t.type==TT.LCURLY) {
            t.skip(TT.LCURLY);

            auto c = Composite.make(bif, Composite.Usage.INNER_KEEP);
            bif.add(c);

            while(t.type!=TT.RCURLY) {
                stmtParser.parse(t, c);
            }
            t.skip(TT.RCURLY);
        }
    }
}

