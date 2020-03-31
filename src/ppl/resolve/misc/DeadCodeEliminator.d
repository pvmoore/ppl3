module ppl.resolve.misc.DeadCodeEliminator;

import ppl.internal;
///
/// Remove any nodes that do not affect the result. ie. they are not referenced
///
final class DeadCodeEliminator {
private:
    BuildState state;
    StopWatch watch;
public:
    this(BuildState state) {
        this.state = state;
    }
    void clearState() {
        watch.reset();
    }

    ulong getElapsedNanos() { return watch.peek().total!"nsecs"; }

    auto removeUnreferencedModules() {
        watch.start();
        scope(exit) watch.stop();
        log("Removing unreferenced modules");

        auto removeMe = new DynamicArray!Module;
        foreach(m; state.allModules) {
            if(m.numRefs==0) {
                log("\t  Removing unreferenced module %s", m.canonicalName);
                removeMe.add(m);
            }
        }
        foreach(m; removeMe) {
            state.removeModule(m.canonicalName);
        }
        return this;
    }
    void removeUnreferencedNodesAfterResolution() {
        watch.start();
        scope(exit) watch.stop();
        log("Removing unreferenced nodes after resolution");

        foreach(m; state.allModules) {
            removePrivateAliases(m);
            removeAllImports(m);
            if(!state.config.enableAsserts) {
                removeAllAsserts(m);
            }
            removeUnreferencedGlobalVariables(m);
            removePrivateStructBlueprints(m);
            removeUnreferencedPrivateFunctions(m);
        }

        removeAllUnreferencedPrivateStructs();
        removeAllUnreferencedPrivateEnums();
    }
private:
    void removePrivateAliases(Module m) {
        auto aliases = new DynamicArray!Alias;
        m.selectDescendents!Alias(aliases);
        foreach(a; aliases) {
            // NOTE: Leave public aliases so that they can still be accessed by the incremental builder
            if(a.access.isPrivate) {
                log("\t alias %s", a.name);
                remove(a, m);
            }
        }
    }
    void removeAllImports(Module m) {
        auto imports = new DynamicArray!Import;
        m.selectDescendents!Import(imports);
        foreach(imp; imports) {
            log("\t import %s", imp.moduleName);
            remove(imp, m);
        }
    }
    void removeAllAsserts(Module m) {
        auto asserts = new DynamicArray!Assert;
        m.selectDescendents!Assert(asserts);
        foreach(a; asserts) {
            remove(a, m);
        }
    }
    void removeUnreferencedPrivateFunctions(Module m) {
        auto functions = new DynamicArray!Function;
        m.selectDescendents!Function(functions);

        foreach(f; functions) {
            if(f.isImport) {
                log("\t  proxy func %s", f.name);
                remove(f, m);
            } else if(f.access.isPublic) {
                // keep these
            } else if(f.isTemplateBlueprint) {
                log("\t  template func %s", f.name);
                remove(f, m);
            } else if(f.numRefs==0 && f.name!="new") {
            //} else if(f.numRefs==0 && (f.name!="new" || !f.isGlobal)) {
                log("\t  unreferenced func %s", f);

                if(f.isGlobal && f.access.isPrivate) {
                    warn(f, "Unreferenced function %s should have been removed during resolve phase".format(f));
                }

                remove(f, m);
            }
        }
    }
    void removeUnreferencedGlobalVariables(Module m) {
        foreach(v; m.getVariables()) {
            if(v.numRefs==0) {

                warn(v, "Unreferenced variable %s should have been removed during resolve phase".format(v));

                remove(v, m);
            }
        }
    }
    void removePrivateStructBlueprints(Module m) {
        foreach(s; getAllDeclaredStructs(m)) {
            if(s.isTemplateBlueprint) {
                if(s.access.isPrivate) {
                    log("\t  struct template blueprint %s", s.name);
                    remove(s, m);
                }
            }
        }
    }
    Struct[] getAllDeclaredStructs(Module m) {
        auto structs = new DynamicArray!Struct;
        m.selectDescendents!Struct(structs);
        return structs.values;
    }
    Enum[] getAllDeclaredEnums(Module m) {
        auto enums = new DynamicArray!Enum;
        m.selectDescendents!Enum(enums);
        return enums.values;
    }
    Struct[] getAllReferencedStructs(Module m) {
        auto structs = new Set!Struct;
        m.recurse!ASTNode(
            n => n.id!=NodeID.STRUCT,
            (n) {
                auto type = n.getType;

                /// Type may not be known if this is a template function
                auto s = type.isKnown ? type.getStruct : null;
                if(s) {
                    structs.add(s);
                }
            }
        );
        return structs.values;
    }
    Enum[] getAllReferencedEnums(Module m) {
        auto enums = new Set!Enum;
        m.recurse!ASTNode(
            n => !n.isModule &&
                 n.id!=NodeID.ENUM && n.parent.id!=NodeID.ENUM,
            (n) {
                auto type = n.getType;

                /// Type may not be known if this is a template function
                auto e = type.isKnown ? type.getEnum : null;
                if(e) {
                    enums.add(e);
                }
            }
        );
        return enums.values;
    }
    void removeAllUnreferencedPrivateStructs() {
        auto allDeclaredStructs = new Set!Struct;
        auto allReferencedStructs = new Set!Struct;
        foreach(m; state.allModules) {
            allDeclaredStructs.add(getAllDeclaredStructs(m));
            allReferencedStructs.add(getAllReferencedStructs(m));
        }
        foreach(s; allDeclaredStructs.values) {
            if(!allReferencedStructs.contains(s)) {
                //dd("removing struct", s.getModule.canonicalName, s.name);
                if(s.access.isPrivate) {
                    remove(s);
                }
            } else {
                /// The struct is referenced but some of the functions may not be
                foreach(f; s.getMemberFunctions()) {
                    if(f.numRefs==0) {
                        //dd("\t  ---> unreferenced func", s.name, f.name);
                        //remove(f);
                    }
                }
            }
        }
    }
    void removeAllUnreferencedPrivateEnums() {
        auto allDeclaredEnums = new Set!Enum;
        auto allReferencedEnums = new Set!Enum;
        foreach(m; state.allModules) {
            allDeclaredEnums.add(getAllDeclaredEnums(m));
            allReferencedEnums.add(getAllReferencedEnums(m));
        }
        foreach(e; allDeclaredEnums.values) {
            if(!allReferencedEnums.contains(e)) {
                if(e.access.isPrivate) {
                    //dd("removing enum", e.getModule.canonicalName, e.name);
                    remove(e);
                }
            }
        }
    }
    void remove(ASTNode n, Module m = null) {

        if(!n.isAttached) return;
        if(!m) m = n.getModule;
        n.detach();
        FoldUnreferenced.recursiveDereference(n, m);
    }
}