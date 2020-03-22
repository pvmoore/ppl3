import ModelBuilder from './ModelBuilder';
import Suggestions from "./Suggestions";
import { Connection, TextDocuments, TextDocument, TextDocumentItem, InitializeParams, DidChangeTextDocumentParams, CompletionItem, TextDocumentPositionParams, CompletionItemKind, DidOpenTextDocumentParams, CompletionParams, LogTraceNotification } from "vscode-languageserver";
import { Module } from "./model";
import { log } from "./util";
import * as util from "./util";

export default class State {
    modules: Map<string, Module> = new Map();
    connection: Connection;
    documents: TextDocuments;

    activeModule: Module;

    hasConfigurationCapability: boolean = false;
    hasWorkspaceFolderCapability: boolean = false;
    hasDiagnosticRelatedInformationCapability: boolean = false;

    constructor(conn: Connection, documents: TextDocuments) {
        this.connection = conn;
        this.documents = documents;
    }
    init(params: InitializeParams) {
        let capabilities = params.capabilities;

        // Does the client support the `workspace/configuration` request?
        // If not, we will fall back using global settings
        this.hasConfigurationCapability = !!(
            capabilities.workspace && !!capabilities.workspace.configuration
        );
        this.hasWorkspaceFolderCapability = !!(
            capabilities.workspace && !!capabilities.workspace.workspaceFolders
        );
        this.hasDiagnosticRelatedInformationCapability = !!(
            capabilities.textDocument &&
            capabilities.textDocument.publishDiagnostics &&
            capabilities.textDocument.publishDiagnostics.relatedInformation
        );
    }
    onOpen(params: DidOpenTextDocumentParams) {
        const m = this.getModule(params.textDocument.uri);
        this.activeModule = m;
        log(`active module = ${m.name}`);

        setTimeout(() => {
            this.buildModule(m, params.textDocument.text, params.textDocument.version);
        });
    }
    onClose(uri: string) {
        const m = this.getModule(uri);
    }
    onSave(uri: string) {
        const m = this.getModule(uri);
    }
    onEdit(params: DidChangeTextDocumentParams) {
        const m = this.getModule(params.textDocument.uri);
        const uri = params.textDocument.uri;
        this.activeModule = m;
        log(`active module = ${m.name}`);

        log(`count = ${params.contentChanges.length}`);

        params.contentChanges.forEach(c => {
            const range = c.range;
            const rangeLength = c.rangeLength;
            const text = c.text;

            if (range) log(`range = ${range}`);
            if (rangeLength) log(`rangeLength = ${rangeLength}`);
            if (text) {

                const m2 = m.clone();

                setTimeout(() => {
                    this.buildModule(m, text, params.textDocument.version);
                });
            }
        });
    }
    onComplete(params: CompletionParams): CompletionItem[] {
        const m = this.getModule(params.textDocument.uri);
        return m.suggestions.getSuggestions(params);
        // return [
        //     {
        //         label: 'field',
        //         kind: CompletionItemKind.Field,
        //         data: { name: "Peter", type: "Field", parent: "TheClass" }
        //     },
        //     {
        //         label: 'method',
        //         kind: CompletionItemKind.Method,
        //         data: { name: "Bruce", type: "Method", parent: "TheClass2" }
        //     }
        // ];
    }
    onCompleteResolve(item: CompletionItem): CompletionItem {
        return Suggestions.resolve(item);
    }

    private getModule(uri: string): Module {
        let m = this.modules.get(uri);
        if (!m) {
            m = new Module(util.uriToModuleName(uri), uri);
            this.modules.set(uri, m);
        }
        return m;
    }
    private buildModule(m: Module, text: string, version: number) {
        log("building "+m.name);
        let newMod = m.clone();
        newMod.text = text;
        newMod.version = version;

        new ModelBuilder(newMod).build();

        this.modules.set(newMod.uri, newMod);

        log(`Module ${newMod.name} (v${newMod.version}) ready`);
    }
}
