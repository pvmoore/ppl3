
import { Node, Module, Struct, Enum, Function, Variable } from "./model";
import { state } from "./server";
import { log } from "./util";
import * as util from "./util";
import { Lexer } from "./lex/Lexer";
import * as path from "path";
import * as fs from "fs";
import * as settings from "./settings";
import { S_IFREG } from "constants";

export default class ModelBuilder {
    jsonFolder: string;

    scope: string;
    isBuilding: boolean;
    jsonMap: Map<string, object>;

    constructor(uri: string) {
        this.scope = uri;
        this.isBuilding = false;
        this.jsonMap = new Map<string, object>();

        log("Initialising ModelBuilder");
        this.jsonFolder = state.projectRoot + path.sep + ".target\\json";
        log("\tjsonFolder ... " + this.jsonFolder);
        log("ModelBuilder ready");
    }

    build() {
        if (!state.compilerExe) {
            log("No compiler is configured");
            return;
        }
        if (!state.projectRoot) {
            log("No project root found");
            return;
        }
        if (this.isBuilding) {
            log("Already building");
            return;
        }
        log("building");
        this.isBuilding = true;

        // TODO - spawn ppl3 process
        this.loadJson();


        //const text = this.module.text;

        //this.module.tokens = new Lexer(text).lex();

        //log(`tokens: ${this.module.tokens.length}`);

        // this.module.tokens.forEach(t => {
        //     log(`\t${JSON.stringify(t)}`);
        // });

    }
    private loadJson() {
        log("loading json");

        fs.readdir(this.jsonFolder, {withFileTypes: true}, (err, files:fs.Dirent[]) => {
            if (err) {
                log("Error reading json files: " + err.message);
            } else {

                files.forEach(e => {
                    if (e.isFile && e.name.endsWith(".json")) {

                        const content = fs.readFileSync(this.jsonFolder + path.sep + e.name);
                        const json = JSON.parse(content.toString());

                        const key = e.name.substring(0, e.name.length - 5).replace(/\\./g, "::");

                        this.jsonMap.set(key, json);
                    }
                });

                log("Loaded " + this.jsonMap.size + " json objects");

                // for (const [k, v] of this.jsonMap) {
                //     log("" + k + " = " + v);
                // }
                this.buildModule(state.mainModuleName, true);
            }
        });
    }
    private buildModule(name:string, andIncludes:boolean) {
        log("building module " + name);

        const root:any = this.jsonMap.get(name);
        if (!root) {
            log("Can't find module " + name + " in json map");
            return;
        }

        const n: Node = Module.fromName(name);
        n.nid = root.nid;

        if (root.zchildren) {
            for(const o of root.zchildren) {
                //log("o=" + JSON.stringify(o));

                switch (o.id) {
                    case "VARIABLE":
                        let v = new Variable(o.name);
                        v.nid = o.nid;
                        v.line = o.line;
                        v.column = o.col;
                        if (o.public) v.isPublic = true;
                        n.add(v);
                        break;
                    case "FUNCTION":
                        let f = new Function(o.name);
                        f.nid = o.nid;
                        f.line = o.line;
                        f.column = o.col;
                        if (o.public) f.isPublic = true;
                        n.add(f);
                        break;
                    default:
                        log("-->Unhandled id " + o.id);
                        break;
                }
            }
        }
    }
}