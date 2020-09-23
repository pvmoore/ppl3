module ppl.build.BuildState;

import ppl.internal;

abstract class BuildState {
protected:
    Mutex getModuleLock;

    Queue!string taskQueue;

    Module[/*canonicalName*/string] modules;
    Set!string removedModules;

    string[string] unoptimisedIr;
    string[string] optimisedIr;
    string linkedIr;
    string linkedASM;

    StopWatch watch;

    CompileError[string] errors;
    DeadCodeEliminator dce;
    IBuildStateListener[] listeners;
public:
    interface IBuildStateListener {
        void buildFinished(BuildState);
    }

    LLVMWrapper llvmWrapper;
    Optimiser optimiser;
    Linker linker;
    Config config;
    Module mainModule;
    Mangler mangler;

    ulong getElapsedNanos() const { return watch.peek().total!"nsecs"; }
    bool hasErrors() const        { return errors.length>0; }

    void addListener(IBuildStateListener listener) {
        listeners ~= listener;
    }

    CompileError[] getErrors() {
        import std.algorithm.comparison : cmp;
        alias comp = (x,y) {
            int r = cmp(x.module_.canonicalName, y.module_.canonicalName);
            if(r!=0) return r < 0;
            return x.line*1_000_000 + x.column < y.line*1_000_000 + y.column;
        };
        return errors.values.sort!(comp).array;
    }
    CompileError[] getErrorsForModule(Module m) {
        return errors.values
                     .filter!(it=>it.module_.nid==m.nid)
                     .array;
    }

    string getOptimisedIR(string canonicalName)   { return optimisedIr.get(canonicalName, null); }
    string getUnoptimisedIR(string canonicalName) { return unoptimisedIr.get(canonicalName, null); }
    string getLinkedIR()                          { return linkedIr; }
    string getLinkedASM()                         { return linkedASM; }

    this(LLVMWrapper llvmWrapper, Config config) {
        this.llvmWrapper            = llvmWrapper;
        this.optimiser              = new Optimiser(llvmWrapper);
        this.linker                 = new Linker(llvmWrapper);
        this.dce                    = new DeadCodeEliminator(this);
        this.config                 = config;
        this.getModuleLock          = new Mutex;
        this.taskQueue              = new Queue!string(1024);
        this.mangler                = new Mangler;
        this.removedModules         = new Set!string;
        //this.refInfo                = new ReferenceInformation(this);
    }
    /// Tasks
    bool tasksOutstanding()       { return !taskQueue.empty; }
    int tasksRemaining()          { return taskQueue.length; }
    string getNextTask()          { return taskQueue.pop; }
    void addTask(string t)        { taskQueue.push(t); }

    void addError(CompileError e, bool canContinue) {
        string key = e.getKey();
        if(canContinue && key in errors) return;

        errors[key] = e;

        if(!canContinue) {
            throw new CompilationAborted(CompilationAborted.Reason.COULD_NOT_CONTINUE);
        }
        if(errors.length >= config.maxErrors) {
            throw new CompilationAborted(CompilationAborted.Reason.MAX_ERRORS_REACHED);
        }
    }
    void startNewBuild() {
        taskQueue.clear();
        dce.clearState();
        optimiser.clearState();
        linker.clearState();
        mangler.clearState();
        unoptimisedIr.clear();
        optimisedIr.clear();
        errors.clear();

        foreach(m; modules.values) {
            if(m.llvmValue) m.llvmValue.destroy();
        }
        modules.clear();
        removedModules.clear();
    }
    void startRebuild() {
        taskQueue.clear();
        removedModules.clear();
        errors.clear();

        // TODO - reset all module, function, variable refs?


    }

