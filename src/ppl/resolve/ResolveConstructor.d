module ppl.resolve.ResolveConstructor;

import ppl.internal;


final class ResolveConstructor {
private:
    Module module_;
    ResolveModule resolver;
    ResolveAlias aliasResolver;
    FoldUnreferenced foldUnreferenced;
public:
    this(ResolveModule resolver) {
        this.resolver         = resolver;
        this.module_          = resolver.module_;
        this.aliasResolver    = resolver.aliasResolver;
        this.foldUnreferenced = resolver.foldUnreferenced;
    }
    void resolve(Constructor n) {
        aliasResolver.resolve(n, n.type);

        if(n.isRewritten==false && n.type.isKnown) {

            rewrite(n);
        }

        if(n.isResolved) {
            assert(n.type.isStructOrClass());

            auto struct_ = n.type.getStruct;

            if(n.type.getPtrDepth() > 1) {
                module_.addError(n, "Cannot construct an instance of type %s".format(n.type), true);
                return;
            }

            /// If struct is a POD then rewrite call to individual property setters
            // if(struct_.isPOD) {

            //     if(n.type.isClass()) {
            //         module_.addError(n, "Classes cannot be POD", true);
            //     } else {
            //         rewriteToPOD(n, struct_);
            //     }
            //     return;
            // }
        }
    }
private:
    /**
     * Rewrite this:
     *
     * Constructor
     *    Call "new"
     *       { args }
     *
     * To this depending on whether the type is a value | pointer | POD:
     *
     * Constructor type = S or type = S*
     *    Variable _temp (type=S or S*)
     *    _temp = calloc    // if ptr
     *    Dot
     *       _temp
     *       Call new
     *          _temp | addressof(_temp)
     *          [ args ]                    // if non-POD
     *    _temp.name = arg                  // for each arg if POD
     *    _temp
     */
    void rewrite(Constructor n) {
        /// Constructor
        ///     Call "new"
        ///         { args }
        assert(n.type.isStructOrClass());
        assert(n.numChildren()==1);
        assert(n.first().isA!Call);

        auto b = module_.nodeBuilder;
        auto struct_ = n.type.getStruct;
        auto call = n.first().getCall();
        auto numArgs = call.numChildren();
        auto names = call.paramNames ? call.paramNames : null;
        auto args  = call.args().dup;
        auto isPOD = struct_.isPOD();

        if(struct_.isA!Class && isPOD) {
            module_.addError(n, "Classes cannot be POD", true);
        }

        Variable _makeVariable() {
            import common : contains;
            auto prefix = n.getName();
            if(prefix.contains("__")) prefix = "constructor";
            return b.variable(module_.makeTemporary(prefix), n.type, false);
        }
        string _getMemberName(int index) {

            string _badIndex() {
                module_.addError(n, "Too many initialiers. Found %s, expecting %s or fewer"
                    .format(numArgs, struct_.numMemberVariables), true);
                return null;
            }

            if(names) {
                if(index>=names.length) {
                    return _badIndex();
                }
                return names[index];
            } else {
                if(index>=struct_.numMemberVariables) {
                    return _badIndex();
                }
                return struct_.getMemberVariable(index).name;
            }
        }

        Variable var = _makeVariable();
        n.add(var);

        /// Constructor
        ///     Call "new"
        ///         { args }
        ///     Variable _temp

        /// allocate memory
        if(n.type.isPtr) {
            /// Heap calloc

            if(n.type.getPtrDepth() > 1) {
                module_.addError(n, "Cannot construct an instance of type %s".format(n.type), true);
            }

            auto calloc  = makeNode!Calloc;
            calloc.valueType = n.type.getValueType;
            n.add(b.assign(b.identifier(var.name), calloc));

            call.addToFront(b.identifier(var.name));

            /// Constructor
            ///     Call "new"
            ///         _temp
            ///         { args }
            ///     Variable _temp
            ///     assign
            ///         _temp
            ///         calloc
            assert(n.numChildren()==3);

        } else {
            /// Stack alloca
            call.addToFront(b.addressOf(b.identifier(var.name)));

            /// Constructor
            ///     Call "new"
            ///         AddressOf
            ///             _temp
            ///         { args }
            ///     Variable _temp
            assert(n.numChildren()==2);
        }

        auto dot = b.dot(b.identifier(var), call);
        n.add(dot);
        n.add(b.identifier(var));

        /// Constructor
        ///     Variable _temp
        ///     { _temp = calloc }
        ///     Dot
        ///         _temp
        ///         Call new
        ///             etc...
        ///     _temp

        if(struct_.isPOD) {
            /// Rewrite call args to assignments

            foreach(i, arg; args) {
                auto name = _getMemberName(i.as!int);
                if(!name) return;

                /// assign
                ///    dot
                ///       _temp
                ///       name
                ///    arg

                auto dot2 = b.dot(b.identifier(var), b.identifier(name));
                auto bin  = b.binary(Operator.ASSIGN, dot2, arg);

                n.insertAt(n.numChildren()-1, bin);
            }

            call.paramNames = null;
        } else {
            if(call.paramNames.length > 0) {
                call.paramNames = "this" ~ call.paramNames;
            }
        }

        n.isRewritten = true;
    }
}