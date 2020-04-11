module ppl.build.IncrementalBuilder;

import ppl.internal;
import core.thread;
import core.sync.semaphore;
import core.sync.mutex;
import fswatch;

/**
 *  Watches the project directory and rebuilds when a file is modified.
 *
 */
final class IncrementalBuilder : BuildState {
private:
    enum WATCH_SLEEP_INTERVAL = 1000;
    FileWatch watcher;
    Thread watcherThread, builderThread;
    Semaphore builderSemaphore;
    Mutex mutex;
    bool running = true;

    IQueue!string modifications;

public:
    this(LLVMWrapper llvmWrapper, Config config) {
        if(!From!"std.file".exists(config.basePath)) throw new Error("%s is not a directory".format(config.basePath));

        super(llvmWrapper, config);

        this.llvmWrapper = llvmWrapper;
        this.config = config;
        this.builderSemaphore = new Semaphore(1);
        this.mutex = new Mutex;
        this.modifications = makeSPSCQueue!string(1024);
        this.watcher = FileWatch(config.basePath, true);
        this.watcherThread = new Thread(&watchFolder);
        this.watcherThread.isDaemon = true;
        this.watcherThread.start();

        this.builderThread = new Thread(&build);
        this.builderThread.isDaemon = true;
        this.builderThread.start();
    }
    void shutdown() {
        running = false;
        builderSemaphore.notify();
    }
private:
    /// Async (builderThread)
    void build() {
        while(running) {
            writefln("Builder waiting for work");
            builderSemaphore.wait();
            if(!running) return;

            watch.reset();
            watch.start();
            bool astDumped = false;

            try{

                // Build everything if this is the first run or there were errors the last time
                if(modules.length == 0 || hasErrors()) {
                    buildAll();
                } else {
                    rebuild();
                }

            }catch(InternalCompilerError e) {
                writefln("\n=============================");
                writefln("!! Internal compiler error !!");
                writefln("=============================");
                writefln("%s", e.info);
                writefln("\n=============================");
                throw e;
            }catch(CompilationAborted e) {
                writefln("Compilation aborted ... %s\n", e.reason);
            }catch(Throwable e) {
                auto m = mainModule ? mainModule : modules.values[0];
                addError(new UnknownError(m, "Unhandled exception: %s".format(e)), true);
            }finally{
                if(!astDumped) dumpAST();
                flushLogs();
            }
            watch.stop();

            writefln("%s modules are cached - %s errors (Elapsed time %s ms)", modules.length, errors.length, watch.peek().total!"msecs");

            foreach(l; listeners) {
                l.buildFinished(this);
            }
        }
    }
    /**
     *  Rebuild everything from scratch.
     *
     *  Async (builderThread)
     */
    void buildAll() {
        writefln("Doing full build");
        startNewBuild();

        moduleRequired(config.getMainModuleCanonicalName);

        parseAndResolve();
        if(hasErrors()) {
            return;
        }

        removeUnreferencedNodesAfterResolution();
        afterResolution();
        if(hasErrors()) {
            return;
        }

        semanticCheck();

        if(hasErrors()) {
            return;
        }
    }
    /**
     *  Rebuild only modified modules and those that reference modified modules (recursively).
     *  Assumes there are no errors.
     */
    void rebuild() {
        writefln("Doing partial build");
        assert(hasErrors()==false);

        string[1024] modulesModified;
        auto num = modifications.drain(modulesModified);
        if(num==0) return;

        auto set = new Set!string;
        set.add(modulesModified[0..num]);

        writefln("Modified modules: %s", set.values);

        // what do we need to clear here for a partial rebuild?

        // Wipe all modules that depend on modified module

        import std.array : replace;

        auto changeSet = new Set!string;

        void _check(string cn) {
            if(changeSet.contains(cn)) return;
            changeSet.add(cn);

            auto m = getModule(cn);

            auto refs = allModulesThatImport(m);
            writefln("\tImporters of %s = [%s]", cn, refs.map!(it=>it.canonicalName).join(","));

            foreach(r; refs) {
                _check(r.canonicalName);
            }
        }

        foreach(name; set.values) {
            auto canonicalName = config.getCanonicalName(name);
            _check(canonicalName);
        }

        writefln("\tchange set = [%s]", changeSet.values.map!(it=>it).join(","));

        foreach(change; changeSet.values) {
            // TODO - remove templates in any module that were added by any of the removed modules
            writefln("\tRemoving module %s from the cache", change);
            modules.remove(change);
        }

        startRebuild();
        moduleRequired(config.getMainModuleCanonicalName);

        parseAndResolve();
        if(hasErrors()) {
            dumpErrors();
            return;
        }

        removeUnreferencedNodesAfterResolution();
        afterResolution();

        if(hasErrors()) {
            dumpErrors();
            return;
        }

        semanticCheck();
        if(hasErrors()) {
            dumpErrors();
            return;
        }

        // TODO - if we are generating code at this point we need to check __runModuleConstructors
        //        if the main module has not been regenerated because the modules may have changed

        // TODO - I don't think numRefs matters but if it does we can probably adjust them using Target var/func

    }
    void dumpErrors() {
        writefln("ERRORS:");
        foreach(i, err; getErrors()) {
            // if(i < NUM_DETAILED_ERRORS) {
            //     writefln("[%s] %s\n", i+1, err.toPrettyString());
            // } else {
                writefln("\t[%s] %s", i+1, err.toConciseString());
            //}
        }
    }
    /// Async (watcherThread)
    void watchFolder() {
        writefln("Watching directory %s", config.basePath);
        auto set = new Set!FileChangeEvent;
        while(running) {
            set.add(watcher.getEvents());

            foreach (event; set.values) {

                writefln("event: %s", event);

                final switch(event.type) with(FileChangeEventType) {
                    case create: break;
                    case rename: break;
                    case remove: break;
                    case modify:
                        modifications.push(event.path);
                        builderSemaphore.notify();
                        break;
                    case createSelf: break;
                    case removeSelf: break;
                }
            }
            set.clear();
            Thread.sleep(dur!"msecs"(WATCH_SLEEP_INTERVAL));
        }
    }
}
