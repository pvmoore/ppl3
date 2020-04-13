module ppl.parse.DetectType;

import ppl.internal;

final class DetectType {
private:
    Module module_;
public:
    this(Module module_) {
        this.module_ = module_;
    }

    bool isType(Tokens t, ASTNode node, int offset = 0) {
        return endOffset(t, node, offset) != -1;
    }
    ///
    /// Return the offset of the end of the type.
    /// Return -1 if there is no type at current position.
    /// eg.
    ///     int        // returns 0
    ///     int**      // returns 2
    ///     static int // returns 1
    ///     imp.Type   // returns 2
    ///     type::type // returns 2
    ///
    int endOffset(Tokens t, ASTNode node, int offset = 0) {
        t.markPosition();

        int startOffset = t.index();
        bool found      = false;

        t.next(offset);

        if("static"==t.value) t.next;

        if(t.value=="fn") {
            found = possibleFunctionType(t, node);
        } else if(t.type==TT.AT && t.peek(1).value=="typeOf") {
            typeof_(t, node);
            found = true;
        } else if(t.value=="struct" && t.peek(1).type==TT.LBRACKET) {
            found = possibleTuple(t, node);
        } else {
            /// built-in type
            int p = g_builtinTypes.get(t.value, -1);
            if(p!=-1) {
                t.next;
                found = true;
            }
            /// Is it a Struct, Class, Enum or Alias?
            if(!found) {
                auto ty = module_.typeFinder.findType(t.value, node);
                if(ty) {
                    t.next;
                    found = true;
                } 

                /// Consume possible template parameters
                if(t.type==TT.LANGLE) {
                    int eob = t.findEndOfBlock(TT.LANGLE);
                    t.next(eob + 1);
                }

            }
            /// Template type?
            if(!found) {
                if(t.get.templateType) {
                    t.next;
                    found = true;
                }
            }
            /// module alias? eg. imp.Type
            if(!found) {
                found = possibleModuleAlias(t, node);
            }
        }

        if(found) {

            if(t.type==TT.DBL_COLON) {
                //dd(module_.canonicalName, "-- inner type");
                /// Must be an inner type
                /// eg. type1:: type2 ::
                ///             ^^^^^^^^ repeat
                /// So far we have type1

                /// type2 must be one of: ( Enum | Struct | Struct<...> )

                while(t.type==TT.DBL_COLON) {
                    /// ::
                    t.skip(TT.DBL_COLON);

                    /// ( Enum | Struct | Struct<...> )
                    t.next;

                    if(t.type==TT.LANGLE) {
                        auto j = t.findEndOfBlock(TT.LANGLE);
                        if(j==-1) errorBadSyntax(module_, t, "Missing end >");
                        t.next(j+1);
                    }
                }
                //dd("-- end:", t.get);
            }

            while(true) {
                /// ptr depth
                while(t.type==TT.ASTERISK) {
                    t.next;
                }

                /// array declaration eg. int[3][1]
                if(t.onSameLine && t.type==TT.LSQBRACKET) {
                    int end = t.findEndOfBlock(TT.LSQBRACKET);
                    t.next(end + 1);
                } else break;
            }
        }

        int endOffset = t.index();
        t.resetToMark();
        if(!found) return -1;
        return endOffset - startOffset - 1;
    }
private:
    ///
    /// "struct" "("
    ///
    bool possibleTuple(Tokens t, ASTNode node) {

        int end = t.findEndOfBlock(TT.LBRACKET);
        if(end==-1) return false;

        t.next(end+1);
        return true;
    }
    ///
    /// fn(type) type
    ///
    bool possibleFunctionType(Tokens t, ASTNode node) {

        /// "fn"
        t.skip("fn");

        if(t.type!=TT.LBRACKET) return false;

        int end = t.findEndOfBlock(TT.LBRACKET);
        if(end==-1) return false;

        t.next(end+1);

        /// return type
        int end2 = endOffset(t, node);
        if(end2==-1) {
            errorBadSyntax(module_, t, "Function ptr return type is missing");
            return false;
        }

        t.next(end2 + 1);

        return true;
    }
    /// imp.function       // not a type
    /// imp.enum           // must be a type
    /// imp.type<type>*    // must be a type because of the ptr
    /// imp.type           // might be a type. Need to make sire it is not followed by a static var or func
    ///          :: // followed by :: continue and expect another type
    ///          .  // followed by . must be a static var or func
    ///             // else it must be a type
    bool possibleModuleAlias(Tokens t, ASTNode node) {
        //if(module_.canonicalName=="tstructs::test_inner_structs2") dd("possibleModuleAlias", t.get, node.id);

        //if(t.peek(1).type==TT.DBL_COLON) { warn(t, "Deprecated ::"); }

        /// Look for imp .
        ///           0  1
        if(t.peek(1).type!=TT.DOT) return false;

        Import imp = findImportByAlias(t.value, node);
        //if(module_.canonicalName=="tstructs::test_inner_structs2") dd("imp=", imp);
        if(!imp) return false;

        /// ModuleAlias found. The imported symbol should be available.
        /// If it is not an Alias then it must be a function so we return false

        /// imp  .  ?
        ///  0   1  2
        if(!imp.getAlias(t.peek(2).value)) return false;

        /// We have a valid type

        /// imp  . type ?
        ///  0   1  2   3

        int i = 3;

        /// Consume any template params
        if(t.peek(i).type==TT.LANGLE) {
            i = t.findEndOfBlock(TT.LANGLE, i);
            if(i==-1) return false;
            i++;
        }

        /// We now have one of:
        ///   imp.Type
        ///   imp.Type<...>

        /// If the next type is :: it must be an inner type
        //if(t.peek(i).type==TT.DBL_COLON) {
        //    // handle this in endOffset func?
        //    /// Another type follows
        //    assert(false, "implement me");
        //}

        t.next(i);
        return true;
    }
    /// @typeOf ( expr )
    void typeof_(Tokens t, ASTNode node) {
        /// @ typeOf
        t.next(2);

        /// (
        int eob = t.findEndOfBlock(TT.LBRACKET);
        t.next(eob);

        /// )
        t.skip(TT.RBRACKET);
    }
}