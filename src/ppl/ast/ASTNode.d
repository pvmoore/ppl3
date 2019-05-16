module ppl.ast.ASTNode;

import ppl.internal;

//=============================================================================== NodeID
enum NodeID {
    ADDRESS_OF,
    ALIAS,
    ARRAY,
    AS,
    ASSERT,
    BINARY,
    BREAK,
    BUILTIN_FUNC,
    CALL,
    CALLOC,
    CASE,
    COMPOSITE,
    CONSTRUCTOR,
    CONTINUE,
    DOT,
    LITERAL_EXPR_LIST,
    ENUM,
    ENUM_MEMBER,
    ENUM_MEMBER_REF,
    ENUM_MEMBER_VALUE,
    FUNC_TYPE,
    FUNCTION,
    IDENTIFIER,
    IF,
    IMPORT,
    INITIALISER,
    IS,
    INDEX,
    LAMBDA,
    LITERAL_ARRAY,
    LITERAL_FUNCTION,
    LITERAL_MAP,
    LITERAL_NULL,
    LITERAL_NUMBER,
    LITERAL_STRING,
    LITERAL_TUPLE,
    LOOP,
    META_FUNCTION,
    MODULE,
    MODULE_ALIAS,
    PARAMETERS,
    PARENTHESIS,
    RETURN,
    SELECT,
    STRUCT,
    STRUCT_CONSTRUCTOR,
    TUPLE,
    TYPE_EXPR,
    UNARY,
    VALUE_OF,
    VARIABLE,
}
//=============================================================================== ASTNode
T makeNode(T)() {
    T n = new T;
    n.nid = g_nodeid++;
    assert(n.children);
    return n;
}
T makeNode(T)(Tokens t) {
    T n          = new T;
    n.nid        = g_nodeid++;
    n.line       = t.line;
    n.column     = t.column;
    n.attributes = t.getAttributesAndClear();
    assert(n.children);
    return n;
}
T makeNode(T)(ASTNode p) {
    T n      = new T;
    n.nid    = g_nodeid++;
    n.line   = p ? p.line   : -1;
    n.column = p ? p.column : -1;
    assert(n.children);
    return n;
}
bool isAs(inout ASTNode n)              { return n.id()==NodeID.AS; }
bool isBinary(inout ASTNode n)          { return n.id()==NodeID.BINARY; }
bool isCall(inout ASTNode n)            { return n.id()==NodeID.CALL; }
bool isCase(inout ASTNode n)            { return n.id()==NodeID.CASE; }
bool isComposite(inout ASTNode n)       { return n.id()==NodeID.COMPOSITE; }
bool isAlias(inout ASTNode n)           { return n.id()==NodeID.ALIAS; }
bool isDot(inout ASTNode n)             { return n.id()==NodeID.DOT; }
bool isExpression(inout ASTNode n)      { return n.as!Expression !is null; }
bool isFunction(inout ASTNode n)        { return n.id()==NodeID.FUNCTION; }
bool isIdentifier(inout ASTNode n)      { return n.id()==NodeID.IDENTIFIER; }
bool isIf(inout ASTNode n)              { return n.id()==NodeID.IF; }
bool isIndex(inout ASTNode n)           { return n.id()==NodeID.INDEX; }
bool isInitialiser(inout ASTNode n)     { return n.id()==NodeID.INITIALISER; }
bool isLambda(inout ASTNode n)          { return n.id()==NodeID.LAMBDA; }
bool isLiteralNull(inout ASTNode n)     { return n.id()==NodeID.LITERAL_NULL; }
bool isLiteralNumber(inout ASTNode n)   { return n.id()==NodeID.LITERAL_NUMBER; }
bool isLiteralFunction(inout ASTNode n) { return n.id()==NodeID.LITERAL_FUNCTION; }
bool isLoop(inout ASTNode n)            { return n.id()==NodeID.LOOP; }
bool isModule(inout ASTNode n)          { return n.id()==NodeID.MODULE; }
bool isReturn(inout ASTNode n)          { return n.id()==NodeID.RETURN; }
bool isSelect(inout ASTNode n)          { return n.id()==NodeID.SELECT; }
bool isTypeExpr(inout ASTNode n)        { return n.id()==NodeID.TYPE_EXPR; }
bool isVariable(inout ASTNode n)        { return n.id()==NodeID.VARIABLE; }