    /// Modules
    Module getModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        return modules.get(canonicalName, null);
    }
    Module getOrCreateModule(string canonicalName, string newSource) {
        auto src = convertTabsToSpaces(newSource);

        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        auto m = modules.get(canonicalName, null);
        assert(!m);

        //if(m) {
        //    /// Check the src hash
        //    auto hash = Hasher.sha1(src);
        //    if (hash==m.parser.getSourceTextHash()) {
        //        /// Source has not changed.
        //        return m;
        //    }
        //
        //    /// The module and all modules that reference it are now stale
        //    clearState(m, new Set!string);
        //
        //    m.parser.setSourceText(src);
        //
        //} else {
            m = createModule(canonicalName, true, src);
        //}
        return m;
    }
    Module getOrCreateModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        auto m = modules.get(canonicalName, null);
        if(!m) {
            m = createModule(canonicalName);
        }
        return m;
    }
    void removeModule(string canonicalName) {
        getModuleLock.lock();
        scope(exit) getModuleLock.unlock();

        removedModules.add(canonicalName);

        modules.remove(canonicalName);
    }
    Module[] allModules() {
        return modules.values;
    }
    Module[] allModulesThatReference(Module m) {
        Module[] refs;

        foreach(mod; allModules) {
            foreach(r; mod.getReferencedModules()) {
                if(r==m) refs ~= r;
            }
        }
        return refs;
    }
    /**
     *  Return all modules that import module _m_ regardless of whether the import is actually used.
     */
    Module[] allModulesThatImport(Module m) {
        Module[] refs;

        foreach(mod; allModules) {
            if(m.canonicalName.isOneOf(mod.getImports())) {
                refs ~= mod;
            }
        }

        return refs;
    }
    ///
    /// Recursively clear module state so that it can be re-used
    ///
    void clearState(Module m, Set!string hasBeenReset) {
        if(hasBeenReset.contains(m.canonicalName)) return;
        hasBeenReset.add(m.canonicalName);

        m.clearState();

        Module[] refs = allModulesThatReference(m);
        foreach(r; refs) {
            clearState(r, hasBeenReset);
        }
    }
    void moduleRequired(string moduleName) {
        if(moduleName in modules) return;
        taskQueue.push(moduleName);
    }

    /// Stats
    void dumpStats(void delegate(string) receiver = null) {
        if(!receiver) receiver = it=>writeln(it);

        GC.collect();

        receiver("\nOK");
        receiver("");
        receiver("Active modules ......... %s".format(allModules.length));
        receiver("Inactive modules ....... %s".format(removedModules.length));
        receiver("Parser time ............ %.2f ms".format(allModules.map!(it=>it.parser.getElapsedNanos).sum() * 1e-6));
        receiver("Resolver time .......... %.2f ms".format(allModules.map!(it=>it.resolver.getElapsedNanos).sum() * 1e-6));
        receiver("DCE time ............... %.2f ms".format(dce.getElapsedNanos() * 1e-6));
        receiver("Semantic checker time .. %.2f ms".format(allModules.map!(it=>it.checker.getElapsedNanos).sum() * 1e-6));
        receiver("IR generation time ..... %.2f ms".format(allModules.map!(it=>it.gen.getElapsedNanos).sum() * 1e-6));
        receiver("Optimiser time ......... %.2f ms".format(optimiser.getElapsedNanos * 1e-6));
        receiver("Linker time ............ %.2f ms".format(linker.getElapsedNanos * 1e-6));
        receiver("Total time.............. %.2f ms".format(getElapsedNanos * 1e-6));
        receiver("Memory used ............ %.2f MB".format(GC.stats.usedSize / (1024*1024.0)));
    }
    void logParse(A...)(string fmt, A args) {
        if(config.shouldLog(Logging.PARSE)) {
            writefln(format(fmt, args));
        }
    }
    void logResolve(A...)(string fmt, A args) {
        if(config.shouldLog(Logging.RESOLVE)) {
            writefln(format(fmt, args));
        }
    }
    void logState(A...)(string fmt, A args) {
        if(config.shouldLog(Logging.STATE)) {
            writefln(format(fmt, args));
        }
    }
    void logDCE(A...)(string fmt, A args) {
        if(config.shouldLog(Logging.DCE)) {
            writefln(format(fmt, args));
        }
    }
    void logGen(A...)(string fmt, A args) {
        if(config.shouldLog(Logging.GENERATE)) {
            writefln(format(fmt, args));
        }
    }
    void log(A...)(Logging flags, string fmt, A args) {
        if(config.shouldLog(flags)) {
            writefln(format(fmt, args));
        }
    }
private:
    Module createModule(string canonicalName, bool withSrc = false, string src = null) {
        auto m = new Module(canonicalName, llvmWrapper, this);
        modules[canonicalName] = m;

        mangler.addUniqueModuleName(canonicalName);

        if(canonicalName==config.getMainModuleCanonicalName) {
            m.isMainModule = true;
            mainModule     = m;
        }

        /// Read, tokenise and extract public types and functions
        if(withSrc) {
            m.parser.setSourceText(src);
        } else {
            m.parser.readSourceFromDisk();
        }

        return m;
    }
