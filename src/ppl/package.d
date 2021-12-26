module ppl;

public:

import ppl.global;
import ppl.ppl3;
import ppl.version_;

import ppl.ast.ASTNode;
import ppl.ast.Module;

import ppl.build.BuildState;
import ppl.build.IncrementalBuilder;
import ppl.build.ProjectBuilder;

import ppl.config.Config;
import ppl.config.ConfigReader;
import ppl.config.Logging;

import ppl.error.CompilationAborted;
import ppl.error.CompileError;

import ppl.lex.lexer;
import ppl.lex.tokens;

import ppl.misc.toml;

import ppl.type.IType;



/// Debug logging
void dd(A...)(A args) {
    import std.stdio : writef, writefln;
    import common : flushConsole;

    foreach(a; args) {
        writef("%s ", a);
    }
    writefln("");
    flushConsole();
}
string convertTabsToSpaces(string s, int tabsize=4) {
    import std.string : indexOf;
    import std.array  : appender;
    import common : repeat;

    if(s.indexOf("\t")==-1) return s;
    auto buf = appender!(string);
    auto spaces = " ".repeat(tabsize);
    foreach(ch; s) {
        if(ch=='\t') buf ~= spaces;
        else buf ~= ch;
    }
    return buf.data;
}

private import std.path;
private import std.file;
private import std.array : array, replace;

string normaliseDir(string path, bool makeAbsolute=false) {
    if(makeAbsolute) {
        path = asAbsolutePath(path).array;
    }
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/") ~ "/";
    return path;
}
string normaliseFile(string path,) {
    path = asNormalizedPath(path).array;
    path = path.replace("\\", "/");
    return path;
}