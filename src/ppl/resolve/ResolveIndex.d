module ppl.resolve.ResolveIndex;

import ppl.internal;

final class ResolveIndex {
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
    void resolve(Index n) {
        if(n.exprType().isStruct) {
            /// Rewrite this to a call to operator[]

            auto ns = n.exprType.getStruct;

            auto b = module_.nodeBuilder;

            if(n.parent.isBinary) {
                auto bin = n.parent.as!Binary;
                if(bin.op.isAssign && n.nid==bin.left.nid) {
                    /// Rewrite to operator[](int,value)

                    /// Binary =
                    ///     Index
                    ///         index
                    ///         struct
                    ///     expr
                    ///....................
                    /// Dot
                    ///     [AddressOf] struct
                    ///     Call
                    ///         index
                    ///         expr
                    auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
                    auto call = b.call("operator[]", null)
                                 .add(n.index)
                                 .add(bin.right);

                    auto dot = b.dot(left, call);

                    foldUnreferenced.fold(bin, dot);

                    return;
                }
            }

            /// Rewrite to operator[](int)

            /// Index
            ///     struct
            ///     index
            ///.............
            /// Dot
            ///     [AddressOf] struct
            ///     Call
            ///         index
            auto left = n.exprType.isValue ? b.addressOf(n.expr) : n.expr;
            auto call = b.call("operator[]", null)
                         .add(n.index);

            auto dot = b.dot(left, call);

            foldUnreferenced.fold(n, dot);

            return;

        }
    }
}