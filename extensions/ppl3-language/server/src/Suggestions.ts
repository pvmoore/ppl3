
import { Node, Module, Struct, Enum, Property } from "./model";
import { state } from "./server";
import { log } from "./util";
import {
    CompletionItem, TextDocumentPositionParams, Position, CompletionItemKind, CompletionParams
} from "vscode-languageserver";

export default class Suggestions {
    module: Module;

    constructor(module: Module) {
        this.module = module;
    }

    getSuggestions(params: CompletionParams): CompletionItem[] {
        log(`getSuggestions ${JSON.stringify(params.position)} ${JSON.stringify(params.context)}`);
        const pos = params.position;
        const kind = params.context.triggerKind;
        const char = params.context.triggerCharacter;

        // Only support property/method suggestions at the moment
        if ("." === params.context.triggerCharacter) return this.getDotSuggestions(pos);
        if (":" === params.context.triggerCharacter) return this.getDblColonSuggestions(pos);


        return [
            {
                label: 'fieldname',
                kind: CompletionItemKind.Field,
                data: { name: "Peter", type: "Field", parent: "TheClass" }
            },
            {
                label: 'methodname',
                kind: CompletionItemKind.Method,
                data: { name: "Bruce", type: "Method", parent: "TheClass2" }
            }
        ];
    }
    static resolve(item: CompletionItem): CompletionItem {
        log(`resolve ${JSON.stringify(item)}`);

        switch (item.kind) {
            case CompletionItemKind.Method:
                break;
            case CompletionItemKind.Function:
                break;
            case CompletionItemKind.Struct:
                break;
            case CompletionItemKind.Class:
                break;
            case CompletionItemKind.Property:
                item.detail = item.data.
                    break;
        }

        if (item.data.type === "Field") {
            item.detail = item.data.parent;
        } else if (item.data.type === "Method") {
            item.detail = item.data.parent;
        }


        return item;
    }
    private getDblColonSuggestions(pos: Position): CompletionItem[] {

        return [];
    }
    private getDotSuggestions(pos: Position): CompletionItem[] {

        // Get the word preceeding the pos
        const text = this.module.text;


        // Find the definition of the word

        // Get the properties

        return [];
    }
}
