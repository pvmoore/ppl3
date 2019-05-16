module ppl.gen.GenerateEnum;

import ppl.internal;

final class GenerateEnum {
    GenerateModule gen;
    LLVMBuilder builder;

    this(GenerateModule gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(Module module_) {
        generateLocalEnumDeclarations(module_);
        generateImportedEnumDeclarations(module_);
    }
private:
    void generateLocalEnumDeclarations(Module module_) {
        foreach(e; module_.getEnumsRecurse()) {
            setTypes(e.getLLVMType(), [e.elementType.getLLVMType], true);
        }
    }
    void generateImportedEnumDeclarations(Module module_) {
        foreach(e; module_.getImportedEnums()) {
            setTypes(e.getLLVMType(), [e.elementType.getLLVMType], true);
        }
    }
}

