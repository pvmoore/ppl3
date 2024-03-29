module ppl.check.CheckModule;

import ppl.internal;

///
/// Check semantics after all types have been resolved.
///
final class CheckModule {
private:
    Module module_;
    StopWatch watch;
    Set!string stringSet;
    IdentifierTargetFinder idTargetFinder;
    EscapeAnalysis escapeAnalysis;
    ControlFlow controlFlow;
public:
    this(Module module_) {
        this.module_        = module_;
        this.stringSet      = new Set!string;
        this.escapeAnalysis = new EscapeAnalysis(module_);
        this.controlFlow    = new ControlFlow(module_);
        this.idTargetFinder = new IdentifierTargetFinder(module_);
    }
    void clearState() {
        watch.reset();
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    void check() {
        watch.start();

        recursiveVisit(module_);

        checkAttributes();

        watch.stop();
    }
    //==========================================================================
    void visit(AddressOf n) {

    }
    void visit(Alias n) {
        // Ignore
    }
    void visit(Array n) {
        if(!n.countExpr().isA!LiteralNumber) {
            module_.addError(n.countExpr(), "Array count expression must be a const", true);
        }
    }
    void visit(As n) {
        Type fromType = n.leftType();
        Type toType   = n.rightType();

        if(fromType.isPtr() && toType.isPtr()) {
            /// ok - bitcast pointers
        } else if(fromType.isPtr() && !toType.isInteger()) {
            errorBadExplicitCast(module_, n, fromType, toType);
        } else if(!fromType.isInteger && toType.isPtr) {
            errorBadExplicitCast(module_, n, fromType, toType);
        }
    }
    void visit(Binary n) {

        auto lt = n.leftType();
        auto rt = n.rightType();

        assert(n.numChildren()==2, "Binary numChildren=%s. Expecting 2".format(n.numChildren()));


        if(n.left.isTypeExpr()) {
            module_.addError(n.left(), "Expecting a non-type expression", true);
            return;
        }
        if(n.right.isTypeExpr()) {
            module_.addError(n.right(), "Expecting a non-type expression", true);
            return;
        }

        /// Check the types
        if(n.isPtrArithmetic) {

        } else {
            if(!areCompatible(rt, lt)) {
                module_.addError(n, "Types are incompatible: %s and %s".format(lt, rt), true);
            }
        }

        if(n.op.isAssign()) {

            if(n.op!=Operator.ASSIGN && n.op!=Operator.REASSIGN && lt.isPtr() && rt.isInteger()) {
                /// int* a = 10
                /// a += 10
            } else if(!rt.canImplicitlyCastTo(lt)) {
                errorBadImplicitCast(module_, n, rt, lt);
            }

            /// Check whether we are modifying a const variable
            if(!n.parent.isInitialiser()) {
                auto id = n.left().getIdentifier();
                if(id && id.target.isVariable() && id.target.getVariable().isConst) {
                    module_.addError(n, "Cannot modify const %s".format(id.name), true);
                }
            }
        } else {

        }

        if(n.op==Operator.ASSIGN) {

        }
    }
    void visit(Break n) {

    }
    void visit(BuiltinFunc n) {
        switch(n.name) {
            case "expect":
                if(n.numChildren()!=2) {
                    module_.addError(n, "Expecting two integer expressions", true);
                } else {
                    auto types = n.exprTypes();

                    if(!(types[0].isInteger() || types[0].isBool()) || !types[0].isValue()) {
                        module_.addError(n.children[0], "Expecting an integer expression", true);
                    }
                    if(!(types[1].isInteger() || types[1].isBool()) || !types[1].isValue()) {
                        module_.addError(n.children[1], "Expecting an integer expression", true);
                    }

                }
                break;
            case "ctUnreachable":
                module_.addError(n, "Expected to be unreachable at compile time", true);
                break;
            default:
                compilerError(n, "Builtin %s should not have reached this layer".format(n.name));
                break;
        }
    }
    void visit(Call n) {
        auto paramTypes = n.target.paramTypes();
        auto argTypes   = n.argTypes();

        /// Ensure we have the correct number of arguments
        if(paramTypes.length != argTypes.length) {
            module_.addError(n, "Expecting %s arguments, not %s".format(paramTypes.length, argTypes.length), true);
        }

        /// Ensure the arguments can implicitly cast to the parameters
        foreach(i, p; n.target.paramTypes()) {
            if(!argTypes[i].canImplicitlyCastTo(p)) {
                errorBadImplicitCast(module_, n.arg(i.to!int), argTypes[i], p);
            }
        }

        /// Check access
        if(n.target.isMemberFunction()) {
            checkMemberFunctionAccess(n, n.target.getFunction());
        }
        if(n.target.isMemberVariable()) {
            checkMemberVariableAccess(n, n.target.getVariable());
        }
    }
    void visit(Case n) {

    }
    void visit(Class n) {
        visit(cast(Struct)n);
    }
    void visit(Composite n) {

    }
    void visit(Constructor n) {

    }
    void visit(Continue n) {

    }
    void visit(Dot n) {

    }
    void visit(Enum n) {

    }
    void visit(EnumMember n) {
        /// Must be convertable to element type
        // todo - should have been removed
    }
    void visit(EnumMemberValue n) {
        //dd("!!!!!! we got here", module_.canonicalName, n.line+1, n, ",", n.expr);
        // todo - should have been removed
    }
    void visit(ExpressionRef n) {

    }
    void visit(Function n) {

        if(n.isTemplateBlueprint()) return;

        auto retType = n.getType().getFunctionType().returnType();

        if(n.isVisibleToOtherModules()) {
            checkForExposingPrivateType(n, retType, "Public function return type");
        }

        switch(n.name) {
            case "operator==":
            case "operator!=":
                if(retType.isPtr() || !retType.isBool()) {
                    module_.addError(n, "%s must return bool".format(n.name), true);
                }
                break;
            case "operator[]":
                if(n.params().numParams()==2) {
                    /// get
                    if(retType.isValue() && retType.isVoid()) {
                        module_.addError(n, "operator:(this,int) must not return void", true);
                    }
                } else if(n.params().numParams()==3) {
                    /// set

                }
                break;
            case "__user_main":
                if(retType.isVoid() && retType.isValue()) break; // void ok
                if(retType.category()==Type.INT && retType.isValue()) break; // int ok

                module_.addError(n, "main/WinMain can only return int or void", true);
                break;
            default:
                break;
        }

        //if(!n.isExtern) {
        //    auto body_ = n.getBody();
        //}
    }
    void visit(FunctionType n) {

    }
    void visit(Identifier n) {

        /// Check struct static variables
        if(n.target.isVariable()) {
            auto var = n.target.getVariable();
            if(var.isStatic) {
                checkStaticVariableAccess(n, var);
                checkReadOnlyModification(n, var);
            }
        }

        /// Check struct member variables
        if(n.target.isMemberVariable()) {

            auto var = n.target.getVariable();
            checkMemberVariableAccess(n, var);
            checkReadOnlyModification(n, var);

            /// Check for static access to non-static variable
            if(!var.isStatic) {
                ///
                if(n.parent.isDot()) {
                    auto s = n.previous();
                    // todo
                } else {
                    auto con = n.getContainer();
                    if(con.isFunction()) {
                        if(con.as!LiteralFunction.getFunction().isStatic) {
                            module_.addError(n, "Static access to non-static variable", true);
                        }
                    } else assert(false, "todo");
                }
            }
        }
    }
    void visit(If n) {
        if(n.isExpr()) {
            /// Type must not be void
            if(n.type.isVoid() && n.type.isValue()) {
                module_.addError(n, "If must not have void result", true);
            }

            /// Both then and else are required
            if(!n.hasThen() || !n.hasElse()) {
                module_.addError(n, "If must have both a then and an else result", true);
            }

            /// Don't allow any returns in then or else block
            auto array = new DynamicArray!Return;
            n.selectDescendents!Return(array);
            if(array.length>0) {
                module_.addError(array[0], "An if used as a result cannot return", true);
            }
        }
    }
    void visit(Import n) {

    }
    void visit(Index n) {
        auto lit = n.index().as!LiteralNumber;
        if(lit) {
            /// Index is a const. Check the bounds
            if(n.isArrayIndex()) {
                Array array = n.exprType().getArrayType();
                assert(array);

                auto count = array.countExpr().as!LiteralNumber;
                assert(count);

                if(lit.value.getInt() >= count.value.getInt()) {
                    module_.addError(n, "Array bounds error. %s >= %s".format(lit.value.getInt(), count.value.getInt()), true);
                }
            } else if(n.isTupleIndex()) {

                Tuple tuple = n.exprType().getTuple();
                assert(tuple);

                auto count = tuple.numMemberVariables();
                assert(count);

                if(lit.value.getInt() >= count) {
                    module_.addError(n, "Array bounds error. %s >= %s".format(lit.value.getInt(), count), true);
                }
            } else {
                /// ptr

            }
        } else {
            if(n.isTupleIndex()) {
                module_.addError(n, "Tuple index must be a const number", true);
            }

            /// We could add a runtime check here in debug mode
        }
        if(n.exprType().isKnown()) {

        }
    }
    void visit(Initialiser n) {

    }
    void visit(Is n) {

    }
    void visit(Lambda n) {

    }
    void visit(LiteralArray n) {
        /// Check for too many values
        if(n.length() > n.type.countAsInt()) {
            module_.addError(n, "Too many values specified (%s > %s)".format(n.length(), n.type.countAsInt()), true);
        }

        foreach(i, left; n.elementTypes()) {

            if(!left.canImplicitlyCastTo(n.type.subtype)) {
                errorBadImplicitCast(module_, n.elementValues()[i], left, n.type.subtype);
            }
        }
    }
    void visit(LiteralFunction n) {
        assert(n.first().isA!Parameters);

        /// Check for duplicate Variable names
        Variable[string] map;

        n.recurse!Variable((v) {

            if(v.name) {
                auto ptr = v.name in map;
                if(ptr) {
                    auto v2 = *ptr;

                    bool sameScope = v.parent is v2.parent;

                    if(sameScope) {
                        module_.addError(v, "Variable '%s' is declared more than once in this scope (Previous declaration is on line %s)"
                               .format(v.name, v2.line+1), true);

                    } else if(v.isLocalAlloc()) {

                        /// Check for shadowing
                        auto res = idTargetFinder.find(v.name, v.previous());
                        if(res) {
                            module_.addError(v, "Variable '%s' is shadowing variable declared on line %s".format(v.name, v2.line+1), true);
                        }
                    }
                }
                map[v.name] = v;
            }
        });

        controlFlow.check(n);
        escapeAnalysis.analyse(n);
    }
    void visit(LiteralMap n) {

    }
    void visit(LiteralNull n) {

    }
    void visit(LiteralNumber n) {
        Type* ptr;

        switch(n.parent.id()) with(NodeID) {
            case VARIABLE:
                ptr = &n.parent.as!Variable.type;
                break;
            default: break;
        }

        if(ptr) {
            auto parentType = *ptr;

            if(!n.type.canImplicitlyCastTo(parentType)) {
                errorBadImplicitCast(module_, n, n.type, parentType);
            }
        }
    }
    void visit(LiteralString n) {

    }
    void visit(LiteralTuple n) {
        Tuple tuple = n.type.getTuple();
        assert(tuple);

        auto structTypes = tuple.memberVariableTypes();

        /// Check for too many values
        if(n.numElements() > tuple.numMemberVariables()) {
            module_.addError(n, "Too many values specified", true);
        }

        if(n.numElements()==0) {

        }

        /// Check that the element types match the struct members
        foreach(i, t; n.elementTypes()) {
            auto left  = t;
            auto right = structTypes[i];
            if(!left.canImplicitlyCastTo(right)) {
                errorBadImplicitCast(module_, n.elements()[i], left, right);
            }
        }
    }
    void visit(Loop n ) {

    }
    void visit(Module n) {
        /// Ensure all global variables have a unique name
        stringSet.clear();
        foreach(v; module_.getVariables()) {
            if(stringSet.contains(v.name)) {
                module_.addError(v, "Global variable %s declared more than once".format(v.name), true);
            }
            stringSet.add(v.name);
        }
    }
    void visit(ModuleAlias n) {

    }
    void visit(Parameters n) {
        /// Check that all arg names are unique
        stringSet.clear();
        foreach(i, a; n.paramNames()) {
            if(stringSet.contains(a)) {
                module_.addError(n.getParam(i), "Duplicate parameter name", true);
            }
            stringSet.add(a);
        }
    }
    void visit(Parenthesis n) {

    }
    void visit(Return n) {
        /// Check return type can convert to function return type
        if(n.hasExpr()) {
            auto retType = n.getReturnType();
            if(!n.expr().getType.canImplicitlyCastTo(retType)) {
                errorBadImplicitCast(module_, n.expr(), n.expr().getType, retType);
            }
        }
    }
    void visit(Select n) {
        assert(n.isSwitch);

        /// Check that each clause can be converted to the type of the switch value
        auto valueType = n.valueType();
        foreach(c; n.cases()) {
            foreach(expr; c.conds()) {
                if(!expr.getType.canImplicitlyCastTo(valueType)) {
                    errorBadImplicitCast(module_, expr, expr.getType(), valueType);
                }
            }
        }
        /// Check that all clauses are const integers
        foreach(c; n.cases()) {
            foreach(expr; c.conds()) {
                auto lit = expr.as!LiteralNumber;
                if(!lit || (!lit.getType().isInteger() && !lit.getType().isBool())) {
                    module_.addError(expr, "Switch-style Select clauses must be of const integer type", true);
                }
            }
        }
    }
    void visit(Struct n) {

        stringSet.clear();
        foreach(v; n.getMemberVariables()) {
            /// Variables must have a name
            if(v.name.length==0) {
                module_.addError(v, "Struct variable must have a name", true);
            } else {
                /// Names must be unique
                if(stringSet.contains(v.name)) {
                    module_.addError(v, "Struct %s has duplicate member %s".format(n.name, v.name), true);
                }
                stringSet.add(v.name);
            }
        }
    }
    void visit(Tuple n) {
        stringSet.clear();
        foreach(v; n.getMemberVariables()) {
            /// Names must be unique
            if(v.name) {
                if(stringSet.contains(v.name)) {
                    module_.addError(v, "Tuple has duplicate member %s".format(v.name), true);
                }
                stringSet.add(v.name);
            }
        }
    }
    void visit(TypeExpr n) {

    }
    void visit(Unary n) {

    }
    void visit(ValueOf n) {

        auto et = n.exprType();

        if(et.isValue()) {
            module_.addError(n, "Cannot dereference value type", true);
        } else if(et.isClass() && et.getPtrDepth()==1) {
            module_.addError(n, "Cannot dereference a class type", true);
        }
    }
    void visit(Variable n) {
        if(n.isConst) {

            if(!n.isGlobal() && !n.isStructVar()) {

                /// Initialiser must be const
                //auto ini = n.initialiser();
                //if(ini.comptime()!=CT.YES) {
                //    module_.addError(n, "Const initialiser must be const", true);
                //}
            }
        }
        if(n.isClassVar()) {
            auto class_ = n.getClass();


        }
        if(n.isStructVar()) {

            auto struct_ = n.getStruct();

            if(struct_.isPOD() && !n.access.isPublic()) {
                module_.addError(n, "POD struct member variables must be public", true);
            }
            if(struct_.isVisibleToOtherModules() && n.access.isPublic()) {
                checkForExposingPrivateType(n, n.getType(), "Public struct property");
            }
        }
        if(n.isTupleVar()) {
            auto tuple_ = n.getTuple();


        }
        if(n.isStatic) {
            if(!n.parent.id==NodeID.STRUCT) {
                module_.addError(n, "Static variables are only allowed in a struct", true);
            }
        }
        if(n.type.isStruct()) {

        }

        if(n.type.isTuple()) {
            auto tuple = n.type.getTuple();

            /// Tuples must only contain variable declarations
            foreach(v; tuple.children) {
                if(!v.isVariable()) {
                    module_.addError(n, "A tuple must only contain variable declarations", true);
                } else {
                    auto var = cast(Variable)v;
                    if(var.hasInitialiser) {
                        module_.addError(n, "A tuple must not have variable initialisation", true);
                    }
                }
            }
        }
        if(n.isParameter) {
            Statement funcOrLambda = n.getFunctionOrLambda();
            assert(funcOrLambda);

            if(funcOrLambda.isFunction) {
                auto func = funcOrLambda.as!Function;
                if(func.isVisibleToOtherModules()) {
                    checkForExposingPrivateType(n, n.getType(), "Public function parameter");
                }
            }

        }
        if(n.isLocalAlloc) {

        }
        if(n.isGlobal) {

        }
    }
    //==========================================================================
private:
    void recursiveVisit(ASTNode m) {
        //dd("check", typeid(m));
        m.visit!CheckModule(this);
        foreach(n; m.children) {
            recursiveVisit(n);
        }

        if(m.endPos == INVALID_POSITION) {
            assert(m.line==-1 && m.column==-1);
        }
    }
    void checkAttributes() {

        void check(ASTNode node, Attribute a) {
            bool ok = true;
            final switch(a.type) with(Attribute.Type) {
                case INLINE:
                    ok = node.isFunction;
                    break;
                case NOINLINE:
                    ok = node.isFunction;
                    break;
                case LAZY:
                    ok = node.isFunction;
                    break;
                case MEMOIZE:
                    ok = node.isFunction;
                    break;
                case MODULE:
                    ok = node.isModule;
                    break;
                case NOTNULL:
                    break;
                case PACKED:
                    ok = node.id==NodeID.STRUCT;
                    break;
                case POD:
                    ok = node.id==NodeID.STRUCT;
                    break;
                case PROFILE:
                    ok = node.isFunction;
                    break;
                case MIN:
                case MAX:
                    ok = node.isVariable;
                    break;
                case NOOPT:
                    ok = node.isFunction;
                    break;
            }

            if(!ok) {
                module_.addError(node, "%s attribute cannot be applied to %s".
                    format(a.name, node.id.to!string.toLower), true);
            }
        }

        module_.recurse!ASTNode((n) {
            auto attribs = n.attributes;
            foreach(a; attribs) {
                check(n, a);
            }
            if(n.attributes.get!InlineAttribute && n.attributes.get!NoInlineAttribute) {
                module_.addError(n, "--inline and --noinline attributes are mutually exclusive", true);
            }
        });
    }
    /**
     * Disallow if:
     *  TargetVar is not public AND
     *  Self and targetVar are not in the same module
     */
    void checkMemberVariableAccess(ASTNode self, Variable targetVar) {
        /// Target is public
        if(targetVar.access.isPublic) return;

        auto inSameModule = self.getModule() == targetVar.getModule();

        Struct targetStruct = targetVar.getStruct;
        // Struct thisStruct     = self.getAncestor!Struct;
        // bool isExternalAccess = (thisStruct is null) || thisStruct != targetStruct;

        if(!inSameModule) {

            module_.addError(self, "%s property %s is private".format(targetStruct.name, targetVar.name), true);
        }
    }
    /**
     * Disallow if:
     *  TargetVar is not public AND
     *  Self and targetVar are not in the same module
     */
    void checkStaticVariableAccess(ASTNode self, Variable targetVar) {
        /// Target is public
        if(targetVar.access.isPublic) return;

        auto inSameModule = self.getModule() == targetVar.getModule();

        Struct targetStruct = targetVar.getStruct;
        // Struct thisStruct = self.getAncestor!Struct;
        // if(!thisStruct) {
        //     /// It might be in the module new function
        //     auto ini = self.getAncestor!Initialiser;
        //     if(ini) {
        //         auto f = self.getAncestor!Function;
        //         if(f && f.isModuleConstructor()) {
        //             thisStruct = targetStruct;
        //         }
        //     }
        // }
        // bool isExternalAccess = (thisStruct is null) || thisStruct != targetStruct;

        if(!inSameModule) {
            module_.addError(self, "%s static property %s is private".format(targetStruct.name, targetVar.name), true);
        }
    }
    /**
     * Disallow if:
     *  TargetFunc is not public AND
     *  Self and targetVar are not in the same module
     */
    void checkMemberFunctionAccess(ASTNode self, Function targetFunc) {
        /// Target is public
        if(targetFunc.access.isPublic) return;

        auto inSameModule = self.getModule() == targetFunc.getModule();

        Struct targetStruct = targetFunc.getStruct;
        // Struct thisStruct     = self.getAncestor!Struct;
        // bool isExternalAccess = (thisStruct is null) || thisStruct != targetStruct;

        if(!inSameModule) {
            module_.addError(self, "Function %s.%s is private".format(targetStruct.name, targetFunc.name), true);
        }
    }
    /**
     * Disallow if:
     *  Self and targetVar are not in the same module AND
     *  Self is a modification
     */
    void checkReadOnlyModification(ASTNode self, Variable targetVar) {
        /// Tuple properties are always public and modifiable
        if(targetVar.isTupleVar) return;

        Struct targetStruct = targetVar.getStruct;

        /// POD struct properties are always public and modifiable
        if(targetStruct.isPOD) return;

        auto inSameModule = self.getModule() == targetVar.getModule();

        // auto access       = targetVar.access;
        // Struct thisStruct = self.getAncestor!Struct;
        // bool isExternalAccess = (thisStruct is null) || thisStruct != targetStruct;

    //    // allow writing to indexed pointer value
    //    auto idx = findAncestor!Index;
    //    if(idx) return;N
    //

        if(!inSameModule) {

            auto binary = self.getAncestor!Binary;
            auto isModification = binary && binary.op.isAssign && self.isDescendentOf(binary.left);

            if(isModification) {

                auto msg = targetVar.isStatic ?
                    "%s static property %s can only be modified by code in the same module".format(targetStruct.name, targetVar.name) :
                    "%s property %s can only be modified by code in the same module".format(targetStruct.name, targetVar.name);

                module_.addError(self, msg, true);
            }
        }
    }
    /**
     *
     */
    void checkForExposingPrivateType(ASTNode node, Type t, string msgPrefix = null) {
        auto struct_ = t.getStruct();
        auto enum_   = t.getEnum();
        auto array   = t.getArrayType();
        auto tuple_  = t.getTuple();

        Type errorType;

        if(struct_) {
            if(!struct_.access.isPublic) errorType = struct_;

        } else if(array) {
            checkForExposingPrivateType(node, array.subtype, msgPrefix);
        } else if(enum_) {
            if(!enum_.access.isPublic) errorType = enum_;
        } else if(tuple_) {
            foreach(v; tuple_.getMemberVariables()) {
                checkForExposingPrivateType(v, v.getType(), msgPrefix);
            }
        }

        if(errorType) {
            msgPrefix = msgPrefix ? msgPrefix~" " : "";
            module_.addError(node, msgPrefix ~ "type %s is not externally visible".format(errorType), true);
        }
    }
}