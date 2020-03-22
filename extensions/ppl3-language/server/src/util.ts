
import * as fs from "fs";
import * as path from "path";
import { state } from "./server";
import URI from 'vscode-uri';

export const log = (msg: string) => {
    state.connection.console.log(msg);
};

const findProjectRoot = (uri: string): string | null => {

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

export const uriToModuleName = (uri: string): string => {
    const root = findProjectRoot(uri);
    const p = URI.parse(uri).fsPath;
    const b = p.replace(root + path.sep, "");
    const c = b.substring(0, b.length - 3);
    return c.replace(path.sep, "::");
}

/**
 * Converts eg. "core\assert.p3" to "core::assert"
 */
export const moduleNameToPath = (name: string): string => {
    return name.replace("::", path.sep);
}

export const isDigit = (ch: string): boolean => {
    return ch.charCodeAt(0) >= 48 && ch.charCodeAt(0) <= 57;
}
