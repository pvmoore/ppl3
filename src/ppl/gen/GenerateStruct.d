module ppl.gen.GenerateStruct;

import ppl.internal;

final class GenerateStruct {
    GenerateModule gen;
    LLVMBuilder builder;

    this(GenerateModule gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(Module module_) {
        generateImportedStructDeclarations(module_);
        generateLocalStructDeclarations(module_);
    }
private:
    void generateImportedStructDeclarations(Module module_) {
        foreach(s; module_.getImportedStructs()) {
            setTypes(s.getLLVMType(), s.getLLVMTypes(), s.isPacked);
        }
    }
    void generateLocalStructDeclarations(Module module_) {
        foreach(s; module_.getStructsRecurse()) {
            setTypes(s.getLLVMType(), s.getLLVMTypes(), s.isPacked);
        }
    }
}

