module ppl.build.AfterResolution;

import ppl.internal;
///
/// These tasks need to be done after all nodes have been resolved
///
final class AfterResolution {
private:
    BuildState buildState;
public:
    this(BuildState buildState) {
        this.buildState = buildState;
    }
    void process(Module[] modules) {
        //bool hasMainModule = buildState.mainModule !is null;
        //Module mainModule  = buildState.mainModule;
        //Function entry     = hasMainModule ?
        //        mainModule.getFunctions(buildState.config.getEntryFunctionName())[0]
        //        : null;

        //auto calls = new DynamicArray!Call;

        foreach(mod; modules) {

            if(mod.afterResolutionHasRun) {
                continue;
            }
            mod.afterResolutionHasRun = true;

            auto initFunc = mod.getInitFunction();
            auto initBody = initFunc.getBody();

            /// Move struct static var initialisers into module new()
            foreach(ns; mod.getStructsAndClassesRecurse) {
                foreach_reverse(v; ns.getStaticVariables) {
                    if(v.hasInitialiser) {
                        initBody.insertAt(1, v.initialiser);
                    }
                }
            }
            /// Move global var initialisers into module new()
            foreach_reverse(v; mod.getVariables()) {

                if(v.hasInitialiser) {
                    /// Parameters should always be the 1st child of body so we insert at 1
                    initBody.insertAt(1, v.initialiser);
                }
            }
        }

        addModuleConstructorCalls();
    }
private:
    /**
     *  main() {
     *      GC.start()
     *      call __runModuleConstructors()
     *      ...
     *  }
     *  __runModuleConstructors() {
     *      for each module:
     *          module.new()
     *  }
     */
    void addModuleConstructorCalls() {
        if(buildState.mainModule is null) return;

        Module mainModule = buildState.mainModule;
        Function entry    = mainModule.getFunctions(buildState.config.getEntryFunctionName())[0];

        alias comparator = (Module a, Module b) {
            return a.getPriority > b.getPriority;
        };

        auto builder = mainModule.nodeBuilder;

        /// Find __runModuleConstructors function
        auto rmcFuncs = mainModule.getFunctions("__runModuleConstructors");
        assert(rmcFuncs.length==1);
        auto rmcFunc = rmcFuncs[0];

        assert(rmcFunc.getBody().children[0].isA!Parameters);
        assert(rmcFunc.getBody().children[1].isA!Return);

        foreach(mod; buildState.allModules.sort!(comparator)) {
            //writefln("[%s] %s", mod.getPriority, mod.canonicalName);

            auto call = builder.call("new", mod.getInitFunction());

            rmcFunc.getBody().insertAt(1, call);

            /// Add after Parameters and call to GC.start()
            //entry.getBody().insertAt(2, call);


        }

        assert(entry.getBody().first().isA!Parameters);

        assert(entry.getBody().children[1].isA!Dot &&
               entry.getBody().children[1].as!Dot.right().isA!Call &&
               entry.getBody().children[1].as!Dot.right().getCall().name=="start");
    }
}