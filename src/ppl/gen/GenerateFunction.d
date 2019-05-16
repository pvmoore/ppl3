module ppl.gen.GenerateFunction;

import ppl.internal;

final class GenerateFunction {
    GenerateModule gen;
    GenerateLiteral genLiteral;
    LLVMBuilder builder;

    this(GenerateModule gen, GenerateLiteral genLiteral) {
        this.gen        = gen;
        this.genLiteral = genLiteral;
        this.builder    = gen.builder;
    }
    void generate(Module module_) {
        /// Generate declarations
        generateStandardFunctionDeclarations(module_);
        generateImportedFunctionDeclarations(module_);
        generateLocalStructFunctionDeclarations(module_);
        generateLambdaDeclarations(module_);

        /// Generate bodies
        generateLocalStructMemberFunctionBodies(module_, genLiteral);
        generateLambdaBodies(module_, genLiteral);
    }
private:
    void generateStandardFunctionDeclarations(Module module_) {
        foreach(f; module_.getFunctions()) {
            generateFunctionDeclaration(module_, f);
        }
    }
    void generateImportedFunctionDeclarations(Module module_) {
        foreach(f; module_.getImportedFunctions) {
            generateFunctionDeclaration(module_, f);
        }
    }
    void generateLocalStructFunctionDeclarations(Module module_) {
        foreach(ns; module_.getStructsRecurse()) {
            foreach(f; ns.getMemberFunctions()) {
                generateFunctionDeclaration(module_, f);
            }
            foreach(f; ns.getStaticFunctions()) {
                generateFunctionDeclaration(module_, f);
            }
        }
    }
    void generateLocalStructMemberFunctionBodies(Module module_, GenerateLiteral literalGen) {
        foreach(ns; module_.getStructsRecurse()) {
            foreach(f; ns.getMemberFunctions()) {
                auto litFunc = f.getBody();
                literalGen.generate(litFunc, f.llvmValue);
            }
            foreach(f; ns.getStaticFunctions()) {
                auto litFunc = f.getBody();
                literalGen.generate(litFunc, f.llvmValue);
            }
        }
    }
    void generateLambdaDeclarations(Module module_) {
        foreach(c; module_.getLambdas()) {
            generateLambdaDeclaration(module_, c);
        }
    }
    void generateLambdaBodies(Module module_, GenerateLiteral literalGen) {
        foreach(c; module_.getLambdas()) {
            auto litFunc = c.getBody();
            literalGen.generate(litFunc, c.llvmValue);
        }
    }
    void generateLambdaDeclaration(Module m, Lambda c) {
        auto litFunc = c.getBody();
        auto type    = litFunc.type.getFunctionType;

        auto func = m.llvmValue.addFunction(
            c.name,
            type.returnType.getLLVMType,
            type.paramTypes.map!(it=>it.getLLVMType).array,
            LLVMCallConv.LLVMFastCallConv
        );
        c.llvmValue = func;

        if(m.config.enableInlining) {
            addFunctionAttribute(func, LLVMAttribute.InlineHint);
        }
        addFunctionAttribute(func, LLVMAttribute.NoUnwind);

        func.setLinkage(LLVMLinkage.LLVMInternalLinkage);
    }
    void generateFunctionDeclaration(Module module_, Function f) {
        auto type = f.getType.getFunctionType;
        auto func = module_.llvmValue.addFunction(
            f.getMangledName(),
            type.returnType.getLLVMType(),
            type.paramTypes().map!(it=>it.getLLVMType()).array,
            f.getCallingConvention()
        );
        f.llvmValue = func;

        auto config = module_.config;

        //// inline
        bool isInline   = false;
        bool isNoInline = false;

        if(!config.enableInlining) {
            isInline = false;
        }

        /// Check if the user has set an attribute
        if(f.attributes.get!InlineAttribute) {
            isInline = true;
        }
        if(f.attributes.get!NoInlineAttribute) {
            isNoInline = true;
        }

        if(isInline) {
            addFunctionAttribute(func, LLVMAttribute.AlwaysInline);
        } else if(isNoInline) {
            addFunctionAttribute(func, LLVMAttribute.NoInline);
        }

        /// We don't support exceptions
        addFunctionAttribute(func, LLVMAttribute.NoUnwind);

        //// linkage
        //if(!f.isExport && f.access==Access.PRIVATE) {

        if(f.isExtern) {
            f.llvmValue.setLinkage(LLVMLinkage.LLVMExternalLinkage);
        } else if(f.numExternalRefs==0 && !f.isProgramEntry) {
            f.llvmValue.setLinkage(LLVMLinkage.LLVMInternalLinkage);
        }


        //if(module_.canonicalName=="test_imports" && f.name=="new") {
        //    dd("!! linkage", f.getUniqueName, f.numExternalRefs, isInline, f.llvmValue.getLinkage);
        //}
    }
}

