module ppl.misc.node_builder;

import ppl.internal;

final class NodeBuilder {
    Module module_;

    this(Module module_) {
        this.module_ = module_;
    }

    AddressOf addressOf(Expression expr) {
        auto a = makeNode!AddressOf;
        a.add(expr);
        return a;
    }
    As as(Expression left, Type type) {
        auto a = makeNode!As;
        a.add(left);
        a.add(typeExpr(type));
        return a;
    }
    Binary assign(Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary;
        b.type = type;
        b.op   = Operator.ASSIGN;

        b.add(left);
        b.add(right);
        return b;
    }
    Binary or(Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary;
        b.type = type;
        b.op   = Operator.BOOL_OR;

        b.add(left);
        b.add(right);
        return b;
    }
    Binary binary(Operator op, Expression left, Expression right, Type type=TYPE_UNKNOWN) {
        auto b = makeNode!Binary;
        b.type = type;
        b.op   = op;

        b.add(left);
        b.add(right);
        return b;
    }
    Call call(string name, Function f = null) {
        auto call   = makeNode!Call;
        call.target = new Target(module_);
        call.name   = name;
        if(f) {
            call.target.set(f);
        }
        return call;
    }
    /// eg. GC.start()
    /// Dot
    ///     TypeExpr
    ///     identifier
    Expression callStatic(string typeName, string memberName, ASTNode parent) {
        Type t = module_.typeFinder.findType(typeName, parent);
        assert(t);
        return dot(typeExpr(t), call(memberName));
    }
    Dot dot(ASTNode left, ASTNode right) {
        auto d = makeNode!Dot;
        d.add(left);
        d.add(right);
        return d;
    }
    EnumMember enumMember(Enum enum_, Expression expr) {
        auto em = makeNode!EnumMember;
        em.name = module_.makeTemporary("");
        em.type = enum_;
        em.add(expr);
        return em;
    }
    EnumMemberValue enumMemberValue(Enum enum_, Expression expr) {
        auto emv  = makeNode!EnumMemberValue;
        emv.enum_ = enum_;
        emv.add(expr);
        return emv;
    }
    Function function_(string name) {
        Function f   = makeNode!Function;
        f.name       = name;
        f.moduleName = module_.canonicalName;

        auto body_ = makeNode!LiteralFunction;

        auto params = makeNode!Parameters;
        body_.add(params);

        auto type   = makeNode!FunctionType;
        type.params = params;
        body_.type  = Pointer.of(type, 1);

        f.add(body_);

        return f;
    }
    Identifier identifier(Variable v) {
        auto id   = makeNode!Identifier;
        id.target = new Target(module_);
        id.name   = v.name;
        id.target.set(v);
        return id;
    }
    Identifier identifier(string name) {
        auto id   = makeNode!Identifier;
        id.target = new Target(module_);
        id.name   = name;
        return id;
    }
    If if_(Expression condition, Expression then, Expression else_ = null) {
        assert(condition);
        assert(then);

        auto i = makeNode!If;

        auto init = Composite.make(Composite.Usage.INLINE_KEEP);
        auto thn  = Composite.make(Composite.Usage.INNER_KEEP).add(then);
        auto els  = else_ ? Composite.make(Composite.Usage.INNER_KEEP).add(else_) : null;

        i.add(init);
        i.add(condition);
        i.add(thn);
        if(els) i.add(els);

        return i;
    }
    Index index(Expression left, Expression right) {
        auto i = makeNode!Index;
        i.add(left);
        i.add(right);
        return i;
    }
    Expression integer(int value) {
        return LiteralNumber.makeConst(value, TYPE_INT);
    }
    Return return_(Expression expr) {
        auto ret = makeNode!Return;
        ret.add(expr);
        return ret;
    }
    Return returnVoid() {
        auto ret = makeNode!Return;
        return ret;
    }
    TypeExpr typeExpr(Type t) {
        auto e = makeNode!TypeExpr;
        e.type = t;
        return e;
    }
    Unary unary(Operator op, Expression expr) {
        auto u = makeNode!Unary;
        u.op = op;
        u.add(expr);
        return u;
    }
    Unary not(Expression expr) {
        auto u = makeNode!Unary;
        u.op = Operator.BOOL_NOT;
        u.add(expr);
        return u;
    }
    ValueOf valueOf(Expression expr) {
        auto v = makeNode!ValueOf;
        v.add(expr);
        return v;
    }
    Variable variable(string name, Type t, bool isConst = false) {
        auto var    = makeNode!Variable;
        var.name    = name;
        var.type    = t;
        var.isConst = isConst;
        return var;
    }

    Constructor string_(LiteralString lit) {
        /// Create an alloca
        auto con = makeNode!Constructor;
        con.type = module_.typeFinder.findType("string", module_);

        auto var = variable(module_.makeTemporary("str"), con.type);
        con.add(var);

        /// Call string.new(this, byte*, int)
        Call call = call("new");
            call.add(addressOf(identifier(var.name)));
            call.add(lit);
            call.add(LiteralNumber.makeConst(lit.calculateLength(), TYPE_INT));

        //auto dot = dot(identifier(var.name), call);

        //auto valueof = valueOf(dot);
        con.add(valueOf(dot(identifier(var.name), call)));
        return con;
    }

    /**
    // Replace:
    //
    // e
    //
    // if
    //   Composite
    //   Composite
    //     not
    //       e
    //   Composite
    //     call
    //       __nullCheckFail
    //         modulename
    //         line
    //     e
    //   Composite
    //     e
    */
    void addNullCheck(Expression e) {
        auto p = e.parent;
        auto dummy = LiteralNumber.makeConst(0, TYPE_INT);
        p.replaceChild(e, dummy);
        //p.dumpToConsole();

        auto moduleName = module_.moduleNameLiteral.copy();
        auto line = LiteralNumber.makeConst(e.line+1, TYPE_INT);

        auto call = this.call("__nullCheckFail")
            .add(moduleName)
            .add(line)
            .as!Expression;

        auto if_ = this.if_(not(e), call, ExpressionRef.make(e));

        call.parent.add(ExpressionRef.make(e));

        p.replaceChild(dummy, if_);

        //p.dumpToConsole();
    }
}

