module ppl.resolve.ResolveAlias;

import ppl.internal;

final class ResolveAlias {
  private:
    Module module_;
    ResolveModule resolveModule;
    FoldUnreferenced foldUnreferenced;
public:
    this(ResolveModule resolveModule) {
        this.resolveModule    = resolveModule;
        this.module_          = resolveModule.module_;
        this.foldUnreferenced = resolveModule.foldUnreferenced;
    }
    void resolve(ASTNode node, ref Type type) {
        if(!type.isAlias) return;

        auto alias_ = type.getAlias;

        /+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ inner +/
        void _resolveTo(Type toType) {
            type = Pointer.of(toType, type.getPtrDepth);
            resolveModule.setModified();

            auto node = cast(ASTNode)toType;
            if(node) {
                auto access = node.getAccess();
                if(access.isPrivate && module_.nid!=node.getModule().nid) {
                    module_.addError(alias_, "Type %s is private".format(node), true);
                }
            }

            if(alias_.parent && alias_.parent.id==NodeID.IMPORT) {
                /// This is an import alias. Leave it attached
            } else if(!type.isAlias) {
                //dd("!! detaching alias", alias_);

                if(alias_.isInnerType) {
                    alias_.detach();
                }
            }
        }
        /+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/

        /// Handle import
        if(alias_.isImport) {
            auto m = module_.buildState.getOrCreateModule(alias_.moduleName);
            if(!m.isParsed) {
                /// Come back when m is parsed
                return;
            }
            Type externalType = m.getAlias(alias_.name);
            if(!externalType) externalType = m.getStruct(alias_.name);
            if(!externalType) externalType = m.getEnum(alias_.name);
            if(!externalType) {
                module_.addError(module_, "Import %s not found in module %s".format(alias_.name, alias_.moduleName), true);
                return;
            }

            _resolveTo(externalType);
            return;
        }

        /// type<...>
        if(alias_.isTemplateProxy) {

            /// Ensure template params are resolved
            foreach(ref t; alias_.templateParams) {
                resolve(node, t);
            }

            /// Resolve until we have the Struct
            if(alias_.type.isAlias) {
                resolve(node, alias_.type);
            }
            if(!alias_.type.isStruct) {
                resolveModule.addUnresolved(alias_);
                return;
            }

            if(!alias_.templateParams.areKnown) {
                resolveModule.addUnresolved(alias_);
                return;
            }
        }
        /// type::type2::type3 etc...
        if(alias_.isInnerType) {

            resolve(node, alias_.type);

            if(alias_.type.isAlias) {
                resolveModule.addUnresolved(alias_);
                return;
            }
        }

        if(alias_.isTemplateProxy || alias_.isInnerType) {

            /// We now have a Struct to work with
            auto ns = alias_.type.getStruct;
            assert(ns);

            string mangledName;
            if(alias_.isInnerType) {
                mangledName ~= alias_.name;
            } else {
                mangledName ~= ns.name;
            }
            if(alias_.isTemplateProxy) {
                mangledName ~= "<" ~ module_.buildState.mangler.mangle(alias_.templateParams) ~ ">";
            }

            auto t = module_.typeFinder.findType(mangledName, ns, alias_.isInnerType);
            if(t) {
                /// Found

                /// Check that the inner type is visible
                if(alias_.isInnerType) {
                    if(getAccess(t.as!ASTNode).isPrivate) {
                        auto callerStruct = node.getAncestor!Struct;

                        if(!callerStruct || callerStruct != ns) {
                            module_.addError(alias_, "Inner type %s is not visible".format(t), true);
                        }
                    }
                }

                _resolveTo(t);
            } else {

                if(alias_.isInnerType) {
                    /// Find the template blueprint
                    string parentName = ns.name;
                    ns = ns.getStruct(alias_.name);
                    if(!ns) {
                        module_.addError(alias_, "Struct %s does not have inner type %s".format(parentName, alias_.name), true);
                        return;
                    }
                }

                if(alias_.isTemplateProxy) {
                    /// Extract the template
                    auto structModule = module_.buildState.getOrCreateModule(ns.moduleName);
                    structModule.templates.extract(ns, node, mangledName, alias_.templateParams);

                    resolveModule.addUnresolved(alias_);
                }
            }
            return;
        }

        if(alias_.type.isKnown || alias_.type.isAlias) {
            /// Switch to the Aliased type
            _resolveTo(alias_.type);
        } else {
            resolveModule.addUnresolved(alias_);
        }
    }
}