bool areAll(NodeID ID)(ASTNode[] n) { return n.all!(it=>it.id==ID); }
bool areResolved(ASTNode[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Expression[] nodes) { return nodes.all!(it=>it.isResolved); }
bool areResolved(Variable[] nodes) { return nodes.all!(it=>it.isResolved); }

abstract class ASTNode {
private:
    Module module_;
public:
    DynamicArray!ASTNode children;
    Attribute[] attributes;
    ASTNode parent;
    int line   = -1;
    int column = -1;
    int nid;
    int modIteration;   /// Set to the current resolver iteration when node is modified in some way

    this() {
        children = new DynamicArray!ASTNode;
    }

/// Override these
    abstract NodeID id() const;
    abstract bool isResolved() { return false; }
    Type getType()             { return TYPE_UNKNOWN; }
/// end

    final bool hasChildren() const { return children.length > 0; }
    final int numChildren() const { return cast(int)children.length; }

    final void setModified(int iteration) {
        modIteration = iteration;
        if(parent) parent.setModified(iteration);
    }

    Module getModule() {
        if(!module_) {
            module_ = findModule();
        }
        return module_;
    }
    final int getDepth() {
        if(this.id==NodeID.MODULE) return 0;
        return parent.getDepth() + 1;
    }
    final ASTNode getParentIgnoreComposite() {
        if(parent.isComposite) return parent.getParentIgnoreComposite();
        return parent;
    }
    final bool isAttached() {
        if(this.isModule) return true;
        if(parent is null) return false;
        return parent.isAttached();
    }

    final auto addToFront(ASTNode child) {
        child.detach();
        children.insertAt(0, child);
        child.parent = this;
        return this;
    }
    final auto add(ASTNode child) {
        child.detach();
        children.add(child);
        child.parent = this;
        return this;
    }

    final void insertAt(int index, ASTNode child) {
        child.detach();
        children.insertAt(index, child);
        child.parent = this;
    }
    final void remove(ASTNode child) {
        children.remove(child);
        child.parent = null;
    }
    final void removeAt(int index) {
        auto child = children.removeAt(index);
        child.parent = null;
    }
    final void removeLast() {
        assert(children.length>0);
        auto child = children.removeAt(children.length.toInt-1);
        child.parent = null;
    }
    final void replaceChild(ASTNode child, ASTNode otherChild) {
        int i = indexOf(child);
        assert(i>=0, "This is not my child");

        children[i]       = otherChild;
        child.parent      = null;
        otherChild.parent = this;
    }
    final int indexOf(ASTNode child) {
        /// Do the happy path first, assuming child is an immediate descendent
        foreach(i, ch; children[]) {
            if(ch is child) return i.toInt;
        }
        /// Do the slower version looking at all descendents
        foreach(i, ch; children[]) {
            if(ch.hasDescendent(child)) return i.toInt;
        }
        return -1;
    }
    final ASTNode first() {
        if(children.length == 0) return null;
        return children[0];
    }
    final ASTNode second() {
        if(children.length<2) return null;
        return children[1];
    }
    final ASTNode last() {
        if(children.length == 0) return null;
        return children[$-1];
    }
    final void detach() {
        if(parent) {
            parent.remove(this);
        }
    }
    final int index() {
        if(parent) {
            return parent.indexOf(this);
        }
        return -1;
    }
    //=================================================================================
    final ASTNode previous() {
        int i = index();
        if(i<1) return parent;
        return parent.children[i-1];
    }
    final ASTNode prevSibling() {
        int i = index();
        if(i<1) return null;
        return parent.children[i-1];
    }
    final ASTNode[] prevSiblings() {
        int i = index();
        if(i<1) return [];
        return parent.children[0..i];
    }
    final ASTNode[] prevSiblingsAndMe() {
        int i = index();
        if(i<0) return [];
        return parent.children[0..i+1];
    }
    final ASTNode[] allSiblings() {
        return parent.children[].filter!(it=>it !is this).array;
    }
    ///
    /// Return the root node ie. the node whose parent is Module
    ///
    final ASTNode getRoot() {
        assert(this.id!=NodeID.MODULE);
        if(this.parent.id==NodeID.MODULE) return this;
        return parent.getRoot();
    }
    //================================================================================= Dump
    final void dumpToConsole(string indent="") {
        //dd(this.id);
        dd("[% 4s] %s".format(this.line+1, indent ~ this.toString()));
        foreach(ch; this.children) {
            ch.dumpToConsole(indent ~ "   ");
        }
    }
    final void dump(FileLogger l, string indent="") {
        //debug if(getModule.canonicalName=="test") dd(this.id, "line", line);
        l.log("[% 4s] %s", this.line+1, indent ~ this.toString());
        foreach(ch; children) {
            ch.dump(l, indent ~ "   ");
        }
    }
    //=================================================================================
    final Container getContainer() inout {
        auto c = cast(Container)parent;
        if(c) return c;
        if(parent) return parent.getContainer();
        throw new Exception("We are not inside a container!!");
    }
    final bool hasAncestor(T)() {
        if(parent is null) return false;
        if(parent.isA!T) return true;
        return parent.hasAncestor!T;
    }
    final T getAncestor(T)() {
        if(parent is null) return null;
        if(parent.isA!T) return parent.as!T;
        return parent.getAncestor!T;
    }
    final bool isDescendentOf(ASTNode n) {
        auto p = this.parent;
        while(p && (p !is n)) {
            p = p.parent;
        }
        return p !is null;
    }
    final bool hasDescendent(T)() {
        auto d = cast(T)this;
        if(d) return true;
        foreach(ch; children) {
            if(ch.hasDescendent!T) return true;
        }
        return false;
    }
    /// true if d is our descendent
    final bool hasDescendent(ASTNode d) {
        foreach(ch; children) {
            if(ch is d) return true;
            bool r = ch.hasDescendent(d);
            if(r) return true;
        }
        return false;
    }
    final T getDescendent(T)() {
        auto d = cast(T)this;
        if(d) return d;
        foreach(ch; children) {
            d = ch.getDescendent!T;
            if(d) return d;
        }
        return null;
    }
    ///
    /// Return a list of all descendents that are of type T.
    ///
    final void selectDescendents(T)(DynamicArray!T array) {
        auto t = cast(T)this;
        if(t) array.add(t);

        foreach(ch; children) {
            ch.selectDescendents!T(array);
        }
    }
    ///
    /// Collect all nodes where filter returns true, recursively.
    ///
    final void recursiveCollect(DynamicArray!ASTNode array, bool delegate(ASTNode n) filter) {
        if(filter(this)) array.add(this);
        foreach(n; children) {
            n.recursiveCollect(array, filter);
        }
    }
    final void recursiveCollect(T)(DynamicArray!T array, bool delegate(T n) filter) {
        T t = this.as!T;
        if(t && filter(t)) array.add(t);
        foreach(n; children) {
            n.recursiveCollect!T(array, filter);
        }
    }
    final void recurse(T)(void delegate(T n) functor) {
        if(this.isA!T) functor(this.as!T);
        foreach(n; children) {
            n.recurse!T(functor);
        }
    }
    final void recurse(T)(void delegate(int level, T n) functor, int level = 0) {
        if(this.isA!T) functor(level, this.as!T);
        foreach(n; children) {
            n.recurse!T(functor, level+1);
        }
    }
    final void collectTargets(ref Target[] targets) {

        if(this.isIdentifier) {
            targets ~= this.as!Identifier.target;
        } else if(this.isCall) {
            targets ~= this.as!Call.target;
        }
        foreach(ch; children[]) {
            ch.collectTargets(targets);
        }
    }
    //===================================================================================
    final override size_t toHash() const @trusted {
        assert(nid!=0);
        return nid;
    }
    /// Every node is unique
    final override bool opEquals(Object o) const {
        ASTNode foo = cast(ASTNode)o;
        assert(nid && foo.nid);
        return foo && foo.nid==nid;
    }
    override int opCmp(Object o) const {
        ASTNode other = cast(ASTNode)o;
        return nid==other.nid ? 0 :
               nid < other.nid ? -1 : 1;
    }
private:
    Module findModule() {
        if(this.isA!Module) return this.as!Module;
        if(parent) return parent.findModule();
        throw new Exception("We are not attached to a module!!");
    }
}
