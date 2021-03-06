/* --------------------------------------------------------------------------------------------
 * Copyright (c) Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See License.txt in the project root for license information.
 * ------------------------------------------------------------------------------------------ */

import * as path from 'path';
import { workspace, ExtensionContext, window } from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	ServerOptions,
	TransportKind,
	ExecutableOptions,
	RequestType0
} from 'vscode-languageclient';

let client: LanguageClient;

export function activate(context: ExtensionContext) {
	// The server is implemented in node
	let serverModule = context.asAbsolutePath(
		path.join('server', 'out', 'server.js')
	);
	// The debug options for the server
	// --inspect=6009: runs the server in Node's Inspector mode so VS Code can attach to the server for debugging
	let debugOptions = { execArgv: ['--nolazy', '--inspect=6009'] };

	// If the extension is launched in debug mode then the debug server options are used
	// Otherwise the run options are used
	let serverOptions: ServerOptions = {
		run: {
			module: serverModule,
			transport: TransportKind.ipc
		},
		debug: {
			module: serverModule,
			transport: TransportKind.ipc,
			options: debugOptions
		}
	};

	// Options to control the language client
	let clientOptions: LanguageClientOptions = {
		// Register the server for plain text documents
		documentSelector: [{ scheme: 'file', language: 'ppl3' }],
		synchronize: {
			// Notify the server about file changes to '.clientrc files contained in the workspace
			fileEvents: workspace.createFileSystemWatcher('**/.clientrc')
		}
	};

	// Create the language client and start the client.
	// client = new LanguageClient(
	// 	'ppl3-lsp-client',
	// 	'PPL3 Language Server',
	// 	serverOptions,
	// 	clientOptions
	// );



	// Create a language client that starts up an external server
	client = new LanguageClient(
		"ppl3-lsp-client",
		"PPL3 LSP",
		<ServerOptions>{
			command: "server.exe",
			args: ["-lsp"],
			options: <ExecutableOptions>{
				cwd: "\\pvmoore\\d\\apps\\ppl3\\",
				env: "",
				detached: false
			}
		},
		<LanguageClientOptions>{
			documentSelector: [{ scheme: 'file', language: 'ppl3' }],
			outputChannel: window.createOutputChannel("PPL3 LSP")
		},
		true
	)

	// Start the client. This will also launch the server
	client.start();

	client.onReady().then(() => {
		console.log("onReady");
		client.onNotification("window/logMessage", function (info) {
			console.log("onNotification");
		});
	});

	//client.onRequest(RequestType0.);

	//client.sendRequest();

	context.subscriptions.push({
		dispose() {
			client.stop();
		}
	});
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) {
		return undefined;
	}
	return client.stop();
}