protected:
    void parseAndResolve() {
        logState("[✓] parseAndResolve");

        auto prevUnresolved = new Set!int;
        bool stalemate      = false;

        for(int loop=1; loop<100; loop++) {

            /// Process all pending tasks
            while(tasksOutstanding()) {
                auto moduleName = getNextTask();

                Module mod = getOrCreateModule(moduleName);

                /// Parse this module if we haven't done so already
                if(!mod.isParsed) {
                    mod.parser.parse();
                }
            }

            bool nodesModified = false;
            auto unresolved    = new Set!int;

            parseModules();
            runResolvePass(unresolved, nodesModified, stalemate);

            if(unresolved.length==0 && !tasksOutstanding() && !nodesModified) {
                /// This is our successful exit point
                allModulesResolved();
                return;
            }

            if(!nodesModified && unresolved==prevUnresolved) {
                if(stalemate) {
                    writefln("Couldn't make any further progress");
                    break;
                }
                stalemate = true;
            } else {
                stalemate = false;
            }

            prevUnresolved = unresolved;
        }
        /// If we get here we couldn't resolve something
        if(!hasErrors()) {
            convertUnresolvedNodesIntoErrors();
        }
    }
    void parseModules() {
        foreach(m; allModules) {
            if(!m.isParsed) {
                m.parser.parse();
            }
        }
    }
    void runResolvePass(Set!int unresolved, ref bool nodesModified, bool resolveStalemate) {
        assert(nodesModified==false);
        assert(unresolved.length==0);

        int numUnresolvedModules = 0;

        foreach(m; allModules) {
            bool resolved  = m.resolver.resolve(resolveStalemate);
            nodesModified |= m.resolver.isModified();

            unresolved.add(
                m.resolver.getUnresolvedNodes().map!(it=>it.nid).array
            );

            if(resolved) {
                //log("\t.. %s is resolved", m.canonicalName);
            } else {
                //log("\t.. %s is unresolved", m.canonicalName);
                numUnresolvedModules++;
            }
        }
        //log("There are %s unresolved modules, %s unresolved nodes", numUnresolvedModules, unresolved.length);
    }
    void allModulesResolved() {
        logState("[✓] All modules resolved");
         Module largestM;
        foreach(m; modules.values) {
            if(largestM is null || m.resolver.getCurrentIteration > largestM.resolver.getCurrentIteration) {
                largestM = m;
            }
            //dd("  [%s] %s".format(m.canonicalName, m.resolver.getCurrentIteration));
        }
        //logState("  [%s] %s".format(largestM.canonicalName, largestM.resolver.getCurrentIteration));
    }
    void removeUnreferencedNodesAfterResolution() {
        logState("[✓] remove unreferenced after resolution");

        dce.removeUnreferencedModules();
        dce.removeUnreferencedNodesAfterResolution();
    }
    ///
    /// - Move global variable initialisation code into the module constructor new() function.
    /// - Call module new() functions at start of program entry
    ///
    void afterResolution() {
        logState("[✓] after resolution");
        new AfterResolution(this).process(modules.values);
    }
    void semanticCheck() {
        logState("[✓] semantic");
        foreach(m; allModules) {
            //dd(m.canonicalName);
            m.checker.check();
        }
    }
    void afterSemantic() {
        logState("[✓] after semantic");
        new AfterSemantic(this).process();
    }
    bool generateIR() {
        logState("[✓] generating IR");
        bool allOk = true;
        foreach(m; allModules) {
            allOk &= m.gen.generate();

            if(config.collectOutput) {
                unoptimisedIr[m.canonicalName] = m.llvmValue.dumpToString();
            }
        }
        return allOk;
    }
    void convertUnresolvedNodesIntoErrors() {
        foreach(m; modules.values) {
            foreach(n; m.resolver.getUnresolvedNodes()) with(NodeID) {

                if(n.id==IDENTIFIER) {
                    auto identifier = n.getIdentifier();
                    m.addError(n, "Unresolved identifier %s".format(identifier.name), true);
                } else if(n.id==VARIABLE) {
                    auto variable = n.as!Variable;
                    m.addError(n, "Unresolved variable %s".format(variable.name), true);
                } else {
                    writefln("\t%s[line %s] %s: %s", m.canonicalName, n.line+1, n.id, n);
                }
            }
        }
        if(!hasErrors()) {
            auto m = mainModule ? mainModule : modules.values[0];
            addError(new UnknownError(m, "There were unresolved symbols but no errors were added"), true);
        }
    }
    void dumpAST() {
        logState("[✓] dumpAST");
        foreach(m; allModules) {
            m.resolver.writeAST();
        }
    }
}