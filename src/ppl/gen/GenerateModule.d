module ppl.gen.GenerateModule;

import ppl.internal;

const DEBUG = false;

final class GenerateModule {
private:
    Module module_;
    StopWatch watch;
    GenerateBinary genBinary;
    GenerateLiteral genLiteral;
    GenerateEnum genEnum;
    GenerateIf genIf;
    GenerateFunction genFunction;
    GenerateSelect genSelect;
    GenerateStruct genStruct;
    GenerateLoop genLoop;
    GenerateVariable genVariable;
public:
    LLVMWrapper llvm;
    LLVMBuilder builder;
    LLVMValueRef lhs;
    LLVMValueRef rhs;
    LLVMBasicBlockRef currentBlock;

    LLVMValueRef[string] structMemberThis;  /// key = struct.getUniqueName

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    this(Module module_, LLVMWrapper llvm) {
        this.module_     = module_;
        this.llvm        = llvm;
        this.builder     = llvm.builder;
        this.genBinary   = new GenerateBinary(this);
        this.genLiteral  = new GenerateLiteral(this);
        this.genEnum     = new GenerateEnum(this);
        this.genFunction = new GenerateFunction(this, genLiteral);
        this.genIf       = new GenerateIf(this);
        this.genSelect   = new GenerateSelect(this);
        this.genStruct   = new GenerateStruct(this);
        this.genLoop     = new GenerateLoop(this);
        this.genVariable = new GenerateVariable(this);
    }
    void clearState() {
        watch.reset();
    }
    bool generate() {
        watch.start();
        log("Generating IR for module %s", module_.canonicalName);

        static if(DEBUG) dd("Generating IR for module", module_.canonicalName);

        this.lhs = null;
        this.rhs = null;

        if(module_.llvmValue !is null) {
           module_.llvmValue.destroy();
        }
        module_.llvmValue = llvm.createModule(module_.canonicalName);

        generateGlobalStrings();

        genVariable.generate(module_);
        genStruct.generate(module_);
        genEnum.generate(module_);
        genFunction.generate(module_);

        visitChildren(module_);

        writeLL(module_, "ir/");

        bool result = verify();
        watch.stop();
        return result;
    }
    //======================================================================================
    void visit(AddressOf n) {
        n.expr().visit!GenerateModule(this);

        rhs = lhs;
    }
    void visit(As n) {
        n.left.visit!GenerateModule(this);

        rhs = castType(rhs, n.left().getType, n.getType, "as");
    }
    void visit(Binary n) {
        genBinary.generate(n);
    }
    void visit(Break n) {
        genLoop.generate(n);
    }
    void visit(BuiltinFunc n) {
        switch(n.name) {
            case "expect":

                auto e = n.exprs();

                e[0].visit!GenerateModule(this);
                auto first = castType(rhs, e[0].getType, n.type);

                e[1].visit!GenerateModule(this);
                auto second = castType(rhs, e[1].getType, n.type);

                auto f = module_.llvmValue.getOrAddIntrinsicFunction("expect", n.type.getLLVMType);

                rhs = builder.ccall(f, [first, second]);

                break;
            default:
                compilerError(n);
                assert(false);
        }
    }
    void visit(Call n) {
        Type returnType       = n.target.returnType;
        Type[] funcParamTypes = n.target.paramTypes;
        LLVMValueRef[] argValues;

        foreach(i, e; n.children[]) {
            e.visit!GenerateModule(this);
            argValues ~= castType(rhs, e.getType, funcParamTypes[i]);
        }

        if(n.target.isMemberVariable) {

            /// Get the "this" variable
            auto v = n.target.getVariable;
            if(v.isStructVar && !v.isStatic) {
                auto ns = v.getStruct;
                assert(ns);

                lhs = structMemberThis[ns.name];
            }

            int index = n.target.getMemberIndex();

            lhs = builder.getElementPointer_struct(lhs, index);
            rhs = builder.load(lhs, "rvalue");
            rhs = builder.call(rhs, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isMemberFunction) {
            assert(n.target.llvmValue, "llvmValue is null %s %s".format(n, n.target));
            rhs = builder.call(n.target.llvmValue, argValues, LLVMCallConv.LLVMFastCallConv);

            //if(rhs.getType.isPointer) {
            //    int index = n.target.structMemberIndex;
            //    lhs = builder.getElementPointer_struct(rhs, index);
            //}

        } else if(n.target.isVariable) {
            rhs = builder.load(n.target.llvmValue);
            rhs = builder.call(rhs, argValues, LLVMCallConv.LLVMFastCallConv);
        } else if(n.target.isFunction) {
            assert(n.target.llvmValue, "Function llvmValue is null: %s".format(n.target.getFunction));
            rhs = builder.call(n.target.llvmValue, argValues, n.target.getFunction().getCallingConvention());
        }

        if((returnType.isStruct || returnType.isTuple) &&
           (n.parent.isDot || n.parent.isA!Parenthesis) &&
           !returnType.isPtr)
        {
            /// Special case for returning struct values.
            /// We need to store the result locally
            /// so that we can take a pointer to it
            lhs = builder.alloca(returnType.getLLVMType(), "retValStorage");
            builder.store(rhs, lhs);
        }
    }
    void visit(Composite n) {
        visitChildren(n);
    }
    void visit(Continue n) {
        genLoop.generate(n);
    }
    void visit(Constructor n) {
        visitChildren(n);
    }
    void visit(Dot n) {
        n.left.visit!GenerateModule(this);

        if(n.left.getType.isPtr) {
            if(n.left.getType.getPtrDepth>1) {
                assert(false, "wasn't expecting this to happen!!!!");
            }
            /// automatically dereference the pointer
            lhs = rhs; //builder.load(gen.lhs);
        }

        n.right.visit!GenerateModule(this);
    }
    void visit(Enum n) {

    }
    void visit(EnumMember n) {
        auto enum_    = n.type;
        auto llvmType = enum_.getLLVMType;
        assert(llvmType);

        n.expr().visit!GenerateModule(this);
        auto elementValue = castType(rhs, n.expr().getType, enum_.elementType);

        if(isConst(elementValue)) {
            rhs = constNamedStruct(llvmType, [elementValue]);
        } else {
            /// Do it the long-winded way
            lhs = builder.alloca(llvmType, "temp_enum");
            rhs = builder.insertValue(builder.load(lhs), elementValue, 0);
        }
    }
    void visit(EnumMemberValue n) {

        n.expr().visit!GenerateModule(this);

        rhs = builder.extractValue(rhs, 0);
    }
    void visit(ExpressionRef n) {
        n.expr().visit!GenerateModule(this);
    }
    void visit(Function n) {
        if(n.isExtern) return;

        assert(n.llvmValue);
        n.getBody().visit!GenerateModule(this);
    }
    void visit(Identifier n) {
        if(n.target.isMemberFunction) {
            assert(false, "%s line %s".format(n.name, n.line+1));
            //int index = n.target.structMemberIndex;
            //lhs = builder.getElementPointer_struct(lhs, index);
            //rhs = builder.load(lhs);
        } else if(n.target.isMemberVariable) {
            /// Get the "this" variable
            auto v = n.target.getVariable;
            if(!n.parent.isDot && v.isStructVar && !v.isStatic) {
                auto ns = n.target.getVariable.getStruct;
                assert(ns);

                lhs = structMemberThis[ns.name];
            }

            int index = n.target.getMemberIndex();
            lhs = builder.getElementPointer_struct(lhs, index);
            rhs = builder.load(lhs);
        } else if(n.target.isFunction) {
            assert(n.target.llvmValue);

            rhs = n.target.llvmValue;
        } else if(n.target.isVariable) {
            assert(n.target.llvmValue, "null llvmValue %s".format(n.target.getVariable));
            lhs = n.target.llvmValue;
            rhs = builder.load(lhs);
        }
    }
    void visit(If n) {
        genIf.generate(n);
    }
    void visit(Index n) {
        n.index().visit!GenerateModule(this);
        rhs = castType(rhs, n.index().getType, TYPE_INT, "cast");
        LLVMValueRef arrayIndex = rhs;

        n.expr().visit!GenerateModule(this);

        if(n.isArrayIndex) {

            auto indices = [constI32(0), arrayIndex];
            lhs = builder.getElementPointer_inBounds(lhs, indices);

        } else if(n.isTupleIndex) {
            // todo - handle "this"?

            lhs = builder.getElementPointer_struct(lhs, n.getIndexAsInt());

        } else if(n.isPtrIndex) {

            auto indices = [arrayIndex];
            lhs = builder.getElementPointer_inBounds(rhs, indices);

        } else assert(false);

        rhs = builder.load(lhs);
    }
    void visit(Initialiser n) {
        visitChildren(n);
    }
    void visit(Is n) {
        n.left.visit!GenerateModule(this);
        auto left = castType(rhs, n.leftType(), n.rightType());

        n.right.visit!GenerateModule(this);
        auto right = rhs;

        auto predicate = n.negate ? LLVMIntPredicate.LLVMIntNE : LLVMIntPredicate.LLVMIntEQ;

        auto cmp = builder.icmp(predicate, left, right);
        rhs = castI1ToI8(cmp);
    }
    void visit(Lambda n) {
        assert(n.llvmValue);
        rhs = n.llvmValue;
    }
    void visit(LiteralArray n) {
        genLiteral.generate(n);
    }
    void visit(LiteralFunction n) {
        assert(!n.isLambda);
        genLiteral.generate(n, n.getLLVMValue);
    }
    void visit(LiteralNull n) {
        genLiteral.generate(n);
    }
    void visit(LiteralNumber n) {
        genLiteral.generate(n);
    }
    void visit(LiteralString n) {
        genLiteral.generate(n);
    }
    void visit(LiteralTuple n) {
        genLiteral.generate(n);
    }
    void visit(Loop n) {
        genLoop.generate(n);
    }
    void visit(ModuleAlias n) {

    }
    void visit(Parameters n) {
        auto litFunc   = n.getLiteralFunction();
        auto llvmValue = litFunc.getLLVMValue();
        auto params    = getFunctionParams(llvmValue);

        foreach(i, v; n.getParams()) {
            v.visit!GenerateModule(this);
            builder.store(params[i], lhs);

            /// Remember values of "this" so that we can access member variables later
            if(v.name=="this") {
                auto ns = v.type.getStruct;
                assert(ns);

                rhs = builder.load(lhs, "this");
                structMemberThis[ns.name] = params[i]; // rhs
            }
        }
    }
    void visit(Parenthesis n) {
        n.expr().visit!GenerateModule(this);
    }
    void visit(Return n) {
        if(n.hasExpr) {
            n.expr().visit!GenerateModule(this);
            rhs = castType(rhs, n.expr().getType, n.getReturnType());
            builder.ret(rhs);
        } else {
            builder.retVoid();
        }
    }
    void visit(Select n) {
        genSelect.generate(n);
    }
    void visit(Struct n) {

    }
    void visit(Tuple n) {

    }
    void visit(TypeExpr n) {
        /// ignore
    }
    void visit(Unary n) {

        n.expr().visit!GenerateModule(this);

        if(n.op is Operator.BOOL_NOT) {
            rhs = forceToBool(rhs, n.expr().getType);
            rhs = builder.not(rhs, "not");
        } else if(n.op is Operator.BIT_NOT) {
            rhs = builder.not(rhs, "not");
        } else if(n.op is Operator.NEG) {
            auto op = n.getType.isReal ? LLVMOpcode.LLVMFSub : LLVMOpcode.LLVMSub;
            rhs = builder.binop(op, n.expr().getType.zeroValue, rhs);
        }
    }
    void visit(ValueOf n) {
        n.expr().visit!GenerateModule(this);

        lhs = builder.getElementPointer_inBounds(rhs, [constI32(0)]);
        rhs = builder.load(rhs, "valueOf");
    }
    void visit(Variable n) {
        if(n.isGlobal) {

        } else if(n.isTupleVar) {

        } else if(n.isStructVar) {

        } else {
            //// it must be a local/parameter

            lhs = builder.alloca(n.type.getLLVMType(), n.name);

            n.llvmValue = lhs;

            if(n.hasInitialiser) {
                n.initialiser.visit!GenerateModule(this);
                //gen.rhs = gen.castType(left, b.leftType, cmpType);

                //log("assign: %s to %s", n.initialiser.getType, n.type);
                //builder.store(rhs, n.llvmValue);
            } else if(!n.isParameter) {
                auto zero = constAllZeroes(n.type.getLLVMType());
                builder.store(zero, n.llvmValue);
            }
        }
    }
    //============================================================================================
    void visitChildren(ASTNode n) {

        foreach(ch; n.children) {
            static if(DEBUG) {
                if(ch.isFunction) dd(module_.canonicalName, "visit Function", ch.as!Function.name, ch.line+1);
                else dd("  visit", ch.id, n.line+1);
            }
            ch.visit!GenerateModule(this);
        }
    }
    void generateGlobalStrings() {
        foreach(LiteralString[] array; module_.getLiteralStrings()) {
            /// create a global string for only one of these
            auto s = array[0];
            log("Generating string literal decl ... %s", s);
            auto str = constString(s.value);
            auto g   = module_.llvmValue.addGlobal(str.getType);
            g.setInitialiser(str);
            g.setConstant(true);
            g.setLinkage(LLVMLinkage.LLVMInternalLinkage);

            auto llvmValue = builder.bitcast(g, pointerType(i8Type()));
            //// set the same llvmValue on each reference
            foreach(sl; array) {
                sl.llvmValue = llvmValue;
            }
        }
    }
    void setArrayValue(LLVMValueRef arrayPtr, LLVMValueRef value, uint index, string name=null) {
        auto indices = [constI32(0), constI32(index)];
        auto ptr = builder.getElementPointer_inBounds(arrayPtr, indices, name);
        builder.store(value, ptr);
    }
    void setStructValue(LLVMValueRef structPtr, LLVMValueRef value, uint paramIndex, string name=null) {
        //logln("setStructValue(%s = %s index:%s)",
        //	  structPtr.getType.toString, value.getType.toString, paramIndex);
        auto ptr = builder.getElementPointer_struct(structPtr, paramIndex, name);
        //logln("ptr is %s", ptr.getType.toString);
        builder.store(value, ptr);
    }
    LLVMBasicBlockRef createBlock(ASTNode n, string name) {
        auto body_ = n.getAncestor!LiteralFunction();
        assert(body_);
        return body_.getLLVMValue().appendBasicBlock(name);
    }
    void moveToBlock(LLVMBasicBlockRef label) {
        builder.positionAtEndOf(label);
        currentBlock = label;
    }
    ///
	/// Force a possibly non bool value into a proper bool which
	/// has either all bits set or all bits zeroed.
	///
    LLVMValueRef forceToBool(LLVMValueRef v, Type fromType) {
        if(fromType.isBool) return v;
        auto i1 = builder.icmp(LLVMIntPredicate.LLVMIntNE, v, fromType.zeroValue, "tobool");
        return castI1ToI8(i1);
    }
    LLVMValueRef castI1ToI8(LLVMValueRef v) {
        if(v.isI1) {
            return builder.sext(v, i8Type());
        }
        return v;
    }
    /*LLVMValueRef castI8ToI1(LLVMValueRef v) {
		if(v.isI8) {
			return builder.trunc(v, i1Type());
		}
        return v;
    }*/
    LLVMValueRef castType(LLVMValueRef v, Type from, Type to, string name=null) {
        if(from.exactlyMatches(to)) return v;
        //dd("cast", from, to);
        /// cast to different pointer type
        if(from.isPtr && to.isPtr) {
            rhs = builder.bitcast(v, to.getLLVMType, name);
            return rhs;
        }
        if(from.isPtr && to.isInteger) {
            rhs = builder.ptrToInt(v, to.getLLVMType, name);
            return rhs;
        }
        if(from.isInteger && to.isPtr) {
            rhs = builder.intToPtr(v, to.getLLVMType, name);
            return rhs;
        }
        /// real->int or int->real
        if(from.isReal != to.isReal) {
            if(!from.isReal) {
                /// int->real
                rhs = builder.sitofp(v, to.getLLVMType, name);
            } else {
                /// real->int
                rhs = builder.fptosi(v, to.getLLVMType, name);
            }
            return rhs;
        }
        if(from.category()==Type.UNKNOWN) {
            dd("!!!", from.category(), module_.canonicalName);
        }
        /// widen or truncate
        if(from.size < to.size) {
            /// widen
            if(from.isReal) {
                rhs = builder.fpext(v, to.getLLVMType, name);
            } else {
                rhs = builder.sext(v, to.getLLVMType, name);
            }
        } else if(from.size > to.size) {
            /// truncate
            if(from.isReal) {
                rhs = builder.fptrunc(v, to.getLLVMType, name);
            } else {
                rhs = builder.trunc(v, to.getLLVMType, name);
            }
        } else {
            /// Size is the same
            assert(from.isTuple, "castType size is the same - from %s to %s".format(from, to));
            assert(to.isTuple);
            assert(false, "we shouldn't get here");
        }
        return rhs;
    }
    bool verify() {
        log("Verifying %s", module_.canonicalName);
        if(!module_.llvmValue.verify()) {
            log("=======================================");
            module_.llvmValue.dump();
            log("=======================================");
            log("module %s is invalid", module_.canonicalName);
            //llvmmod.verify();
            return false;
        }
        log("finished verifying");
        return true;
    }
}