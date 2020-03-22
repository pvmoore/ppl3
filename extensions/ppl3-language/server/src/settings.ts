import { Connection, TextDocuments, TextDocument, InitializeParams, DidChangeConfigurationParams } from "vscode-languageserver";
import { state } from "./server";
import { log } from "./util";

export interface PPL3Settings {
    maxNumberOfProblems: number;
    favouriteNumber: number;
}

// The global settings, used when the `workspace/configuration` request is not supported by the client.
// Please note that this is not the case when using this server with the client provided in this example
// but could happen with other clients.
const defaultSettings: PPL3Settings = {
    maxNumberOfProblems: 1000,
    favouriteNumber: 7
};

let globalSettings: PPL3Settings = defaultSettings;

// Cache the settings of all open documents
let documentSettings: Map<string, Thenable<PPL3Settings>> = new Map();

export const configChanged = (change: DidChangeConfigurationParams) => {
    log("configChanged");
    if (state.hasConfigurationCapability) {
        // Reset all cached document settings
        documentSettings.clear();
    } else {
        globalSettings = <PPL3Settings>(
            (change.settings.languageServerExample || defaultSettings)
        );
    }

    // Revalidate all open text documents
    //state.documents.all().forEach(validateTextDocument);
};

export const getDocumentSettings = (resource: string): Thenable<PPL3Settings> => {
    if (!state.hasConfigurationCapability) {
        return Promise.resolve(globalSettings);
    }
    let result = documentSettings.get(resource);
    if (!result) {
        result = state.connection.workspace.getConfiguration({
            scopeUri: resource,
            section: 'ppl3Language'
        });
        documentSettings.set(resource, result);
    }
    return result;
};