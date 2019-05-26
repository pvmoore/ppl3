module ppl.ast.Module;

import ppl.internal;

final class Module : ASTNode, Container {
private:
    int tempCounter;
    Lambda[] lambdas;
    LiteralString[][string] literalStrings;
    Set!ASTNode activeRoots;  /// Active root nodes
public:
    string canonicalName;
    string fileName;
    string fullPath;
    bool isMainModule;        /// true if this module contains the 'main' function

    int numRefs;

    Config config;
    BuildState buildState;
    ParseModule parser;

    ResolveModule resolver;
    CheckModule checker;
    DeadCodeEliminator dce;
    GenerateModule gen;
    Templates templates;

    ParseAttribute attrParser;
    ParseStatement stmtParser;
    ParseExpression exprParser;
    ParseFunction funcParser;
    ParseType typeParser;
    DetectType typeDetector;
    ParseStruct structParser;
    ParseVariable varParser;
    ParseLiteral literalParser;

    NodeBuilder nodeBuilder;
    TypeFinder typeFinder;

    /// Generation properties
    LLVMModule llvmValue;
    LiteralString moduleNameLiteral;

    this(string canonicalName, LLVMWrapper llvmWrapper, BuildState buildState) {
        import std.array : replace;

        this.nid               = g_nodeid++;
        this.canonicalName     = canonicalName;
        this.buildState        = buildState;
        this.config            = buildState.config;
        this.fileName          = canonicalName.replace("::", ".");
        this.fullPath          = config.getFullModulePath(canonicalName);

        log("Creating new Module(%s)", canonicalName);

        parser            = new ParseModule(this);
        resolver          = new ResolveModule(this);
        checker           = new CheckModule(this);
        dce               = new DeadCodeEliminator(this);
        gen               = new GenerateModule(this, llvmWrapper);
        templates         = new Templates(this);
        activeRoots       = new Set!ASTNode;

        attrParser        = new ParseAttribute(this);
        stmtParser        = new ParseStatement(this);
        exprParser        = new ParseExpression(this);
        funcParser        = new ParseFunction(this);
        typeParser        = new ParseType(this);
        typeDetector      = new DetectType(this);
        structParser      = new ParseStruct(this);
        varParser         = new ParseVariable(this);
        nodeBuilder       = new NodeBuilder(this);
        typeFinder        = new TypeFinder(this);
        literalParser     = new ParseLiteral(this);

        moduleNameLiteral = makeNode!LiteralString(this);
        moduleNameLiteral.value = canonicalName;
        addLiteralString(moduleNameLiteral);
    }
    void clearState() {
        lambdas = null;
        literalStrings.clear();
        activeRoots.clear();
        children.clear();
        numRefs = 0;
        tempCounter = 0;

        parser.clearState();
        resolver.clearState();
        checker.clearState();
        dce.clearState();
        gen.clearState();
        templates.clearState();
        llvmValue = null;

        addLiteralString(moduleNameLiteral);
    }
/// ASTNode
    override bool isResolved()  { return true; }
    override NodeID id() const  { return NodeID.MODULE; }
    override Module getModule() { return this; }
    override Type getType()     { return TYPE_VOID; }
///

    bool isParsed() { return parser.isParsed; }

    /// Order of construction. Lower priorities get constructed first.
    int getPriority() {
        auto attr = attributes.get!ModuleAttribute;
        if(attr) return attr.priority;
        if(this is buildState.mainModule) return 0;
        return 10000+nid;
    }

    auto getLiteralStrings()               { return literalStrings.values; }
    void addLiteralString(LiteralString s) { literalStrings[s.value] ~= s; }

    Lambda[] getLambdas()       { return lambdas; }
    void addLambda(Lambda c)    { lambdas ~= c; }
    void removeLambda(Lambda c) { import common : remove; lambdas.remove(c); }

    auto getCopyOfActiveRoots()      { return activeRoots.values.dup; }
    void addActiveRoot(ASTNode node) { activeRoots.add(node.getRoot); }
    bool isActive(ASTNode node) {
        auto root = node.getRoot();
        return root && activeRoots.contains(root);
    }

    NodeBuilder builder(ASTNode n) {
        return nodeBuilder.forNode(n);
    }

    void addError(ASTNode node, string msg, bool canContinue) {
        buildState.addError(new ParseError(this, node, msg), canContinue);
    }
    void addError(Tokens t, string msg, bool canContinue) {
        buildState.addError(new ParseError(this, t, msg), canContinue);
    }
    void addError(CompileError err, bool canContinue) {
        buildState.addError(err, canContinue);
    }

