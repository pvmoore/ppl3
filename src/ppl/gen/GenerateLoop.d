module ppl.gen.GenerateLoop;

import ppl.internal;

final class GenerateLoop {
    GenerateModule gen;
    LLVMBuilder builder;

    this(GenerateModule gen) {
        this.gen     = gen;
        this.builder = gen.builder;
    }
    void generate(Loop loop) {
        auto preBB   = gen.createBlock(loop, "loop_init");
        auto checkBB = gen.createBlock(loop, "loop_condition");
        auto bodyBB  = gen.createBlock(loop, "loop_body");
        auto contBB  = gen.createBlock(loop, "loop_continue");
        auto exitBB  = gen.createBlock(loop, "loop_exit");

        loop.continueBB = contBB;
        loop.breakBB    = exitBB;

        auto loopStartBB = loop.hasCondExpr ? checkBB : bodyBB;

        builder.br(preBB);

        /// pre loop statements
        gen.moveToBlock(preBB);
        loop.initStmts().visit!GenerateModule(gen);
        builder.br(loopStartBB);

        /// checkBB: evaluate condition
        gen.moveToBlock(checkBB);
        if(loop.hasCondExpr) {
            loop.condExpr.visit!GenerateModule(gen);
            auto cmp = builder.icmp(LLVMIntPredicate.LLVMIntNE, gen.rhs, loop.condExpr.getType.zeroValue);
            builder.condBr(cmp, bodyBB, exitBB);
        } else {
            builder.br(bodyBB);
        }

        /// bodyBB: body
        gen.moveToBlock(bodyBB);
        loop.bodyStmts().visit!GenerateModule(gen);
        builder.br(contBB);

        /// contBB: post loop statements
        gen.moveToBlock(contBB);
        loop.postExprs().visit!GenerateModule(gen);
        builder.br(loopStartBB);

        /// exitBB: exit
        gen.moveToBlock(exitBB);
    }
    void generate(Break brk) {
        builder.br(brk.loop.breakBB);
        auto bb = gen.createBlock(brk, "after_break");
        gen.moveToBlock(bb);
    }
    void generate(Continue cont) {
        builder.br(cont.loop.continueBB);
        auto bb = gen.createBlock(cont, "after_continue");
        gen.moveToBlock(bb);
    }
}