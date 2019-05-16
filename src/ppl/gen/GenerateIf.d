module ppl.gen.GenerateIf;

import ppl.internal;

final class GenerateIf {
    GenerateModule gen;
    LLVMBuilder builder;

    this(GenerateModule gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(If n) {
        auto ifLabel   = gen.createBlock(n, "if");
        auto thenLabel = gen.createBlock(n, "then");
        auto elseLabel = n.hasElse ? gen.createBlock(n, "else") : null;
        auto endLabel  = gen.createBlock(n, "endif");

        LLVMValueRef[]      phiValues;
        LLVMBasicBlockRef[] phiBlocks;

        builder.br(ifLabel);

        /// If
        gen.moveToBlock(ifLabel);

        /// inits
        if(n.hasInitExpr) {
            n.initExprs().visit!GenerateModule(gen);
        }

        /// condition
        n.condition.visit!GenerateModule(gen);

        auto cmp = builder.icmp(LLVMIntPredicate.LLVMIntNE, gen.rhs, n.condition.getType.zeroValue);

        builder.condBr(cmp, thenLabel, n.hasElse ? elseLabel : endLabel);

        /// then
        gen.moveToBlock(thenLabel);

        n.thenStmt().visit!GenerateModule(gen);

        if(n.isExpr) {
            gen.castType(gen.rhs, n.thenType(), n.type);

            phiValues ~= gen.rhs;
            phiBlocks ~= gen.currentBlock;
        }

        if(!n.thenBlockEndsWithReturn) {
            builder.br(endLabel);
        }

        /// else
        if(n.hasElse) {
            gen.moveToBlock(elseLabel);

            n.elseStmt().visit!GenerateModule(gen);

            if(n.isExpr) {
                gen.castType(gen.rhs, n.elseType(), n.type);

                phiValues ~= gen.rhs;
                phiBlocks ~= gen.currentBlock;
            }

            if(!n.elseBlockEndsWithReturn) {
                builder.br(endLabel);
            }
        }

        /// end
        gen.moveToBlock(endLabel);
        if(n.isExpr) {
            auto phi = builder.phi(n.type.getLLVMType);
            phi.addIncoming(phiValues, phiBlocks);

            gen.rhs = phi;
        }
    }
}