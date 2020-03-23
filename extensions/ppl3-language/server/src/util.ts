
import * as fs from "fs";
import * as path from "path";
import { state } from "./server";
import URI from 'vscode-uri';

export const log = (msg: string) => {
    state.connection.console.log(msg);
};

export const findProjectRoot = (uri: string): string | null => {

    let p = URI.parse(uri).fsPath;
    let d = path.dirname(p);

    // Handle special case of editing libs::core and libs::std
    if (d.endsWith("ppl3\\libs\\core") || d.endsWith("ppl3\\libs\\std")) {
        return path.resolve(d, "..");
    }

    const recurse = (dir: string): string | null => {

        const files: fs.Dirent[] = fs.readdirSync(dir, { withFileTypes: true });

        for (const f of files) {
            if (f.isFile()) {
                if (f.name === "config.toml") {
                    return dir;
                }
            }
        }

        const dir2 = path.resolve(dir, "..");
        if (dir2 !== dir) {
            return recurse(dir2);
        } else return null;
    };

    return recurse(path.dirname(p));
};

/**
 * Converts "file:///<projectRoot>/name/name2.p3" to "name::name2"
 */
export const uriToModuleName = (uri: string): string => {
    const root = findProjectRoot(uri);
    const p = URI.parse(uri).fsPath;
    const b = p.replace(root + path.sep, "");
    const c = b.substring(0, b.length - 3);
    return c.replace(path.sep, "::");
}

/**
 * Converts eg. "core::assert" "<projectRoot>\core\assert.p3"
 */
export const moduleNameToFilename = (name: string): string => {
    return state.projectRoot + path.sep + name.replace(/::/g, path.sep) + ".p3";
}

/**
 * Converts "name::name2" to "file:///<projectRoot>/name/name2.p3"
 */
export const moduleNameToUri = (name: string): string => {
    const p = moduleNameToFilename(name);
    const uri = URI.file(moduleNameToFilename(name));
    return uri.toString();
}

export const isDigit = (ch: string): boolean => {
    return ch.charCodeAt(0) >= 48 && ch.charCodeAt(0) <= 57;
}
