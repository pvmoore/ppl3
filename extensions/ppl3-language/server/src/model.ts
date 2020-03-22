
import { Position } from "vscode-languageserver";
import URI from 'vscode-uri';
import Suggestions from "./Suggestions";
import { log } from "./util";
import * as util from "./util";
import { Token } from "./lex/Lexer";

export abstract class Node {
    children: Array<Node> = new Array<Node>();
}

export class Module extends Node {
    name: string;
    uri: string;
    path: string;
    suggestions: Suggestions;

    text: string;
    version: number;
    tokens: Array<Token>; // set by ModelBuilder

    constructor(name: string, uri: string) {
        super();
        this.name = name;
        this.uri = uri;
        this.suggestions = new Suggestions(this);
        this.name = util.uriToModuleName(uri);
        this.path = URI.parse(uri).fsPath;
        //log("name = " + this.name);
        //log("path = "+this.path);
    }
    clone(): Module {
        let m = new Module(this.name, this.uri);
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
    getProperty(name: string): null | Property {
        return null;
    }
}

export class Property extends Node {
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
    parameters = new Array<Parameter>();

    constructor(name: string) {
        super();
        this.name = name;
    }
}

export class Parameter extends Node {
    name: string;

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