    string makeTemporary(string prefix) {
        return "__%s%s".format(prefix, tempCounter++);
    }
    ///
    /// Return the module init function.
    ///
    Function getInitFunction() {
        return getFunctions("new")[0];
    }
    ///
    /// Find an Alias at the module scope.
    ///
    Alias getAlias(string name) {
        return getAliases()
            .filter!(it=>it.name==name)
            .frontOrNull!Alias;
    }
    Alias[] getAliases() {
        return children[]
            .filter!(it=>it.isAlias)
            .map!(it=>cast(Alias)it)
            .array;
    }
    Enum getEnum(string name) {
        return getEnums()
            .filter!(it=>it.name==name)
            .frontOrNull!Enum;
    }
    Enum[] getEnums() {
        return children[]
            .filter!(it=>it.isA!Enum)
            .map!(it=>cast(Enum)it)
            .array;
    }
    Enum[] getEnumsRecurse() {
        auto array = new DynamicArray!Enum;
        selectDescendents!Enum(array);
        return array[];
    }
    Struct getStruct(string name) {
        return getStructs()
            .filter!(it=>it.name==name)
            .frontOrNull!Struct;
    }
    Struct[] getStructs() {
        return children[]
            .filter!(it=>it.id==NodeID.STRUCT)
            .map!(it=>cast(Struct)it)
            .array;
    }
    Struct[] getStructsRecurse() {
        auto array = new DynamicArray!Struct;
        selectDescendents!Struct(array);
        return array[];
    }
    ///
    /// Find all functions with given name at module scope.
    ///
    Function[] getFunctions(string name) {
        return getFunctions()
            .filter!(it=>it.name==name)
            .array;
    }
    ///
    /// Find all functions at module scope.
    ///
    Function[] getFunctions() {
        return children[]
            .filter!(it=>it.id()==NodeID.FUNCTION)
            .map!(it=>cast(Function)it)
            .array;
    }
    ///
    /// Find all Variables at module scope.
    ///
    Variable[] getVariables() {
        return children[]
            .filter!(it=>it.id()==NodeID.VARIABLE)
            .map!(it=>cast(Variable)it)
            .array;
    }
    //================================================================================
    Struct[] getImportedStructs() {
        Struct[string] structs;

        recurse((ASTNode it) {
            auto ns = it.getType.getStruct;
            if(ns && ns.getModule.nid!=nid) {
                structs[ns.name] = ns;
            }
        });

        return structs.values;
    }
    Enum[] getImportedEnums() {
        Enum[string] enums;

        recurse((ASTNode it) {
            auto e = it.getType.getEnum;
            if(e && e.getModule.nid!=nid) {
                enums[e.name] = e;
            }
        });

        return enums.values;
    }
    Function[] getImportedFunctions() {
        auto array = new DynamicArray!ASTNode;
        recursiveCollect(array,
            it=> it.id()==NodeID.CALL &&
                 it.as!Call.target.isFunction() &&
                 it.as!Call.target.targetModule.nid != nid
        );
        /// De-dup
        auto set = new Set!Function;
        foreach(call; array) {
            set.add(call.as!Call.target.getFunction());
        }
        return set.values;
    }
    ///
    /// Find and return all variables defined in other modules.
    /// These should all be non-private statics.
    ///
    Variable[] getImportedStaticVariables() {
        auto array = new DynamicArray!ASTNode;
        recursiveCollect(array, it=>
            it.id()==NodeID.IDENTIFIER &&
            it.as!Identifier.target.isVariable() &&
            it.as!Identifier.target.targetModule.nid != nid &&
            it.as!Identifier.target.getVariable().isStatic
        );
        /// De-dup
        auto set = new Set!Variable;
        foreach(v; array) {
            set.add(v.as!Identifier.target.getVariable());
        }
        return set.values;
    }

    ///
    /// Return a list of all modules referenced from this module
    ///
    Module[] getReferencedModules() {
        auto m = new Set!Module;
        foreach(ns; getImportedStructs()) {
            m.add(ns.getModule);
        }
        foreach(e; getImportedEnums()) {
            m.add(e.getModule);
        }
        foreach(v; getImportedStaticVariables()) {
            m.add(v.getModule);
        }
        foreach(f; getImportedFunctions()) {
            m.add(f.getModule);
        }
        m.remove(this);
        return m.values;
    }

    override int opCmp(Object o) const {
        import std.algorithm.comparison;
        Module other = cast(Module)o;
        return nid==other.nid ? 0 :
               cmp(canonicalName, other.canonicalName);
    }
    override string toString() const {
        return "Module[refs=%s] %s".format(numRefs, canonicalName);
    }
}