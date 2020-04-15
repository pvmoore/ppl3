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

        if(n.isResolved) {
            assert(n.type.isStructOrClass());

            auto struct_ = n.type.getStruct;

            if(n.type.getPtrDepth() > 1) {
                module_.addError(n, "Cannot construct an instance of type %s".format(n.type), true);
                return;
            }

            /// If struct is a POD then rewrite call to individual property setters
            if(struct_.isPOD) {

                if(n.type.isClass()) {
                    module_.addError(n, "Classes cannot be POD", true);
                } else {
                    rewriteToPOD(n, struct_);
                }
                return;
            }
        } else {

        }
    }
private:
    void rewriteToPOD(Constructor n, Struct struct_) {
        /// Rewrite call args as identifier = value

        /// S(...)
        ///    Variable _temp
        ///    Dot
        ///       _temp
        ///       Call new
        ///          AddressOf
        ///             _temp
        ///          [ optional args ] <--- move these --|
        ///    <-- to here ------------------------------|
        ///    assign
        ///       dot
        ///          _temp
        ///          name
        ///       arg
        ///
        ///    _temp

        /// S*(...)
        ///    Variable _temp (type=S*)
        ///    _temp = calloc
        ///    Dot
        ///       _temp
        ///       Call new
        ///          _temp
        ///          [ optional args ] <--- move these --|
        ///    <-- to here ------------------------------|
        ///    assign
        ///       dot
        ///          _temp
        ///          name
        ///       arg
        ///    _temp
        ///

        auto b = module_.nodeBuilder;

        auto var  = n.first().as!Variable;

        /// Find the call to 'new'
        Call call;
        n.recurse!Call( (it) { if(it.name=="new") call = it; });
        assert(var);
        assert(call);

        auto args  = call.args()[1..$].dup;
        auto names = call.paramNames ? call.paramNames[1..$] : null;
        if(args.length==0) return;

        string getMemberName(int index) {

            string badIndex() {
                module_.addError(n, "Too many initialiers. Found %s, expecting %s or fewer"
                    .format(args.length, struct_.numMemberVariables), true);
                return null;
            }

            if(names) {
                if(index>=names.length) {
                    return badIndex();
                }
                return names[index];
            } else {
                if(index>=struct_.numMemberVariables) {
                    return badIndex();
                }
                return struct_.getMemberVariable(index).name;
            }
        }

        foreach(i, arg; args) {
            auto name = getMemberName(i.toInt);
            if(!name) return;

            /// assign
            ///    dot
            ///       var.name
            ///       name
            ///    arg

            auto dot = b.dot(b.identifier(var), b.identifier(name));
            auto bin = b.binary(Operator.ASSIGN, dot, arg);

            n.insertAt(n.numChildren-1, bin);

        }

        call.paramNames = null;
    }
}