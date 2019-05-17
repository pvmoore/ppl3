module ppl.resolve.ResolveModule;

import ppl.internal;

private const bool VERBOSE = false;

final class ResolveModule {
private:
    ResolveAssert assertResolver;
    ResolveAs asResolver;
    ResolveBinary binaryResolver;
    ResolveBuiltinFunc builtinFuncResolver;
    ResolveCalloc callocResolver;
    CallResolver callResolver;
    ResolveConstructor constructorResolver;
    ResolveEnum enumResolver;
    ResolveIf ifResolver;
    ResolveIs isResolver;
    ResolveSelect selectResolver;
    ResolveLiteral literalResolver;
    ResolveIndex indexResolver;
    ResolveUnary unaryResolver;
    ResolveVariable variableResolver;

    StopWatch watch;
    DynamicArray!Callable overloadSet;
    bool addedModuleScopeElements;
    bool modified;
    Set!ASTNode unresolved;
    bool stalemate      = false;
    bool isResolved     = false;
    bool tokensModified = true;
    int iteration       = 0;

public:
    Module module_;
    ResolveIdentifier identifierResolver;

    ulong getElapsedNanos()        { return watch.peek().total!"nsecs"; }
    ASTNode[] getUnresolvedNodes() { return unresolved.values; }
    bool isModified()              { return modified; }
    bool isStalemate()             { return stalemate; }
    int getCurrentIteration()      { return iteration; }

    this(Module module_) {
        this.module_             = module_;
        this.assertResolver      = new ResolveAssert(this, module_);
        this.asResolver          = new ResolveAs(this, module_);
        this.binaryResolver      = new ResolveBinary(this, module_);
        this.builtinFuncResolver = new ResolveBuiltinFunc(this, module_);
        this.callocResolver      = new ResolveCalloc(this, module_);
        this.callResolver        = new CallResolver(this, module_);
        this.constructorResolver = new ResolveConstructor(this, module_);
        this.identifierResolver  = new ResolveIdentifier(this, module_);
        this.enumResolver        = new ResolveEnum(this, module_);
        this.indexResolver       = new ResolveIndex(this, module_);
        this.ifResolver          = new ResolveIf(this, module_);
        this.isResolver          = new ResolveIs(this, module_);
        this.selectResolver      = new ResolveSelect(this, module_);
        this.literalResolver     = new ResolveLiteral(this, module_);
        this.unaryResolver       = new ResolveUnary(this, module_);
        this.variableResolver    = new ResolveVariable(this, module_);
        this.unresolved          = new Set!ASTNode;
        this.overloadSet         = new DynamicArray!Callable;
    }
    void clearState() {
        watch.reset();
        unresolved.clear();
        overloadSet.clear();
        addedModuleScopeElements = false;
        iteration      = 0;
        isResolved     = false;
        tokensModified = true;
    }
    void setModified(ASTNode node) {
        this.modified = true;
        node.setModified(iteration);
    }
    void setModified() {
        isResolved     = false;
        tokensModified = true;
    }

