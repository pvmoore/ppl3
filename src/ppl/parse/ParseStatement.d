module ppl.parse.ParseStatement;

import ppl.internal;

private const string VERBOSE_MODULE = null; //"test";

final class ParseStatement {
private:
    Module module_;

    auto structParser() { return module_.structParser; }
    auto varParser()    { return module_.varParser; }
    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto exprParser()   { return module_.exprParser; }
    auto funcParser()   { return module_.funcParser; }
    auto attrParser()   { return module_.attrParser; }

    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }

    void parse(Tokens t, ASTNode parent) {
        static if(VERBOSE_MODULE) {
            if(module_.canonicalName==VERBOSE_MODULE) {
                dd("[", module_.canonicalName, "] statement line:", t.line+1, " parent:", parent.id, "token:", t.get);
                //scope(exit) dd("end statement line:", t.line+1);
            }
        }

        // Check for statements on the same line that are not separated by semicolons
        if(t.type != TT.SEMICOLON && t.onSameLine && !t.peek(-1).type.isOneOf(TT.SEMICOLON, TT.COMMA)) {
            auto lastChild = parent.last;
            if(lastChild) {
                if(parent.id!=NodeID.STRUCT &&
                   !lastChild.isParameters &&
                   !lastChild.isComposite)
                {
                    warn(t, "Statement on the same line: %s %s %s".format(parent.id, lastChild.id, t.get()));
                }
            }
        }

        consumeAttributes(t, parent);
        if(!t.hasNext) return;

        /// Handle access

        /// Default to private access
        t.setAccess(Access.PRIVATE);

        if(t.type==TT.IDENTIFIER) {
            if("pub"==t.value) {

                checkPubAccess(t, parent);

                t.setAccess(Access.PUBLIC);
                t.next;
            }
        }

        if(t.type==TT.IDENTIFIER)  {
            switch(t.value) {
                case "alias":
                    parseAlias(t, parent);
                    return;
                case"assert":
                    parseAssert(t, parent);
                    return;
                case "break":
                    parseBreak(t, parent);
                    return;
                case "const":
                    varParser().parseLocal(t, parent);
                    return;
                case "continue":
                    parseContinue(t, parent);
                    return;
                case "enum":
                    parseEnum(t, parent);
                    return;
                case "extern":
                    funcParser().parseExtern(t, parent);
                    return;
                case "if":
                    noExprAllowedAtModuleScope(t, parent);
                    exprParser.parse(t, parent);
                    return;
                case "import":
                    parseImport(t, parent);
                    return;
                case"loop":
                    parseLoop(t, parent);
                    return;
                case "ret":
                    parseReturn(t, parent);
                    return;
                case "select":
                    noExprAllowedAtModuleScope(t, parent);
                    exprParser.parse(t, parent);
                    return;
                case "static":
                    /// static type name
                    /// static type name =
                    /// static name {
                    /// static name <

                    /// static fn
                    if(t.peek(1).value=="fn") {
                        funcParser().parse(t, parent);
                    } else if(t.peek(2).type==TT.LCURLY) {
                        funcParser().parse(t, parent);
                    } else if (t.peek(2).type==TT.LANGLE) {
                        funcParser().parse(t, parent);
                    } else {
                        if(parent.isA!Struct) {
                            module_.addError(t, "Struct properties are not allowed in the body", true);
                            varParser().parseStructMember(t, parent);
                        } else {
                            /// Consume this token
                            module_.addError(t, "'static' not allowed here", true);
                            t.next;
                        }
                    }
                    return;
                case "struct":
                    /// Could be a struct/tuple decl

                    if(t.peek(1).type==TT.LBRACKET) {
                        /// "struct" "("
                        varParser().parseLocal(t, parent);
                    } else {
                        /// "struct" id "{"
                        /// "struct" id "<"
                        structParser().parse(t, parent);
                    }
                    return;
                case "fn":
                    if(t.peek(1).type==TT.LBRACKET) {
                        /// fn()type
                        varParser().parseLocal(t, parent);
                    } else {
                        /// fn id(
                        funcParser().parse(t, parent);
                    }
                    return;
                default:
                    break;
            }
        }
        switch(t.type) with(TT) {
            case SEMICOLON:
                t.next;
                return;
            case TT.PIPE:
                /// Lambda
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
                return;
            case AT:
                if(t.peek(1).value=="typeOf") {
                    // must be a variable decl
                    varParser().parseLocal(t, parent);
                    return;
                }
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
                return;
            //case LBRACKET:
            //    errorBadSyntax(module_, t, "Parenthesis not allowed here");
            //    break;
            default:
                break;
        }

        /// type
        /// type .
        /// type (
        /// type is
        auto node = parent;
        if(node.hasChildren) node = node.last();
        int eot = typeDetector().endOffset(t, node);
        if(eot!=-1) {
            /// First token is a type so this could be one of:
            /// constructor, variable declaration, type.xxx or is_expr
            auto nextTok = t.peek(eot+1);

            if(nextTok.type==TT.DOT) {
                /// dot
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else if(nextTok.type==TT.LBRACKET) {
                /// Constructor
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else if(nextTok.value=="is") {
                /// is
                noExprAllowedAtModuleScope(t, parent);
                exprParser.parse(t, parent);
            } else {
                /// Variable decl
                varParser().parseLocal(t, parent);
            }

            return;
        }

        /// name < ... > (      // call
        /// name<...> |a| {     // call with lambda arg
        /// name<...> {         // call with lambda arg
        if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.LANGLE) {
            int end;
            if(ParseHelper.isTemplateParams(t, 1, end)) {
                auto nextTok = t.peek(end+1);
                auto ntt     = nextTok.type;

                if(ntt==TT.LCURLY || ntt==TT.PIPE || ntt==TT.LBRACKET) {
                    /// Ok
                } else {
                    errorMissingType(module_, t, t.value);
                }
            }
        }

        /// Test for 'Type type' where Type is not known
        if(parent.isModule && t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
            errorMissingType(module_, t, t.value);
        }

        /// It must be an expression
        noExprAllowedAtModuleScope(t, parent);
        exprParser.parse(t, parent);
    }
private: //=============================================================================== private
    void consumeAttributes(Tokens t, ASTNode parent) {
        while(t.type==TT.DBL_LSQBRACKET) {
            attrParser().parse(t, parent);
        }
    }
    void checkPubAccess(Tokens t, ASTNode parent) {

        /// "pub" is only valid at module or struct scope:
        auto p = parent; if(p.isComposite || p.isA!Placeholder) p = p.parent;
        if(!p.isModule && !p.isA!Struct) {
            module_.addError(t, "'pub' visibility modifier not allowed here", true);
            return;
        }

        /// The only valid subsequent statements are:
        ///     - Module/struct scope function decl
        ///     - Module/struct scope struct decl
        ///     - Module/struct scope enum decl
        ///     - Module scope alias
        auto n = t.peek(1);

        if(n.value=="fn") return;
        if(n.value=="static" && t.peek(2).value=="fn") return;
        if(n.value=="extern" && t.peek(2).value=="fn") return;
        if(n.value=="struct") return;
        if(n.value=="enum") return;
        if(n.value=="alias") return;

        bool isType = typeDetector().isType(t, parent, 1);
        if(!isType) {
            module_.addError(t, "'pub' visibility modifier not allowed here", true);
        }
    }
    void noExprAllowedAtModuleScope(Tokens t, ASTNode parent) {
        if(parent.isA!Module) {
            errorBadSyntax(module_, t, "Expressions not allowed at module scope");
        }
    }
    /// import       ::= "import" [identifier "="] module_paths
    /// module_path  ::= identifier { "::" identifier }
    /// module_paths ::= module_path { "," module-path }
    ///
    void parseImport(Tokens t, ASTNode parent) {

        /// "import"
        t.next;

        while(true) {
            auto imp = makeNode!Import(t);
            parent.add(imp);

            string collectModuleName() {
                string moduleName = t.value;
                t.markPosition();
                t.next;

                while(t.type==TT.DBL_COLON) {
                    t.next;
                    moduleName ~= "::";
                    moduleName ~= t.value;
                    t.next;
                }

                /// Check that the import exists
                import std.file : exists;
                if(!exists(module_.config.getFullModulePath(moduleName))) {
                    t.resetToMark();
                    module_.addError(t, "Module %s does not exist".format(moduleName), false);
                }
                t.discardMark();
                return moduleName;
            }

            if(t.peek(1).type==TT.EQUALS) {
                /// module_alias = canonicalName
                imp.aliasName = t.value;
                t.next(2);

                if(findImportByAlias(imp.aliasName, imp.previous())) {
                    module_.addError(imp, "Module alias %s already found in this scope".format(imp.aliasName), true);
                }
            }

            imp.moduleName = collectModuleName();

            if(findImportByCanonicalName(imp.moduleName, imp)) {
                module_.addError(imp, "Module %s already imported".format(imp.moduleName), true);
            }

            /// Trigger the loading of the module
            imp.mod = module_.buildState.getOrCreateModule(imp.moduleName);

            /// For each exported function and type, add proxies to this module
            foreach(f; imp.mod.parser.publicFunctions.values) {
                auto fn       = makeNode!Function(t);
                fn.name       = f;
                fn.moduleName = imp.moduleName;
                fn.isImport   = true;
                imp.add(fn);
            }
            foreach(d; imp.mod.parser.publicTypes.values) {
                auto def        = Alias.make(t);
                def.name        = d;
                def.type        = TYPE_UNKNOWN;
                def.moduleName  = imp.moduleName;
                def.isImport    = true;
                imp.add(def);
            }

            if(t.type==TT.COMMA) {
                t.next;
            } else break;
        }
    }
    ///
    /// alias ::= "alias" identifier "=" type
    ///
    void parseAlias(Tokens t, ASTNode parent) {

        auto alias_ = Alias.make(t);
        parent.add(alias_);

        alias_.access = t.access();

        /// "alias"
        t.skip("alias");

        /// identifier
        alias_.name = t.value;
        t.next;

        /// =
        t.skip(TT.EQUALS);

        /// type
        alias_.type = typeParser().parse(t, alias_);
        //dd("alias_", alias_.name, "type=", alias_.type, "root=", alias_.getRootType);

        alias_.isImport   = false;
        alias_.moduleName = module_.canonicalName;
    }
    ///
    /// return_statement ::= "return" [ expression ]
    ///
    void parseReturn(Tokens t, ASTNode parent) {

        auto r = makeNode!Return(t);
        parent.add(r);

        int line = t.get().line;

        /// return
        t.next;

        /// [ expression ]
        /// This is a bit of a hack.
        /// If there is something on the same line and it's not a '}'
        /// then assume there is a return expression
        if(t.type!=TT.RCURLY && t.get().line==line) {
            exprParser().parse(t, r);
        }
    }
    void parseAssert(Tokens t, ASTNode parent) {
        t.skip("assert");

        auto a = makeNode!Assert(t);
        parent.add(a);

        exprParser().parse(t, a);
    }
    void parseBreak(Tokens t, ASTNode parent) {

        auto b = makeNode!Break(t);
        parent.add(b);

        t.skip("break");
    }
    void parseContinue(Tokens t, ASTNode parent) {
        auto c = makeNode!Continue(t);
        parent.add(c);

        t.skip("continue");
    }
    void parseLoop(Tokens t, ASTNode parent) {

        auto loop = makeNode!Loop(t);
        parent.add(loop);

        t.skip("loop");

        t.skip(TT.LBRACKET);

        /// Init statements (must be Variables or Binary)
        auto inits = Composite.make(t, Composite.Usage.INLINE_KEEP);
        loop.add(inits);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Expecting loop initialiser");

        while(t.type!=TT.SEMICOLON) {

            parse(t, inits);

            t.expect(TT.COMMA, TT.SEMICOLON);
            if(t.type==TT.COMMA) t.next;
        }

        t.skip(TT.SEMICOLON);

        if(t.type==TT.RBRACKET) errorBadSyntax(module_, t, "Expecting loop condition");

        /// Condition
        auto cond = Composite.make(t, Composite.Usage.INNER_KEEP);
        loop.add(cond);
        if(t.type!=TT.SEMICOLON) {
            exprParser().parse(t, cond);
        } else {

        }

        t.skip(TT.SEMICOLON);

        /// Post loop expressions
        auto post = Composite.make(t, Composite.Usage.INNER_KEEP);
        loop.add(post);
        while(t.type!=TT.RBRACKET) {

            exprParser().parse(t, post);

            t.expect(TT.COMMA, TT.RBRACKET);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RBRACKET);

        t.skip(TT.LCURLY);

        /// Body statements
        auto body_ = Composite.make(t, Composite.Usage.INNER_KEEP);
        loop.add(body_);

        while(t.type!=TT.RCURLY) {
            parse(t, body_);
        }
        t.skip(TT.RCURLY);
    }
    void parseEnum(Tokens t, ASTNode parent) {

        auto e = makeNode!Enum(t);
        parent.add(e);

        e.access = t.access();

        /// enum
        t.skip("enum");

        /// name
        e.name       = t.value;
        e.moduleName = module_.canonicalName;
        t.next;

        /// : type (optional)
        if(t.type==TT.COLON) {
            t.next;

            e.elementType = typeParser.parse(t, e);
        }

        /// {
        t.skip(TT.LCURLY);

        while(t.type!=TT.RCURLY) {

            auto value = makeNode!EnumMember(t);
            e.add(value);

            /// name
            value.name = t.value;
            value.type = e;
            t.next;

            if(t.type==TT.EQUALS) {
                t.next;

                exprParser().parse(t, value);
            }

            t.expect(TT.COMMA, TT.RCURLY);
            if(t.type==TT.COMMA) t.next;
        }

        /// }
        t.skip(TT.RCURLY);
    }
}

