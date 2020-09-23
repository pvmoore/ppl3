module ppl.resolve.misc.TypeFinder;

import ppl.internal;

final class TypeFinder {
private:
    Module module_;
    bool doChat;
public:
    this(Module module_) {
        this.module_ = module_;
    }
    ///
    /// Look for a Alias, Enum, Struct or Class with given name starting from _node_.
    ///
    /// It is expected that this function is used during the parse phase so that
    /// is why we treat all nodes within a literal function as possible targets.
    /// This allows us to use the parent (literal function) to find a node which
    /// wouldn't normally be necessary if we started from the node itself (which we may not have).
    ///
    Type findType(string name, ASTNode node, bool isInnerType = false) {

        //doChat = true || name=="Optional<float>";
        //chat("findType %s from %s line %s", name, node.id, node.line);

        Type _find(ASTNode n) {
            auto def = n.as!Alias;
            if(def) {
                if(def.name==name) return def;
            }

            auto ns = n.as!Struct;
            if(ns && ns.name==name) return ns;

            auto en = n.as!Enum;
            if(en && en.name==name) return en;

            auto ph = n.as!Placeholder;
            if(ph) {
                /// Treat children of Placeholder as if they were in scope
                foreach(ch; ph.children) {
                    auto t = _find(ch);
                    if(t) return t;
                }
            }

            auto comp = n.as!Composite;
            if(comp) {
                /// Treat children of Composite as if they were in scope
                if(comp.isInline) {
                    foreach(ch; comp.children) {
                        auto t = _find(ch);
                        if(t) return t;
                    }
                }
            }

            auto imp = n.as!Import;
            if(imp && !imp.hasAliasName) {
                foreach(ch; imp.children) {
                    auto t = _find(ch);
                    if(t) return t;
                }
            }
            return null;
        }

        auto nid = node.id();

        //dd("\t\tfindNode '%s' %s".format(name, node.id()));

        if(nid==NodeID.MODULE) {
            /// Check all module level nodes
            foreach (n; node.children) {
                auto t = _find(n);
                if (t) return found(t);
            }

            // Check module structs and classes. The type may not have been parsed yet
            if(module_.parser.classes.contains(name)) {
                // Add class _name_ to module scope
                //module_.addToFront()
            }
            if(module_.parser.structs.contains(name)) {
                // Add struct _name_ to module scope
                // auto struct_ = makeNode!Struct;
                // struct_.name = name;
                // struct_.moduleName = module_.canonicalName;
                // struct_.isDeclarationOnly = true;
                // module_.addToFront(struct_);
                // dd("!!! --->", name);
                // return found(struct_);
            }

            return null;

        } else if(nid==NodeID.TUPLE || nid==NodeID.STRUCT || nid==NodeID.CLASS || nid==NodeID.LITERAL_FUNCTION) {
            /// Check all scope level nodes
            foreach(n; node.children) {
                auto t = _find(n);
                if(t) return found(t);
            }
            /// If we are looking for an inner type then we haven't found it
            if(isInnerType) {
                return null;
            }

            /// Recurse up the tree
            return findType(name, node.parent);
        }
        /// Check nodes that appear before 'node' in current scope
        foreach(n; node.prevSiblings()) {
            auto t = _find(n);
            if(t) return found(t);
        }
        /// Recurse up the tree
        return findType(name, node.parent);
    }
    ///
    /// A more advanced findType function that handles template params
    ///
    Type findTemplateType(Type untemplatedType, ASTNode node, Type[] templateParams) {
        auto type = untemplatedType;

        assert(templateParams.length>0);
        assert(type && (type.isAlias || type.isStructOrClass()));

        auto alias_ = type.getAlias;
        auto ns     = type.getStruct;
        assert(alias_ !is null || ns !is null);

        found(type);

        string name = ns ? ns.name : alias_.name;

        if(templateParams.areKnown) {
            string name2      = name ~ "<" ~ module_.buildState.mangler.mangle(templateParams) ~ ">";
            auto concreteType = findType(name2, node);
            if(concreteType) {
                /// We found the concrete impl
                return concreteType;
            }
        }

        /// Create a template proxy Alias which can
        /// be replaced later by the concrete Struct
        auto proxy           = Alias.make(node, Alias.Kind.TEMPLATE_PROXY);
        proxy.name           = module_.makeTemporary("templateProxy");
        proxy.type           = type;
        proxy.moduleName     = module_.canonicalName;
        proxy.isImport       = false;
        proxy.templateParams = templateParams;

        type = proxy;

        //dd("!!template proxy =", ns ? "NS:" ~ ns.name : "Def:" ~ def.name, templateParams);

        return type;
    }
private:
    Type found(Type t) {
        auto alias_ = t.getAlias;
        auto ns     = t.getStruct;
        auto en     = t.getEnum;
        assert(alias_ !is null || ns !is null || en !is null);

        if(alias_) {
            module_.buildState.moduleRequired(alias_.moduleName);
        } else if(en) {
            module_.buildState.moduleRequired(en.moduleName);
        } else {
            module_.buildState.moduleRequired(ns.moduleName);
        }

        return t;
    }
    void chat(A...)(lazy string fmt, lazy A args) {
        if(doChat) {
            dd(format(fmt, args));
        }
    }
}
