
import { Position, LogTraceNotification } from "vscode-languageserver";
import URI from 'vscode-uri';
import Suggestions from "./Suggestions";
import { log } from "./util";
import * as util from "./util";
import { Token } from "./lex/Lexer";

export abstract class Node {
    line: number;
    column: number;
    nid: number;
    parent: Node;
    children: Array<Node> = new Array<Node>();

    add(n: Node): Node {
        n.parent = this;
        this.children.push(n);
        return this;
    }
}

export class Module extends Node {
    name: string;
    uri: string;
    filename: string;
    suggestions: Suggestions;

    text: string;
    version: number;
    //tokens: Array<Token>; // set by ModelBuilder

    static fromUri(uri: string): Module {
        let m = new Module();
        m.name = util.uriToModuleName(uri);
        m.uri = uri;
        m.filename = URI.parse(uri).fsPath;
        m.suggestions = new Suggestions(m);
        // log("name = " + m.name);
        // log("uri =" + m.uri);
        // log("filename = " + m.filename);
        return m;
    }
    static fromName(name: string): Module {
        let m = new Module();
        m.name = name;
        m.filename = util.moduleNameToFilename(name);
        m.uri = util.moduleNameToUri(name);
        m.suggestions = new Suggestions(m);
        // log("name = " + m.name);
        // log("uri =" + m.uri);
        // log("filename = " + m.filename);
        return m;
    }
    clone(): Module {
        let m = Module.fromUri(this.uri);
        return m;
    }
    find(pos: Position): Node | null {
        log("TODO: find");
        return null;
    }
}

export class Struct extends Node {
    name: string;
    isPublic: boolean;

    constructor(name: string) {
        super();
        this.name = name;
    }
    getVariable(name: string): null | Variable {
        return null;
    }
}

export class Variable extends Node {
    name: string;
    isPublic: boolean;

    constructor(name: string) {
        super();
        this.name = name;
    }
}

export class Function extends Node {
    name: string;
    isPublic: boolean;
    returnType: Type = UNKNOWN;
    parameters = new Array<Variable>();

    constructor(name: string) {
        super();
        this.name = name;
    }
}

export class Enum extends Node {
    name: string;
    isPublic: boolean;
    elementType: Type = UNKNOWN;

    constructor(name: string) {
        super();
        this.name = name;
    }
}

export enum TypeKind {
    UNKNOWN,
    BOOL,
    BYTE, SHORT, INT, LONG,
    HALF, FLOAT, DOUBLE,
    VOID,
    STRUCT, CLASS, ARRAY, ENUM
}

export class Type {
    kind: TypeKind;
    ptrDepth: number = 0;
    constructor(kind: TypeKind) {
        this.kind = kind;
    }
}

export const UNKNOWN = new Type(TypeKind.UNKNOWN);
export const BOOL = new Type(TypeKind.BOOL);
export const INT = new Type(TypeKind.INT);
