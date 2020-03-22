import { getDocumentSettings } from './settings';
/* --------------------------------------------------------------------------------------------
 * Adapted from https://github.com/Microsoft/vscode-languageserver-node
 *
 * https://microsoft.github.io/language-server-protocol/specification
 * ------------------------------------------------------------------------------------------ */

import {
	createConnection,
	TextDocuments,
	TextDocument,
	Diagnostic,
	DiagnosticSeverity,
	ProposedFeatures,
	InitializeParams,
	DidChangeConfigurationNotification,
	CompletionItem,
	CompletionItemKind,
	SignatureHelpOptions,
	TextDocumentPositionParams,
	CompletionOptions,
	NotificationHandler,
	DidChangeTextDocumentParams,
	DidOpenTextDocumentParams,
	DidCloseTextDocumentParams
} from 'vscode-languageserver';

import State from "./State";
import { PPL3Settings, configChanged } from "./settings";
import { log } from './util';

// Create a connection for the server. The connection uses Node's IPC as a transport.
// Also include all preview / proposed LSP features.
let connection = createConnection(ProposedFeatures.all);

// Create a simple text document manager. The text document manager
// supports full document sync only
let documents: TextDocuments = new TextDocuments();

export let state: State;

connection.onInitialize((params: InitializeParams) => {
	connection.console.log("onInitialise");

	state = new State(connection, documents);
	state.init(params);

	return {
		capabilities: {
			textDocumentSync: documents.syncKind,

			completionProvider: <CompletionOptions>{
				resolveProvider: true,
				triggerCharacters: [".", "::"]
			},
			hoverProvider: false

			// signatureHelpProvider: <SignatureHelpOptions>{
			// 	triggerCharacters: [".", "::"]
			// }
		}
	};
});

connection.onInitialized(() => {
	log("initialised");
	if (state.hasConfigurationCapability) {
		// Register for all configuration changes.
		connection.client.register(DidChangeConfigurationNotification.type, undefined);
	}
	if (state.hasWorkspaceFolderCapability) {
		connection.workspace.onDidChangeWorkspaceFolders(_event => {
			log(`onDidChangeWorkspaceFolders`);
		});
	}

	connection.onDidChangeTextDocument((params: DidChangeTextDocumentParams) => {
		state.onEdit(params);
	});
	connection.onDidOpenTextDocument((params: DidOpenTextDocumentParams) => {
		state.onOpen(params);
	});
	connection.onDidCloseTextDocument((params: DidCloseTextDocumentParams) => {
		state.onClose(params.textDocument.uri);
	});
	connection.onDidSaveTextDocument((params) => {
		state.onSave(params.textDocument.uri);
	});
	connection.onCompletion((params: TextDocumentPositionParams): CompletionItem[] => {
		return state.onComplete(params);
	});
	connection.onCompletionResolve((item: CompletionItem) => {
		return state.onCompleteResolve(item);
	});
});

connection.onDidChangeConfiguration(change => {
	configChanged(change);
});



// Only keep settings for open documents
documents.onDidClose(e => {
	log(`!!onDidClose`);
	//documentSettings.delete(e.document.uri);
});

// The content of a text document has changed. This event is emitted
// when the text document first opened or when its content has changed.
documents.onDidChangeContent(change => {
	log(`!!onDidChangeContent`);
	//validateTextDocument(change.document);
});

/*
async function validateTextDocument(textDocument: TextDocument): Promise<void> {
	// In this simple example we get the settings for every validate run.
	let settings = await getDocumentSettings(textDocument.uri);

	// The validator creates diagnostics for all uppercase words length 2 and more
	let text = textDocument.getText();
	let pattern = /\b[A-Z]{2,}\b/g;
	let m: RegExpExecArray | null;

	let problems = 0;
	let diagnostics: Diagnostic[] = [];
	while ((m = pattern.exec(text)) && problems < settings.maxNumberOfProblems) {
		problems++;
		let diagnostic: Diagnostic = {
			severity: DiagnosticSeverity.Warning,
			range: {
				start: textDocument.positionAt(m.index),
				end: textDocument.positionAt(m.index + m[0].length)
			},
			message: `${m[0]} is all uppercase.`,
			source: 'ex'
		};
		if (hasDiagnosticRelatedInformationCapability) {
			diagnostic.relatedInformation = [
				{
					location: {
						uri: textDocument.uri,
						range: Object.assign({}, diagnostic.range)
					},
					message: 'Spelling matters'
				},
				{
					location: {
						uri: textDocument.uri,
						range: Object.assign({}, diagnostic.range)
					},
					message: 'Particularly for names'
				}
			];
		}
		diagnostics.push(diagnostic);
	}

	// Send the computed diagnostics to VSCode.
	connection.sendDiagnostics({ uri: textDocument.uri, diagnostics });
}
*/

connection.onDidChangeWatchedFiles(_change => {
	// Monitored files have change in VSCode
	log('We received an file change event');
});

connection.onDidOpenTextDocument((params) => {
	log("!!!!");
	// A text document got opened in VSCode.
	// params.textDocument.uri uniquely identifies the document. For documents store on disk this is a file URI.
	// params.textDocument.text the initial full content of the document.
	log(`${params.textDocument.uri} opened.`);
});
connection.onDidChangeTextDocument((params:DidChangeTextDocumentParams) => {
	log("!!!!");
	// The content of a text document did change in VSCode.
	// params.textDocument.uri uniquely identifies the document.
	// params.contentChanges describe the content changes to the document.
	log(`${params.textDocument.uri} changed: ${JSON.stringify(params.contentChanges)}`);
});
connection.onDidCloseTextDocument((params) => {
	log("!!!!");
	// A text document got closed in VSCode.
	// params.textDocument.uri uniquely identifies the document.
	log(`${params.textDocument.uri} closed.`);
});


// Make the text document manager listen on the connection
// for open, change and close text document events
documents.listen(connection);

// Listen on the connection
connection.listen();
