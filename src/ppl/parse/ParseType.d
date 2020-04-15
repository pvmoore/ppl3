module ppl.parse.ParseType;

import ppl.internal;

final class ParseType {
private:
    Module module_;

    auto moduleParser() { return module_.parser; }
    auto exprParser()   { return module_.exprParser; }
    auto stmtParser()   { return module_.stmtParser; }
    auto varParser()    { return module_.varParser; }
    auto typeFinder()   { return module_.typeFinder; }
    auto typeDetector() { return module_.typeDetector; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Type parseForTemplate(Tokens t, ASTNode node) {
        return parse(t, node, false);
    }
    Type parse(Tokens t, ASTNode node, bool addToNode = true) {
        //dd("parseType", node.id, t.get);
        string value = t.value;
        Type type    = null;

        if(t.value=="fn") {
            /// fn(int a) int
            /// fn putchar(int) int
            type = parseFunctionType(t, node, addToNode);
        } else if(t.value=="struct" && t.peek(1).type==TT.LBRACKET) {
            /// "struct" "("
            type = parseTuple(t, node, addToNode);
        } else if(t.type==TT.AT && t.peek(1).value=="typeOf") {
            type = parseTypeof(t, node, addToNode);
        } else {
            /// built-in type
            int p = g_builtinTypes.get(value, -1);
            if(p!=-1) {
                t.next;
                type = new BasicType(p);
            }
            if(type is null) {
                type = t.get.templateType;
                if(type) t.next;
            }
            if(type is null) {
                type = parseImportAlias(t, node);
            }
            /// Is it a Struct, Enum or Alias?
            if(type is null) {
                type = parseAliasOrEnumOrStruct(t, node);
            }
        }

        if(t.type==TT.LANGLE) {
            errorBadSyntax(module_, t, "Cannot parameterise this type");
        }

        if(type !is null) {

            if(t.type==TT.DBL_COLON) {
                /// Inner type eg.
                /// type:: type2 ::
                ///        ^^^^^^^^ repeat
                /// So far we have type

                /// type2 must be one of: ( Enum | Struct | Struct<...> )

                Alias alias_;

                while(t.type==TT.DBL_COLON) {
                    /// ::
                    t.skip(TT.DBL_COLON);

                    if(t.type!=TT.IDENTIFIER) {
                        errorBadSyntax(module_, t, "Expecting a type name");
                    }

                    /// ( Enum | Struct | Struct<...> )
                    auto a        = Alias.make(t, Alias.Kind.INNER_TYPE);
                    a.name        = t.value;
                    a.moduleName  = module_.canonicalName;
                    t.next;

                    if(!alias_) {
                        a.type = type;
                    } else {
                        a.type = alias_;
                    }

                    /// optional <...>
                    a.setTemplateParams(collectTemplateParams(t, node));

                    alias_ = a;
                }
                if(addToNode) {
                    node.add(alias_);
                }
                type = alias_;
            }

            /// ptr depth
            while(true) {
                int pd = 0;
                while(t.type==TT.ASTERISK) {
                    t.next;
                    pd++;
                }
                type = Pointer.of(type, pd);


                if(t.onSameLine && t.type==TT.LSQBRACKET) {

                    if(t.peek(1).type==TT.RSQBRACKET) {
                        parseSlice(t, type, node, addToNode);
                    } else {
                        type = parseArrayType(t, type, node, addToNode);
                    }

                } else break;
            }
        }

        return type;
    }
private:
    Type parseAliasOrEnumOrStruct(Tokens t, ASTNode node) {

        /// Get the name
        string name = t.value;
        t.markPosition();
        t.next;

        Type[] templateParams = collectTemplateParams(t, node);

        auto type = typeFinder.findType(name, node);
        if(type && templateParams.length>0) {
            type = typeFinder.findTemplateType(type, node, templateParams);
        }
        if(type) {

            if(type.isA!Class) {
                type = Pointer.of(type, 1);
            }

        } else {
            t.resetToMark();
        }
        return type;
    }
    Type parseImportAlias(Tokens t, ASTNode node) {

        auto imp = findImportByAlias(t.value, node);
        if(!imp) return null;

        if(t.peek(1).type!=TT.DOT) return null;

        t.next(2);

        /// Assuming for now that inner structs don't exist,
        /// these are the only valid types:

        /// imp.  alias
        /// imp.  alias<>

        string name = t.value;
        t.next;

        Type type = imp.getAlias(name);
        if(!type) errorMissingType(module_, t, t.value);

        Type[] templateParams = collectTemplateParams(t, node);
        if(templateParams.length>0) {
            type = typeFinder.findTemplateType(type, node, templateParams);
        } else {
            auto alias_ = type.as!Alias;
            module_.buildState.moduleRequired(alias_.moduleName);
        }

        return type;
    }
    ///
    /// "struct" "(" variable { variable } ")"
    ///
    Type parseTuple(Tokens t, ASTNode node, bool addToNode) {

        auto s = makeNode!Tuple(t);
        node.add(s);

        /// "struct("
        t.skip("struct");
        t.skip(TT.LBRACKET);

        /// Statements
        while(t.type!=TT.RBRACKET) {

            varParser().parseTupleMember(t, s);

            t.expect(TT.COMMA, TT.RBRACKET);

            if(t.type==TT.COMMA) t.next;
        }

        /// )
        t.skip(TT.RBRACKET);

        if(!addToNode) {
            s.detach();
        }

        /// Set property access to public
        foreach(n; s.getMemberVariables) {
            n.access = Access.PUBLIC;
        }

        s.setEndPos(t);
        return s;
    }
    ///
    /// Type[]
    ///
    Type parseSlice(Tokens t, Type subtype, ASTNode node, bool addToNode) {
        compilerError(t, "Slice not yet implemented");
        assert(false);
    }
    ///
    /// Type[expr] array
    /// Type[expr][expr][expr] array // any number of sub arrays allowed
    Type parseArrayType(Tokens t, Type subtype, ASTNode node, bool addToNode) {

        if(!addToNode && subtype.isA!ASTNode) {
            subtype.as!ASTNode.detach();
        }

        auto a = makeNode!Array(t);
        node.add(a);

        /// [
        t.skip(TT.LSQBRACKET);

        a.subtype = subtype;

        /// count
        if(t.type!=TT.RSQBRACKET) {
            exprParser().parse(t, a);
        }

        /// ]
        t.skip(TT.RSQBRACKET);

        if(!addToNode) {
            a.detach();
        }
        a.setEndPos(t);
        return a;
    }
    ///
    /// function_type ::= with_name | without_name
    /// without_name  ::= "fn"    "(" [ type { "," type } ] ")" type
    /// with_name     ::= "fn" id "(" [ type { "," type } ] ")" type
    ///
    Type parseFunctionType(Tokens t, ASTNode node, bool addToNode) {

        t.skip("fn");

        if(t.type==TT.LBRACKET) {
            t.skip(TT.LBRACKET);
        } else {
            /// ignore name
            t.skip(TT.IDENTIFIER);
            t.skip(TT.LBRACKET);
        }

        auto f = makeNode!FunctionType(t);
        node.add(f);

        /// args
        while(t.type!=TT.RBRACKET) {

            varParser().parseFunctionTypeParameter(t, f);

            t.expect(TT.RBRACKET, TT.COMMA);
            if(t.type==TT.COMMA) t.next;
        }

        /// If type is fn(void)type then remove the unnecessary void param
        if(f.numChildren==1) {
            auto var = f.first().as!Variable;
            if(var.type.isVoid && var.type.isValue && !var.name) {
                var.detach();
            }
        }

        /// )
        t.skip(TT.RBRACKET);

        /// Return type
        if(t.onSameLine) {
            varParser().parseReturnType(t, f);
        } else {
            module_.addError(t, "Missing function type return type", true);
        }

        if(!addToNode) {
            f.detach();
        }

        f.setEndPos(t);
        return Pointer.of(f, 1);
    }
    /// @typeOf ( expr )
    Type parseTypeof(Tokens t, ASTNode node, bool addToNode) {
        /// @ typeOf
        t.next(2);

        /// (
        t.skip(TT.LBRACKET);

        auto a = Alias.make(Alias.Kind.TYPEOF);
        node.add(a);

        exprParser().parse(t, a);

        /// )
        t.skip(TT.RBRACKET);

        if(!addToNode) {
            a.detach();
        }
        return a;
    }
    Type[] collectTemplateParams(Tokens t, ASTNode node) {
        if(t.type!=TT.LANGLE) return null;

        Type[] templateParams;

        t.skip(TT.LANGLE);

        while(t.type!=TT.RANGLE) {

            t.markPosition();

            auto tt = parse(t, node);
            if(!tt) {
                t.resetToMark();
                errorMissingType(module_, t);
            }
            t.discardMark();

            templateParams ~= tt;

            t.expect(TT.COMMA, TT.RANGLE);
            if(t.type==TT.COMMA) t.next;
        }
        t.skip(TT.RANGLE);

        return templateParams;
    }
}