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
    FileWatch watcher;
    Thread watcherThread, builderThread;
    Semaphore builderSemaphore;
    Mutex mutex;
    bool running = true;

public:
    this(LLVMWrapper llvmWrapper, Config config) {
        if(!From!"std.file".exists(config.basePath)) throw new Error("%s is not a directory".format(config.basePath));

        super(llvmWrapper, config);

        this.llvmWrapper = llvmWrapper;
        this.config = config;
        this.builderSemaphore = new Semaphore(1);
        this.mutex = new Mutex;
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
    }
    /// Async (builderThread)
    void build() {
        while(running) {
            writefln("Builder waiting for work");
            builderSemaphore.wait();
            if(!running) return;

            writefln("Builder starting work");
            watch.start();
            bool astDumped;

            try{
                buildAll();

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
                watch.stop();
            }
        }
    }
    /**
     *  Rebuild everything from scratch.
     *
     *  Async (builderThread)
     */
    private void buildAll() {
        startNewBuild();

        functionRequired(config.getMainModuleCanonicalName, config.getEntryFunctionName());

        parseAndResolve();
        if(hasErrors()) {

        }

        afterResolution();
        if(hasErrors()) {

        }

        semanticCheck();
        if(hasErrors()) {

        }
    }
    /// Async (watcherThread)
    void watchFolder() {
        writefln("Watching directory %s", config.basePath);
        while(running) {
            foreach (event; watcher.getEvents()) {

                writefln("event: %s", event);

                final switch(event.type) with(FileChangeEventType) {
                    case create: break;
                    case rename: break;
                    case remove: break;
                    case modify:
                        builderSemaphore.notify();
                        break;
                    case createSelf: break;
                    case removeSelf: break;
                }
            }
            Thread.sleep(dur!"msecs"(500));
        }
    }
}
