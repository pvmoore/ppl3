module ppl.resolve.ResolveIdentifier;

import ppl.internal;

const string VERBOSE = null; //"core::list";

///
/// Resolve an identifier.
/// All identifiers must be found within the same module.
///
final class ResolveIdentifier {
private:
    Module module_;
    ResolveModule resolver;
    FoldUnreferenced foldUnreferenced;
    IdentifierTargetFinder idTargetFinder;
public:
    this(Module module_) {
        this.module_        = module_;
        this.idTargetFinder = new IdentifierTargetFinder(module_);
    }
    this(ResolveModule resolver) {
        this.resolver         = resolver;
        this.foldUnreferenced = resolver.foldUnreferenced;

        this(resolver.module_);
    }
    void resolve(Identifier n) {
        assert(resolver);

        if(!n.target.isResolved) {
            if(n.isStartOfChain()) {
                findLocalOrGlobal(n);
            } else {
                findStructMember(n);
            }
        }

        /// If Identifier target is a const value then just replace with that value
        if(n.isResolved && n.comptime()==CT.YES) {
            auto type = n.target.getType;
            auto var  = n.target.getVariable;
            auto ini  = var.initialiser();
            auto expr = ini.getExpr();

            if(!expr.isResolved) return;

            /// Don't modify n = expr
            if(n.parent.isBinary && n.parent.as!Binary.op==Operator.ASSIGN && n.parent.as!Binary.left() is n) {
                return;
            }

            if(type.isValue) {

                if(type.isEnum) {

                    if(n.parent.isA!EnumMemberValue) {
                        /// EnumMemberValue
                        ///     ID:b (type=A) [comptime] Target: VAR b A

                        /// Extract the EnumMember value (which may be a literal)

                        if(expr.isA!ExpressionRef) {
                            /// ExpressionRef reference=EnumMember

                            expr = expr.as!ExpressionRef.reference;
                        }

                        if(expr.isA!EnumMember) {
                            /// EnumMember
                            ///     4

                            expr = expr.as!EnumMember.expr();
                        }

                        if(!expr || !expr.isResolved) return;

                        type = expr.getType();

                    }
                    else if(expr.isA!ExpressionRef && expr.as!ExpressionRef.reference.isA!EnumMember) {

                        auto em     = expr.as!ExpressionRef.reference.as!EnumMember;
                        auto newRef = ExpressionRef.make(expr.as!ExpressionRef.reference);

                        foldUnreferenced.fold(n, newRef);
                        return;
                    }
                }

                if(type.isInteger || type.isReal || type.isBool) {

                    auto cct = expr.as!CompileTimeConstant;
                    if(cct) {
                        foldUnreferenced.fold(n, cct.copy());
                        return;
                    }
                }
            }
        }
    }
private:
    void findLocalOrGlobal(Identifier n) {

        auto res = idTargetFinder.find(n.name, n);

        if(res is null) {
            module_.addError(n, "identifier '%s' not found".format(n.name), true);
            return;
        }

        if(res.isA!Function) {
            auto func = res.as!Function;

            module_.buildState.moduleRequired(func.moduleName);

            if(func.isMember()) {
                auto ns = n.getAncestor!Struct();
                assert(ns);

                n.target.set(func);
            } else {
                /// Global, local or parameter
                n.target.set(func);
            }
        } else {
            Variable var = res.as!Variable;

            if(var.isStructVar() || var.isClassVar()/* && !var.isStatic*/) {

                auto msg = var.isStatic ?
                    "Struct static access requires the struct class name eg. %s.%s".format(var.getStruct().name, n.name) :
                    "Struct member access requires this eg. this.%s".format(n.name);

                module_.addError(n, msg, true);
                return;

            } else if(var.isTupleVar) {
                auto tuple = n.getAncestor!Tuple();
                assert(tuple);

                n.target.set(var);

            } else {
                /// Global, local or parameter
                n.target.set(var);
            }

            /// If var is unknown we need to do some detective work...
            if(var.type.isUnknown && n.parent.isA!Binary) {
                auto bin = n.parent.as!Binary;
                if(bin.op == Operator.ASSIGN) {
                    auto opposite = bin.otherSide(n);
                    if(opposite && opposite.getType.isKnown) {
                        var.setType(opposite.getType);
                    }
                }
            }
        }
    }
    void findStructMember(Identifier n) {
        Expression prev = n.prevLink();
        Type prevType   = prev.getType;

        if(!prevType.isKnown) return;

        /// Current structure:
        ///
        /// Dot
        ///    prev
        ///    ptr
        ///
        auto dot = n.parent.as!Dot;
        assert(dot);

        // check this - it might be ok since each dot resolves itself in order
        // todo - this dot may not be the one we want if we have a complex chain eg imp::static.length
        //        In this case we might need a findStartOfChain method

        /// Properties:
        switch(n.name) {
            case "length":
                if(prevType.isArray) {
                    int len = prevType.getArrayType.countAsInt();
                    foldUnreferenced.fold(dot, LiteralNumber.makeConst(len.to!string, TYPE_INT));
                    return;
                } else if(prevType.isTuple) {
                    int len = prevType.getTuple.numMemberVariables();
                    foldUnreferenced.fold(dot, LiteralNumber.makeConst(len.to!string, TYPE_INT));
                    return;
                } else if(prevType.isEnum) {
                    int len = prevType.getEnum.numChildren;
                    foldUnreferenced.fold(dot, LiteralNumber.makeConst(len.to!string, TYPE_INT));
                    return;
                }
                break;
            case "subtype":
                // todo change this to elementtype

                /// for arrays only
                if(prevType.isArray) {
                    foldUnreferenced.fold(dot, TypeExpr.make(prevType.getArrayType.subtype));
                    return;
                } else if(prevType.isEnum) {
                    assert(false, "implement me");
                }
                break;
            case "ptr": {
                if(resolver.isAStaticTypeExpr(prev)) break;

                auto b = module_.nodeBuilder;
                As as;
                if(prevType.isArray) {
                    as = b.as(b.addressOf(prev), Pointer.of(prevType.getArrayType.subtype, 1));
                } else if(prevType.isTuple) {
                    as = b.as(b.addressOf(prev), Pointer.of(prevType.getTuple, 1));
                } else {
                    break;
                }
                if(prevType.isPtr) {
                    assert(false, "array is a pointer. handle this %s %s %s".format(prevType, module_.canonicalName, n.line));
                }
                /// As
                ///   AddressOf
                ///      prev
                ///   type*
                foldUnreferenced.fold(dot, as);
                return;
            }
            case "value":
                /// Enum.ONE.value
                if(prevType.isEnum) {
                    auto em = prev.as!EnumMember;
                    if(em) {
                        foldUnreferenced.fold(dot, em.expr());
                        return;
                    } else {
                        /// identifier.value
                        auto emv  = makeNode!EnumMemberValue;
                        emv.enum_ = prevType.getEnum;
                        emv.add(dot.left());

                        foldUnreferenced.fold(dot, emv);
                        return;
                    }
                }
                break;
            default:
                break;
        }

        if(!prevType.isStruct && !prevType.isTuple && !prevType.isEnum) {
            module_.addError(prev, "Left of identifier %s must be a struct or enum type not a %s (prev=%s)".format(n.name, prevType, prev), true);
            return;
        }

        Variable var;

        /// Is it an enum member?
        Enum e = prevType.getEnum;
        if(e) {
            /// Replace Dot with EnumMember
            auto em = e.member(n.name);
            if(!em) {
                module_.addError(n, "Enum member %s not found".format(n.name), true);
                return;
            }

            foldUnreferenced.fold(dot, ExpressionRef.make(em));
            return;
        }

        /// Is it a static member?
        Struct struct_ = prevType.getStruct;
        if(struct_) {
            var = struct_.getStaticVariable(n.name);
            if(var) {

                if(!prev.isA!TypeExpr) {
                    module_.addError(n, "Use static syntax eg. %s.%s".format(prevType, var.name), true);
                }

                n.target.set(var);
                return;
            }
        }

        /// It must be an instance member
        Tuple tuple = prevType.getTuple;
        assert(tuple || struct_);

        if(tuple) {
            var = tuple.getMemberVariable(n.name);
            if(!var) {
                module_.addError(n, "Tuple member '%s' not found".format(n.name), true);
                return;
            }
        } else {
            var = struct_.getMemberVariable(n.name);
            if(!var) {
                module_.addError(n, "Struct '%s' does not have member '%s'".format(struct_.name, n.name), true);
                return;
            }
        }

        if(var) {
            n.target.set(var);

            if(module_.config.nullChecks) {
                if(prevType.isPtr && prev.isIdentifier) {
                    auto id = prev.getIdentifier();

                    module_.nodeBuilder.addNullCheck(id);
                }
            }
        }
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        static if(VERBOSE) {
            if(module_.canonicalName==VERBOSE) {
                dd(format(fmt, args));
            }
        }
    }
}