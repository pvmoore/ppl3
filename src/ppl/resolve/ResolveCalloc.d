module ppl.resolve.ResolveCalloc;

import ppl.internal;

final class ResolveCalloc {
private:
    Module module_;
    ResolveModule resolver;
    FoldUnreferenced foldUnreferenced;
public:
    this(ResolveModule resolver) {
        this.resolver         = resolver;
        this.module_          = resolver.module_;
        this.foldUnreferenced = resolver.foldUnreferenced;
    }
    void resolve(Calloc n) {
        resolver.resolveAlias(n, n.valueType);

        if(n.valueType.isKnown) {
            /// Rewrite Calloc to:

            /// As
            ///     Dot
            ///         GC
            ///         call calloc
            ///             size
            ///     TypeExpr

            auto b = module_.builder(n);

            auto dot = b.callStatic("GC", "calloc", n);
            dot.second().add(b.integer(n.valueType.size));

            auto as = b.as(dot, n.getType);

            foldUnreferenced.fold(n, as);
        }
    }
}