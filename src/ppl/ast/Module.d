module ppl.ast.Module;

import ppl.internal;

final class Module : ASTNode, Container {
private:
    int tempCounter;
    Lambda[] lambdas;
    LiteralString[][string] literalStrings;
    Set!string imports;
public:
    string canonicalName;
    string fileName;
    string fullPath;
    bool isMainModule;        /// true if this module contains the 'main' function

    int numRefs;

    bool afterResolutionHasRun = false; // this could be true if this module is part of a rebuild
                                        // and did was not modified
    Config config;
    BuildState buildState;
    ParseModule parser;

    ResolveModule resolver;
    CheckModule checker;
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
    IdentifierTargetFinder idTargetFinder;

    /// Generation properties
    LLVMModule llvmValue;
    LiteralString moduleNameLiteral;


    this(string canonicalName, LLVMWrapper llvmWrapper, BuildState buildState) {
        import std.array : replace;

        this.nid               = g_nodeid++;
        this.startPos          = Position(0,0);
        this.endPos            = Position(0,0);
        this.canonicalName     = canonicalName;
        this.buildState        = buildState;
        this.config            = buildState.config;
        this.fileName          = canonicalName.replace("::", ".");
        this.fullPath          = config.getFullModulePath(canonicalName);

        this.imports = new Set!string;

        parser            = new ParseModule(this);
        resolver          = new ResolveModule(this);
        checker           = new CheckModule(this);
        gen               = new GenerateModule(this, llvmWrapper);
        templates         = new Templates(this);

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
        idTargetFinder    = new IdentifierTargetFinder(this);
        literalParser     = new ParseLiteral(this);

        moduleNameLiteral = makeNode!LiteralString;
        moduleNameLiteral.value = canonicalName;
        addLiteralString(moduleNameLiteral);
    }
    void clearState() {
        lambdas = null;
        literalStrings.clear();
        children.clear();
        numRefs = 0;
        tempCounter = 0;

        imports.clear();
        parser.clearState();
        resolver.clearState();
        checker.clearState();
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

    void addImport(Import imp) { imports.add(imp.moduleName); }
    string[] getImports() { return imports.values; }

    Lambda[] getLambdas()       { return lambdas; }
    void addLambda(Lambda c)    { lambdas ~= c; }
    void removeLambda(Lambda c) { import common : remove; lambdas.remove(c); }

    void appendTokensFromTemplate(ASTNode afterNode, Token[] tokens) {
        parser.appendTokensFromTemplate(afterNode, tokens);
        resolver.setModified();
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
    Struct getStructOrClass(string name) {
        return getStructsAndClasses()
            .filter!(it=>it.name==name)
            .frontOrNull!Struct;
    }
    Struct[] getStructsAndClasses() {
        return children[]
            .filter!(it=>it.id==NodeID.STRUCT || it.id==NodeID.CLASS)
            .map!(it=>cast(Struct)it)
            .array;
    }
    Struct[] getStructsAndClassesRecurse() {
        auto array = new DynamicArray!Struct;
        selectDescendents!Struct(array);
        return array[];
    }
    bool hasFunction(string name) {
        return getFunctions().any!(it=>it.name==name);
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
    Struct[] getImportedStructsAndClasses() {
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
                 it.getCall().target.isFunction() &&
                 it.getCall().target.targetModule.nid != nid
        );
        /// De-dup
        auto set = new Set!Function;
        foreach(call; array) {
            set.add(call.getCall().target.getFunction());
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
            it.getIdentifier().target.isVariable() &&
            it.getIdentifier().target.targetModule.nid != nid &&
            it.getIdentifier().target.getVariable().isStatic
        );
        /// De-dup
        auto set = new Set!Variable;
        foreach(v; array) {
            set.add(v.getIdentifier().target.getVariable());
        }
        return set.values;
    }

    ///
    /// Return a list of all modules referenced from this module
    ///
    Module[] getReferencedModules() {
        auto m = new Set!Module;
        foreach(ns; getImportedStructsAndClasses()) {
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

    Statement[] getStatementsOnLine(int line) {
        Statement[] stmts;

        foreach(ch; children) {
            if(ch.line==line) stmts ~= ch.as!Statement;
        }

        return stmts;
    }
    /**
     *  Return one of Module, LiteralFunction, Tuple, Class or Struct whichever is the innermost.
     *  Always returns this module in the worst case.
     */
    Container getContainerAtPosition(Position pos) {

        Container con = this;

        recurse!Container((c) {
            if(c.containsPosition(pos)) {
                if(c.as!ASTNode.isDescendentOf(con.as!ASTNode)) {
                    con = c;
                }
            }
        });

        return con;
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