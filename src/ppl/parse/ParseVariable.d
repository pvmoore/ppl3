module ppl.parse.ParseVariable;

import ppl.internal;

final class ParseVariable {
private:
    Module module_;

    enum Loc { LOCAL, PARAM, FUNCTYPE_PARAM, RET_TYPE, STRUCT_MEMBER, TUPLE_MEMBER }

    auto exprParser()   { return module_.exprParser; }
    auto typeParser()   { return module_.typeParser; }
    auto typeDetector() { return module_.typeDetector; }
    auto builder()      { return module_.nodeBuilder; }
public:
    this(Module module_) {
        this.module_ = module_;
    }
    Type parseParameterForTemplate(Tokens t, ASTNode parent) {
        Type type;
        if(typeDetector().isType(t, parent)) {
            type = typeParser.parseForTemplate(t, parent);
        }

        if(t.type==TT.COMMA) {
            assert(false);
        } else {
            /// name
            assert(t.type==TT.IDENTIFIER, "type=%s".format(t.get));
            t.next;
        }
        return type;
    }
    /// foo ( type name, b )
    ///       ^^^^^^^^^  ^
    void parseParameter(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.PARAM);
    }
    /// (type name)
    ///  ^^^^^^^^^
    void parseFunctionTypeParameter(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.FUNCTYPE_PARAM);
    }
    /// () type
    ///    ^^^^
    void parseReturnType(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.RET_TYPE);
    }
    /// struct S ( [pub] [static] [var|const] type name ...
    ///            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    void parseStructMember(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.STRUCT_MEMBER);
    }
    /// [int a, int ...
    ///  ^^^^^  ^^^
    void parseTupleMember(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.TUPLE_MEMBER);
    }
    /// func { [const] [var|type] a ...
    ///
    void parseLocal(Tokens t, ASTNode parent) {
        parse(t, parent, Loc.LOCAL);
    }
private:
    ///
    /// type
    /// id
    /// type id
    /// type id "=" expression
    ///
    void parse(Tokens t, ASTNode parent, Loc loc) {
        //dd("variable", t.get);
        auto v = makeNode!Variable(t);
        parent.add(v);

        if(t.value=="pub") {
            switch(loc) {
                case Loc.STRUCT_MEMBER:
                    t.setAccess(Access.PUBLIC);
                    t.next;
                    break;
                default:
                    module_.addError(t, "Visibility modifier not allowed here", true);
                    t.next;
                    break;
            }
        }

        if(parent.isModule && t.access.isPublic) {
            module_.addError(t, "Global variables cannot be public", true);
            t.setAccess(Access.PRIVATE);
        }

        v.type   = TYPE_UNKNOWN;
        v.access = t.access();

        bool seenVar, seenStatic, seenConst, hasExplicitType;

        bool nameRequired() {
            switch(loc) with(Loc) {
                case LOCAL: case PARAM: case STRUCT_MEMBER:
                    return true;
                default:
                    return false;
            }
        }
        bool nameAllowed() {
            switch(loc) with(Loc) {
                case LOCAL: case PARAM: case FUNCTYPE_PARAM: case STRUCT_MEMBER: case TUPLE_MEMBER:
                    return true;
                default:
                    return false;
            }
        }
        bool typeRequired() {
            switch(loc) with(Loc) {
                case STRUCT_MEMBER: case TUPLE_MEMBER: case FUNCTYPE_PARAM: case RET_TYPE:
                    return true;
                default:
                    return false;
            }
        }
        bool staticAllowed() {
            switch(loc) with(Loc) {
                case STRUCT_MEMBER:
                    return true;
                default:
                    return false;
            }
        }
        bool varConstAllowed() {
            switch(loc) with(Loc) {
                case LOCAL:
                    return true;
                default:
                    return false;
            }
        }

        outer: while(true) {
            switch(t.value) {
                case "static":
                    if(!staticAllowed()) module_.addError(t, "'static' not allowed here", true);
                    if(seenStatic) module_.addError(t, "'static' specified more than once", true);
                    v.isStatic = true;
                    seenStatic = true;
                    t.next;
                    break;
                case "const":
                    if(!varConstAllowed()) module_.addError(t, "'const' not allowed here", true);
                    if(seenConst) module_.addError(t, "'const' specified more than once", true);
                    v.isConst  = true;
                    seenConst  = true;
                    t.next;
                    break;
                case "var":
                    if(!varConstAllowed()) module_.addError(t, "'var' not allowed here", true);
                    if(seenVar) module_.addError(t, "'var' specified more than once", true);
                    seenVar     = true;
                    t.next;
                    break;
                default: break outer;
            }
        }

        if(seenVar && seenConst) {
            module_.addError(t, "Cannot be both 'var' and 'const'", true);
        }

        /// Type
        if(typeDetector().isType(t, v)) {
            if(seenVar && !v.isConst) module_.addError(t, "Type without 'const' modifier implies 'var'", true);

            hasExplicitType = true;
            v.type = typeParser.parse(t, v);
            assert(v.type);
        } else {
            /// no explicit type
            if(typeRequired()) {
                module_.addError(t, "Variable type required", false);
            }

            if(!seenVar && !seenConst) {
                if(typeRequired()) {
                    errorMissingType(module_, t, t.value);
                }
                if(t.type==TT.IDENTIFIER && t.peek(1).type==TT.IDENTIFIER) {
                    errorMissingType(module_, t, t.value);
                }
            }
        }

        bool initRequired() {
            return loc==Loc.LOCAL && !hasExplicitType;
        }

        /// Name
        if(loc!=Loc.RET_TYPE && t.type==TT.IDENTIFIER && !t.get.templateType) {
            if(!nameAllowed()) {
                module_.addError(t, "Variable name not allowed here", true);
            }

            v.name = t.value;

            if(v.name=="this") {
                module_.addError(t, "'this' is a reserved word", true);
            }
            t.next;

            /// = Initialiser
            if(t.type == TT.EQUALS) {
                t.next;

                auto ini = makeNode!Initialiser;
                ini.var = v;
                v.add(ini);

                exprParser().parse(t, ini);

            } else {
                if(initRequired()) {
                    module_.addError(v, "Implicitly typed variable requires initialisation", true);
                }
                if(v.isConst) {
                    module_.addError(v, "Const variable must be initialised", true);
                }
            }
        } else {
            if(nameRequired()) {
                module_.addError(t, "Variable name required", false);
            }
        }

        if(v.type.isUnknown && t.type==TT.LANGLE) {
            t.prev;
            module_.addError(v, "Type %s not found".format(t.value), false);
        }

        v.setEndPos(t);
    }
}