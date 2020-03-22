
import { Module } from "../model";
import { log } from "../util";
import * as util from "../util";
import { start } from "repl";

export class Lexer {
    private text: string;
    constructor(text: string) {
        this.text = text;
    }
    lex(): Token[] {
        log(`Lexing ${this.text.length} chars`);
        let tokens = new Array<Token>();
        let startBuf = 0;
        let i = 0;
        let line = 0;
        let startLine = -1; // for multiline tokens
        let lineOffset = 0;

        const peek = (offset: number): string => {
            return i + offset >= this.text.length ? "\0" : this.text[i + offset];
        };
        const handleEol = (discard:boolean) : boolean => {
            if (peek(0) == "\r") {
                if (peek(1) == "\n") i++;
                i++;
                line++;
                lineOffset = i;
                if (discard) startBuf = i;
                return true;
            } else if (peek(0) == "\n") {
                i++;
                line++;
                lineOffset = i;
                if (discard) startBuf = i;
                return true;
            }
            return false;
        };
        const gotoEol = () => {
            while (i < this.text.length) {
                if (peek(0) == "\r" || peek(0) == "\n") { break; }
                i++;
            }
        };
        const gotoEndOfMLComment = () => {
            // peek(0) + peek(1) == "/*"
            i += 2;
            startLine = line;
            while (i < this.text.length) {
                if (peek(0) == "*" && peek(1) == "/") {
                    i += 2;
                    break;
                }
                handleEol(false);
                i++;
            }
            add();
        };
        const gotoEndOfString = () => {
            // peek(0) == "
            i++;
            while (i < this.text.length) {
                if (peek(0) == "\\") {
                    if (peek(1) == "\"") {
                        i += 2;
                    } else i++;
                } else if (peek(0) == "\"") {
                    i++;
                    break;
                } else i++;
            }
            add();
        };
        const gotoEndOfChar = () => {
            // peek(0) == '
            i++;
            while (i < this.text.length) {
                if (peek(0) == "\\") {
                    if (peek(1) == "'") {
                        i += 2;
                    } else i++;
                } else if (peek(0) == "'") {
                    i++;
                    break;
                } else i++;
            }
            add();
        };
        const determineType = () => {
            const ch = this.text[startBuf];
            const ch2 = i > startBuf ? this.text.slice(startBuf, startBuf + 2) : "\0";
            if (ch == "\"") return TT.STRING;
            if (ch == "\'") return TT.CHAR;
            if (ch2 == "//") return TT.LINE_COMMENT;
            if (ch2 == "/*") return TT.ML_COMMENT;
            if (util.isDigit(ch) || (ch == "-" && util.isDigit(ch2[1]))) return TT.NUMBER;
            return TT.ID;
        };
        const add = (t?: TT, value?: string) => {
            if (i > startBuf) {
                tokens.push({
                    type: determineType(),
                    value: this.text.slice(startBuf, i),
                    start: startBuf,
                    end: i,
                    line: startLine == -1 ? line : startLine
                });
                startLine = -1;
            }

            if (t) {
                value = value ? value : " ";
                tokens.push({ type: t, value: value, start: i, end: i + value.length, line: line });
                i += value.length;
            }
            startBuf = i;
        };
        const check3CharOps = (): boolean => {
            const ch3 = peek(0) + peek(1) + peek(2);
            let found = false;
            switch (ch3) {
                case ">>>": // ambiguous
                    add(TT.OP, ch3);
                    found = true;
                    break;
            }
            return found;
        };
        const check2CharOps = (): boolean => {
            const ch2 = peek(0) + peek(1);
            let found = false;
            switch (ch2) {
                case "!=":
                case "==":
                case "<=":
                case ">=":
                case "::":
                case "--":
                case "<<":
                    //case ">>": // ambiguous

                    add(TT.OP, ch2);
                    found = true;
                    break;
                case "//":
                    add();
                    gotoEol();
                    add();
                    found = true;
                    break;
                case "/*":
                    add();
                    gotoEndOfMLComment();
                    add();
                    found = true;
                    break;
            }
            return found;
        };
        const check1CharOps = (): boolean => {
            const ch = peek(0);
            let found = false;
            switch (ch) {
                case ".":
                case "=":
                case ",":
                case ";":
                case ":":
                case "~":
                case "/":
                case "*":
                case "+":
                case "<":
                case ">":
                case "&":
                case "|":
                case "^":
                case "(":
                case ")":
                case "{":
                case "}":
                case "[":
                case "]":
                case "<":
                case ">":
                    add(TT.OP, ch);
                    found = true;
                    break;
                case "-":
                    if (!util.isDigit(peek(1))) {
                        add(TT.OP, ch);
                        found = true;
                    }
                    break;
                case "\"":
                    add();
                    gotoEndOfString();
                    break;
                case "'":
                    add();
                    gotoEndOfChar();
                    break;
            }
            return found;
        };

        while (i < this.text.length) {
            const ch = peek(0);

            if (ch == "\r" || ch == "\n") {
                add();
                handleEol(true);
            } else if (ch.charCodeAt(0) < 33) {
                add();
                i++;
                startBuf = i;
            } else if (check3CharOps()) {

            } else if (check2CharOps()) {

            } else if (check1CharOps()) {

            } else {
                i++;
            }
        }
        add();

        return tokens;
    }
}

export enum TT {
    ID,
    STRING,
    CHAR,
    NUMBER,
    LINE_COMMENT,
    ML_COMMENT,
    OP
}

export class Token {
    type: TT;
    value: string;
    start: number;
    end: number;
    line: number;
}