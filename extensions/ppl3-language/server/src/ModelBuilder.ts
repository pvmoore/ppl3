
import { Node, Module, Struct, Enum, Property } from "./model";
import { state } from "./server";
import { log } from "./util";
import { Lexer } from "./lex/Lexer";

export default class ModelBuilder {
    module: Module;

    constructor(module: Module) {
        this.module = module;
    }

    build() {
        const text = this.module.text;

        this.module.tokens = new Lexer(text).lex();

        log(`tokens: ${this.module.tokens.length}`);

        this.module.tokens.forEach(t => {
            log(`\t${JSON.stringify(t)}`);
        });
    }
}