    ///
    /// Pass through any unresolved nodes and try to resolve them.   
    /// Return true if all nodes and aliases are resolved and no modifications occurred.
    ///
    bool resolve(bool isStalemate) {
        watch.start();
        scope(exit) watch.stop();

        this.isResolved     = isResolved && !tokensModified;
        this.tokensModified = false;

        if(this.isResolved) {
            return true;
        }

        this.modified  = false;
        this.stalemate = isStalemate;
        this.iteration++;
        this.unresolved.clear();

        collectModuleScopeElements();

        foreach(r; module_.getCopyOfActiveRoots()) {
            recursiveVisit(r);
        }

        tryToFoldScope(module_);

        this.isResolved = unresolved.length==0 &&
                          modified==false &&
                          addedModuleScopeElements &&
                          !tokensModified;

        return isResolved;
    }
    void resolveFunction(string funcName) {
        watch.start();
        scope(exit) watch.stop();
        log("Resolving %s func '%s'", module_, funcName);

        isResolved = false;

        /// Visit all functions at module scope with the right name
        foreach(n; module_.children) {
            auto f = cast(Function)n;
            if(f && f.name==funcName) {
                log("\t  Adding Function root %s", f);
                module_.addActiveRoot(f);

                /// Don't add reference here. Add it once we have filtered possible
                /// overload sets down to the one we are going to use.
            }
        }
    }
    void resolveAliasEnumOrStruct(string AliasName) {
        watch.start();
        scope(exit) watch.stop();
        log("Resolving %s Alias|enum|struct '%s'", module_, AliasName);

        isResolved = false;

        module_.recurse!Type((it) {
            auto ns = it.as!Struct;
            auto en = it.as!Enum;
            auto al = it.as!Alias;

            if(ns) {
                if(ns.name==AliasName) {
                    if(ns.parent.isModule) {
                        log("\t  Adding Struct root %s", it);
                    }
                    module_.addActiveRoot(ns);
                    ns.numRefs++;
                }
            } else if(en) {
                if(en.name==AliasName) {
                    if(en.parent.isModule) {
                        log("\t  Adding Enum root %s", en);
                    }
                    module_.addActiveRoot(en);
                    en.numRefs++;
                }
            } else if(al) {
                if(al.name==AliasName) {
                    if(al.parent.isModule) {
                        log("\t  Adding Alias root %s", al);
                    }
                    module_.addActiveRoot(al);
                    al.numRefs++;

                    /// Could be a chain of Aliases in different modules
                    if(al.isImport) {
                        module_.buildState.aliasEnumOrStructRequired(al.moduleName, al.name);
                    }
                }
            }
        });
    }
    //=====================================================================================
    void visit(AddressOf n) {
        if(n.expr.id==NodeID.VALUE_OF) {
            auto valueof = n.expr.as!ValueOf;
            auto child   = valueof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(Alias n) {
        if(n.isTypeof) {
            if(n.first.isResolved) {
                n.type     = n.first.getType;
                n.isTypeof = false;
                modified   = true;
                n.first().detach();
                assert(!n.hasChildren());
            }
        } else {
            resolveAlias(n, n.type);
        }
    }
    void visit(Array n) {
        resolveAlias(n, n.subtype);
    }
    void visit(As n) {
        asResolver.resolve(n);
    }
    void visit(Assert n) {
        assertResolver.resolve(n);
    }
    void visit(Binary n) {
        binaryResolver.resolve(n);
    }
    void visit(Break n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Break statement must be inside a loop", true);
            }
        }
    }
    void visit(BuiltinFunc n) {
        builtinFuncResolver.resolve(n);
    }
    void visit(Call n) {
        callResolver.resolve(n);
    }
    void visit(Calloc n) {
        callocResolver.resolve(n);
    }
    void visit(Case n) {

    }
    void visit(Composite n) {
        switch(n.usage) with(Composite.Usage) {
            case PLACEHOLDER:
                /// If children==1 -> replace with child
                /// else           -> Don't remove
                if(n.numChildren==1) {
                    auto child = n.first();
                    fold(n, child);
                }
                break;
            case INNER_REMOVABLE:
            case INLINE_REMOVABLE:
                /// If it's empty then just remove it
                if(n.numChildren==0) {
                    fold(n);
                    break;
                }
                /// If there is only a compile time constant in this scope then fold
                if(n.numChildren==1) {
                    auto cct = n.first().as!CompileTimeConstant;
                    if(cct) {
                        fold(n, cct.copy());
                    }
                }
                break;
            default:
                break;
        }
    }
    void visit(Continue n) {
        if(!n.isResolved) {
            n.loop = n.getAncestor!Loop;
            if(n.loop is null) {
                module_.addError(n, "Continue statement must be inside a loop", true);
            }
        }
    }
    void visit(Constructor n) {
        constructorResolver.resolve(n);
    }
    void visit(Dot n) {
        auto lt      = n.leftType();
        auto rt      = n.rightType();
        auto builder = module_.builder(n);

        /// Rewrite Enum::A where A is also a type declared elsewhere
        //if(lt.isEnum && n.right().isTypeExpr) {
        //    auto texpr = n.right().as!TypeExpr;
        //    if(texpr.isResolved) {
        //        auto id = builder.identifier(texpr.toString());
        //        fold(n.right(), id);
        //        return ;
        //    }
        //}
    }
    void visit(Enum n) {
        enumResolver.resolve(n);
    }
    void visit(EnumMember n) {

    }
    void visit(EnumMemberValue n) {

    }
    void visit(ExpressionRef n) {

    }
    void visit(Function n) {

    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {
        identifierResolver.resolve(n);
    }
    void visit(If n) {
        ifResolver.resolve(n);
    }
    void visit(Import n) {

    }
    void visit(Index n) {
        indexResolver.resolve(n);
    }
    void visit(Initialiser n) {
        n.resolve();
    }
    void visit(Is n) {
        isResolver.resolve(n);
    }
    void visit(Lambda n) {

    }
    void visit(LiteralArray n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralFunction n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralMap n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralNull n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralNumber n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralString n) {
        literalResolver.resolve(n);
    }
    void visit(LiteralTuple n) {
        literalResolver.resolve(n);
    }
    void visit(Loop n) {

    }
    void visit(Module n) {

    }
    void visit(ModuleAlias n) {

    }
    void visit(Struct n) {

    }
    void visit(Parameters n) {

    }
    void visit(Parenthesis n) {
        assert(n.numChildren==1);

        /// We don't need any Parentheses any more
        fold(n, n.expr());
    }
    void visit(Return n) {

    }
    void visit(Select n) {
        selectResolver.resolve(n);
    }
    void visit(Tuple n) {

    }
    void visit(TypeExpr n) {
        resolveAlias(n, n.type);
    }
    void visit(Unary n) {
        unaryResolver.resolve(n);
    }
    void visit(ValueOf n) {
        if(n.expr.id==NodeID.ADDRESS_OF) {
            auto addrof = n.expr.as!AddressOf;
            auto child  = addrof.expr;
            fold(n, child);
            return;
        }
    }
    void visit(Variable n) {
        variableResolver.resolve(n);
    }
    //==========================================================================
    void writeAST() {
        if(!module_.config.writeAST) return;

        //dd("DUMP MODULE", module_);

        auto f = new FileLogger(module_.config.targetPath~"ast/" ~ module_.fileName~".ast");
        scope(exit) f.close();

        module_.dump(f);

        f.log("==============================================");
        f.log("======================== Unresolved Nodes (%s)", unresolved.length);

        foreach (i, n; unresolved.values) {
            f.log("\t[%s] Line %s %s", i, n.line, n);
        }
        f.log("==============================================");
    }
    void fold(ASTNode replaceMe, ASTNode withMe, bool dereference = true) {

        auto p = replaceMe.parent;

        setModified(replaceMe);
        setModified(withMe);

        p.replaceChild(replaceMe, withMe);

        if(dereference) {
            recursiveDereference(replaceMe);
        }
        modified = true;

        /// Ensure active roots remain valid
        module_.addActiveRoot(withMe);
    }
    void fold(ASTNode removeMe, bool dereference = true) {
        if(dereference) {
            recursiveDereference(removeMe);
        }
        setModified(removeMe);
        removeMe.detach();
        modified = true;
    }


    bool isAStaticTypeExpr(Expression expr) {
        auto exprType       = expr.getType;
        bool isStaticAccess = exprType.isValue;
        if(isStaticAccess) {
            switch(expr.id) with(NodeID) {
                case CONSTRUCTOR:
                case IDENTIFIER:
                case COMPOSITE:
                    isStaticAccess = false;
                    break;
                case DOT:
                    auto d = expr.as!Dot;
                    if(d.left.id==MODULE_ALIAS) {
                        isStaticAccess = d.right().isTypeExpr;
                    } else {
                        isStaticAccess = false;
                        //assert(false, "implement me %s.%s %s %s".format(d.left.id, d.right.id, expr.line+1, module_.canonicalName));
                    }
                    break;
                case INDEX:
                    isStaticAccess = false;
                    break;
                case TYPE_EXPR:
                    break;
                case VALUE_OF:
                    isStaticAccess = false;
                    break;
                default:
                    assert(false, "implement me %s %s %s".format(expr.id, expr.line+1, module_.canonicalName));
            }
        }
        return isStaticAccess;
    }
    ///
    /// If type is a Alias then we need to resolve it
    ///
    void resolveAlias(ASTNode node, ref Type type) {
        if(!type.isAlias) return;

        auto alias_ = type.getAlias;

        /+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ inner +/
        void resolveTo(Type toType) {
            type     = Pointer.of(toType, type.getPtrDepth);
            modified = true;

            auto node = cast(ASTNode)toType;
            if(node) {
                auto access = node.getAccess();
                if(access.isPrivate && module_.nid!=node.getModule().nid) {
                    module_.addError(alias_, "Type %s is private".format(node), true);
                }
            }

            if(alias_.parent && alias_.parent.id==NodeID.IMPORT) {
                /// This is an import alias. Leave it attached
            } else if(!type.isAlias) {
                //dd("!! detaching alias", alias_);

                if(alias_.isInnerType) {
                    alias_.detach();
                }
            }
        }
        /+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/

        /// Handle import
        if(alias_.isImport) {
            auto m = module_.buildState.getOrCreateModule(alias_.moduleName);
            if(!m.isParsed) {
                /// Come back when m is parsed
                return;
            }
            Type externalType = m.getAlias(alias_.name);
            if(!externalType) externalType = m.getStruct(alias_.name);
            if(!externalType) externalType = m.getEnum(alias_.name);
            if(!externalType) {
                module_.addError(module_, "Import %s not found in module %s".format(alias_.name, alias_.moduleName), true);
                return;
            }

            resolveTo(externalType);
            return;
        }

        /// type<...>
        if(alias_.isTemplateProxy) {

            /// Ensure template params are resolved
            foreach(ref t; alias_.templateParams) {
                resolveAlias(node, t);
            }

            /// Resolve until we have the Struct
            if(alias_.type.isAlias) {
                resolveAlias(node, alias_.type);
            }
            if(!alias_.type.isStruct) {
                unresolved.add(alias_);
                return;
            }

            if(!alias_.templateParams.areKnown) {
                unresolved.add(alias_);
                return;
            }
        }
        /// type::type2::type3 etc...
        if(alias_.isInnerType) {

            resolveAlias(node, alias_.type);

            if(alias_.type.isAlias) {
                unresolved.add(alias_);
                return;
            }
        }

        if(alias_.isTemplateProxy || alias_.isInnerType) {

            /// We now have a Struct to work with
            auto ns = alias_.type.getStruct;
            string mangledName;
            if(alias_.isInnerType) {
                mangledName ~= alias_.name;
            } else {
                mangledName ~= ns.name;
            }
            if(alias_.isTemplateProxy) {
                mangledName ~= "<" ~ module_.buildState.mangler.mangle(alias_.templateParams) ~ ">";
            }

            auto t = module_.typeFinder.findType(mangledName, ns, alias_.isInnerType);
            if(t) {
                /// Found
                resolveTo(t);
            } else {

                if(alias_.isInnerType) {
                    /// Find the template blueprint
                    string parentName = ns.name;
                    ns = ns.getInnerStruct(alias_.name);
                    if(!ns) {
                        module_.addError(alias_, "Struct %s does not have inner type %s".format(parentName, alias_.name), true);
                        return;
                    }
                }

                if(alias_.isTemplateProxy) {
                    /// Extract the template
                    auto structModule = module_.buildState.getOrCreateModule(ns.moduleName);
                    structModule.templates.extract(ns, node, mangledName, alias_.templateParams);

                    unresolved.add(alias_);
                }
            }
            return;
        }

        if(alias_.type.isKnown || alias_.type.isAlias) {
            /// Switch to the Aliased type
            resolveTo(alias_.type);
        } else {
            unresolved.add(alias_);
        }
    }
//==========================================================================
private:
    ///
    /// If this is the first time we have looked at this module then add           
    /// all module level variables to the list of roots to resolve
    ///
    void collectModuleScopeElements() {
        if(!addedModuleScopeElements && module_.isParsed) {
            addedModuleScopeElements = true;

            foreach(n; module_.getVariables()) {
                module_.addActiveRoot(n);
            }
        }
    }
    void recursiveVisit(ASTNode m) {

        if(!m.isAttached) return;

        if(m.id==NodeID.STRUCT) {
            if(m.as!Struct.isTemplateBlueprint) return;
        } else if(m.isFunction) {
            auto f = m.as!Function;
            if(f.isTemplateBlueprint) return;
            if(f.isImport) return;
        } else if(m.isAlias) {
            auto a = m.as!Alias;
            if(a.isStandard && !a.type.isAlias) return;
        }

        static if(VERBOSE) {
            dd("  resolve", typeid(m), "nid:", m.nid, module_.canonicalName, "line:", m.line+1);
        }

        /// Resolve children
        foreach(n; m.children[].dup) {
            recursiveVisit(n);
        }

        /// Resolve this node
        m.visit!ResolveModule(this);

        if(!m.isAttached) return;

        if(!m.isResolved) unresolved.add(m);

        /// If this is a scope, do some extra housekeeping
        bool isScope = m.isLiteralFunction |
                      (m.isComposite && m.as!Composite.usage==Composite.Usage.INNER_KEEP) |
                      (m.isComposite && m.as!Composite.usage==Composite.Usage.INNER_REMOVABLE);

        /// Remove any unused nodes in this scope
        if(isScope) {
            tryToFoldScope(m);
        }
    }
    void recursiveDereference(ASTNode n) {
        /// dereference
        if(n.isIdentifier) {
            auto t = n.as!Identifier.target;
            t.dereference();
        } else if(n.isCall) {
            auto t = n.as!Call.target;
            t.dereference();
        } else if(n.isLambda) {
            module_.removeLambda(n.as!Lambda);
        }
        foreach(ch; n.children) {
            recursiveDereference(ch);
        }
    }
    void tryToFoldScope(ASTNode scope_) {

        /// We need all targets inside this scope to be resolved
        Target[] targets;
        scope_.collectTargets(targets);
        if(!targets.all!(it=>it.isResolved)) return;

        foldUnreferencedVariables(scope_);
        foldUnreferencedCalls(scope_);
        foldUnreferencedFunctions(scope_);
    }
    void foldUnreferencedVariables(ASTNode scope_) {
        scope_.recurse!Variable( (v) {
            if(v.isLocalAlloc) {

                if(v.numRefs==0) {
                    /// If numRefs==0 then remove it
                    fold(v);

                } else if(v.numRefs==1) {

                    //'b' Variable[refs=1] (type=int) LOCAL PRIVATE
                    //    Initialiser var=b, type=int
                    //       ASSIGN (type=int)
                    //          ID:b (type=int) Target: VAR b int
                    //          2 (type=const int)

                    /// If the only reference is the initialiser and the
                    /// initialiser is a CompileTimeConstant then the Variable can be removed
                    if(v.hasInitialiser) {
                        auto lit = v.initialiser().getLiteral();
                        auto ctc = lit.as!CompileTimeConstant;
                        if(ctc) {
                            fold(v);
                        }
                    }
                }
            }
        });
    }
    void foldUnreferencedCalls(ASTNode scope_) {
        scope_.recurse!Call( (call) {
            assert(call.target.isResolved);

            if(call.target.isFunction) {
                auto func  = call.target.getFunction;
                auto body_ = func.hasBody() ? func.getBody() : null;
                if(body_) {
                    if(body_.isEmpty()) {
                        /// Function has nothing in it so the call can be removed

                        fold(call);

                    } else if(body_.numStatements()==1) {
                        if(body_.second().isA!Return) {
                            /// Function only has a single statement which is a return.
                            /// If it returns void or a compile time constant
                            /// then we can fold the call
                            auto ret = body_.second().as!Return;
                            if(ret.hasExpr) {
                                auto ctc = ret.expr().as!CompileTimeConstant;
                                if(ctc) {
                                    fold(call, ctc.copy());
                                }
                            } else {
                                fold(call);
                            }
                        }
                    }
                }
            }
        });
    }
    void foldUnreferencedFunctions(ASTNode scope_) {
        scope_.recurse!Function( (f) {

            /// Don't get rid of any constructors
            if(f.name!="new") {

                /// Only look at private functions
                if(f.access.isPrivate) {

                    if(f.numRefs==0) {
                        fold(f);
                    } else {

                    }
                }
            }
        });
    }
}