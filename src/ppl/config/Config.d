module ppl.config.Config;

import ppl.internal;
import std.array;
import std.path;

final class Config {
private:
    enum Mode { DEBUG, RELEASE }
    Mode mode;
    string mainModuleCanonicalName;
    Include[string] includes;   // key = baseModuleName
    string[] libs;
public:
    struct Include {
        string baseModuleName;  /// eg. "core"
        string absPath;
    }

    string mainFile;
    string basePath;
    string targetPath;
    string targetExe;

    /// Compilation options
    bool nullChecks         = true;
    bool enableAsserts      = true;
    bool enableInlining     = true;
    bool enableBoundsChecks = true;
    bool enableOptimisation = true;
    bool fastMaths          = true;

    /// Logging options
    ulong loggingFlags = Logging.HEADER | Logging.STATE | Logging.STATS;

    /// Link options
    bool enableLink  = true;
    string subsystem = "console";

    int maxErrors = int.max;

    /// Collect data for display in ide
    bool collectOutput = false;

    /// Compiler meta options
    bool logTokens    = false;

    bool writeASM     = true;
    bool writeOBJ     = true;
    bool writeAST     = true;
    bool writeIR      = true;
    bool writeJSON    = false;

    ///==================================================================================

    bool isDebug()   { return mode==Mode.DEBUG; }
    bool isRelease() { return mode==Mode.RELEASE; }
    string getMainModuleCanonicalName() { return mainModuleCanonicalName; }
    Include[] getIncludes() { return includes.values; }
    bool shouldLog(Logging flags) { return (loggingFlags & flags) != 0; }

    string getEntryFunctionName() {
        if(subsystem=="console") return "main";
        if(subsystem=="windows") return "WinMain";
        assert(false, "Unknown subsystem : " ~ subsystem);
    }

    void initialise() {
        mainModuleCanonicalName = mainFile.stripExtension.replace("/", "::").replace("\\", "::");

        generateTargetDirectories();
    }
    void addLib(string path) {
        libs ~= path;
    }
    void addInclude(string name, string path) {
        includes[name] = Include(name, normaliseDir(path, true));
    }
    void setToDebug() {
        mode               = Mode.DEBUG;
        nullChecks         = true;
        enableAsserts      = true;
        enableInlining     = false;
        enableOptimisation = true; //false; // fixme
        fastMaths          = true;
        enableBoundsChecks = true;

        libs ~= "external/.target/x64/Debug/tgc.lib";
    }
    void setToRelease() {
        mode               = Mode.RELEASE;
        nullChecks         = true;
        enableAsserts      = false;
        enableInlining     = true;
        enableOptimisation = true;
        fastMaths          = true;
        enableBoundsChecks = false;

        libs ~= "external/.target/x64/Release/tgc.lib";
    }

    ///
    /// Return the full path including the module filename and extension
    ///
    string getFullModulePath(string canonicalName) {
        auto baseModuleName = splitCanonicalName(canonicalName)[0];
        auto path           = basePath;

        foreach(lib; includes) {
            if(lib.baseModuleName==baseModuleName) {
                path = lib.absPath;
            }
        }

        assert(path.endsWith("/"));

        return path ~ canonicalName.replace("::", "/") ~ ".p3";
    }
    /**
     *  Convert "mod/mod2.p3" to "mod::mod2"
     */
    string getCanonicalName(string relpath) {
        import std.array : replace;
        return relpath[0..relpath.length-3].replace("\\", "::").replace("/", "::");
    }
    string[] getExternalLibs() {
        if(isDebug) {
            string[] dynamicRuntime = [
                "msvcrtd.lib",
                "ucrtd.lib",
                "vcruntimed.lib"
            ];
            //string[] staticRuntime = [
            //    "libcmt.lib",
            //    "libucrt.lib",
            //    "libvcruntime.lib"
            //];
            return dynamicRuntime ~ libs;
        }
        string[] dynamicRuntime = [
            "msvcrt.lib",
            "ucrt.lib",
            "vcruntime.lib"
        ];
        //string[] staticRuntime = [
        //    "libcmt.lib",
        //    "libucrt.lib",
        //    "libvcruntime.lib"
        //];
        return dynamicRuntime ~ libs;
    }

    override string toString() {
        auto buf = new StringBuffer;
        buf.add("Main file .... %s\n".format(mainFile));
        buf.add("Base path .... %s\n".format(basePath));
        buf.add("Target path .. %s\n".format(targetPath));
        buf.add("Target exe ... %s\n\n".format(targetExe));

        buf.add("[option] Build         = %s\n", isDebug ? "DEBUG" : "RELEASE");
        buf.add("[option] Null checks   = %s\n".format(nullChecks));
        buf.add("[option] Bounds checks = %s\n".format(enableBoundsChecks));
        buf.add("[option] Asserts       = %s\n".format(enableAsserts));
        buf.add("[option] Inline        = %s\n".format(enableInlining));
        buf.add("[option] Optimise      = %s\n".format(enableOptimisation));
        buf.add("[option] Fast maths    = %s\n".format(fastMaths));
        buf.add("[option] Link          = %s\n".format(enableLink));
        buf.add("[option] Subsystem     = %s\n\n".format(subsystem));

        foreach(lib; includes) {
            buf.add("[include] %s %s\n", lib.baseModuleName, lib.absPath);
        }
        buf.add("\n");
        foreach(lib; libs) {
            buf.add("[lib] %s\n", lib);
        }
        return buf.toString();
    }
private:
    /// eg. "core::console" -> ["core", "console"]
    static string[] splitCanonicalName(string canonicalName) {
        assert(canonicalName);
        return canonicalName.split("::");
    }
    void generateTargetDirectories() {
        createTargetDir("");
        createTargetDir("tok/");
        createTargetDir("ast/");
        createTargetDir("ir/");
        createTargetDir("ir_opt/");
        createTargetDir("bc/");
        createTargetDir("json/");
    }
    void createTargetDir(string dir) {
        import std.file : exists, mkdir;
        string path = targetPath ~ dir;
        if(!exists(path)) {
            mkdir(path);
        }
    }
}