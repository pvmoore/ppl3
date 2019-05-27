module ppl.parse.ParseModule;

import ppl.internal;
///
/// 1) Read file contents
/// 2) Tokenise
/// 3) Extract exports
/// 4) Parse statements
///
final class ParseModule {
private:
    Module module_;
    StopWatch watch;
    Lexer lexer;

    Tokens mainTokens;
    Tokens[] templateTokens;
    ASTNode[] templateStartNodes;
    bool mainParseComplete;
    bool templateParseComplete;

    string sourceText;
    Hash!20 sourceTextHash;
public:
    Set!string publicTypes;
    //Set!string privateFunctions;
    Set!string publicFunctions;

    ulong getElapsedNanos()   { return watch.peek().total!"nsecs"; }
    Tokens getInitialTokens() { return mainTokens; }
    auto getSourceTextHash()  { return sourceTextHash; }
    bool isParsed()           { return mainParseComplete && templateParseComplete; }

    this(Module module_) {
        this.module_          = module_;
        this.lexer            = new Lexer(module_);
        this.publicTypes      = new Set!string;
        //this.privateFunctions = new Set!string;
        this.publicFunctions  = new Set!string;
    }
    void clearState() {
        publicFunctions.clear();
        //privateFunctions.clear();
        publicTypes.clear();
        mainParseComplete = false;
        templateParseComplete = false;
        templateTokens = null;
        templateStartNodes = null;
        module_.children.clear();
        sourceText = null;
        sourceTextHash.invalidate();
        watch.reset();
    }
    ///
    /// Set/reset the source text.
    ///
    void setSourceText(string src) {
        assert(false==From!"common".contains(src, "\t"));

        this.sourceTextHash = Hasher.sha1(src);
        this.sourceText     = src;
        log("Parser: %s src -> %s bytes hash:%s", module_.fullPath, sourceText.length, sourceTextHash);

        tokenise();
        collectTypesAndFunctions();
    }
    void readSourceFromDisk() {
        import std.file : read;
        setSourceText(convertTabsToSpaces(cast(string)read(module_.fullPath)));
    }
    ///
    /// Tokenise the contents and then start to parse the statements.
    /// Continue parsing until an import statement is found
    /// where the exports are not yet known.
    ///
    void parse() {
        if(isParsed()) return;
        watch.start();

        log("[%s] Parsing", module_.canonicalName);

        /// Parse all module tokens
        while(mainTokens.hasNext) {
            module_.stmtParser.parse(mainTokens, module_);
        }

        /// Parse subsequently added template tokens
        foreach(i, nav; templateTokens) {
            while(nav.hasNext()) {
                module_.stmtParser.parse(nav, templateStartNodes[i]);
            }
        }

        log("[%s] Parsing finished", module_.canonicalName);
        moduleFullyParsed();

        mainParseComplete     = true;
        templateParseComplete = true;
        watch.stop();
    }
    void appendTokensFromTemplate(ASTNode afterNode, Token[] tokens) {
        auto t = new Tokens(module_, tokens);
        this.templateTokens ~= t;
        if(afterNode.isFunction) {
            t.setAccess(afterNode.as!Function.access);
        } else {
            assert(afterNode.id==NodeID.STRUCT);
            t.setAccess(afterNode.as!Struct.access);
        }

        auto ph = makeNode!Placeholder(t);
        afterNode.parent.insertAt(afterNode.index, ph);

        this.templateStartNodes ~= ph;

        templateParseComplete = false;
        module_.resolver.setModified();
    }
private:
    void tokenise() {
        watch.start();
        auto tokens = getImplicitImportsTokens() ~ lexer.tokenise(sourceText, module_.buildState);
        log("... found %s tokens", tokens.length);
        lexer.dumpTokens(tokens);

        this.mainTokens = new Tokens(module_, tokens);
        watch.stop();
    }
    ///
    /// Look for module scope functions, aliases and structs
    ///
    void collectTypesAndFunctions() {
        watch.start();
        log("Parser: %s Extracting exports", module_.canonicalName);

        auto t = mainTokens;

        bool isStruct() {
            return t.isKeyword("struct");
        }
        bool isAlias() {
            return t.isKeyword("alias");
        }
        bool isEnum() {
            return t.isKeyword("enum");
        }
        /// Assumes isStruct() and isAlias() and isEnum() returned false
        bool isFuncDecl() {
            /// fn foo()
            /// extern fn foo()
            /// fn foo<T>()
            /// Don't match fn()type which is a variable decl

            if(t.isKeyword("extern")) return true;
            if(t.isKeyword("fn") && t.peek(1).type!=TT.LBRACKET) return true;

            return false;
        }

        while(t.hasNext) {
            if(t.isKeyword("pub")) {
                /// Public declaration found
                t.next;

                if(isStruct() || isAlias() || isEnum()) {
                    t.next;
                    publicTypes.add(t.value);
                } else if(isFuncDecl()) {
                    if(t.isKeyword("extern")) t.next;

                    if(t.value=="fn") {
                        t.next;
                        publicFunctions.add(t.value);
                    } else {
                        publicFunctions.add(t.value);
                    }
                }

            } else if(t.type==TT.LCURLY) {
                /// Skip {} block
                auto eob = t.findEndOfBlock(t.type);
                if(eob==-1) {
                    module_.addError(t, "Couldn't find matching bracket }", false);
                    break;
                }
                t.next(eob);
            } else if(t.type==TT.LSQBRACKET) {
                /// Skip [] block
                auto eob = t.findEndOfBlock(t.type);
                if(eob==-1) {
                    module_.addError(t, "Couldn't find matching bracket ]", false);
                    break;
                }
                t.next(eob);
            }
            t.next;
        }

        t.reset();
        watch.stop();
    }
    Token[] getImplicitImportsTokens() {
        auto tokens = appender!(Token[]);

        Token tok(string value) {
            Token t;
            t.type   = TT.IDENTIFIER;
            t.line   = 1;
            t.column = 1;
            t.value  = value;
            return t;
        }

        __gshared static string[] IMPORTS = [
            "core::c",
            "core::memory",
            "core::core",
            "core::assert",
            "core::string",
            "core::unsigned",

            "std::console",
            "std::List",
            "std::file",
            "std::StringBuffer"
        ];

        foreach(s; IMPORTS) {
            if(module_.canonicalName!=s) {
                tokens ~= tok("import");
                tokens ~= tok(s);
            }
        }

        return tokens.data;
    }
    ///
    ///  - Check that there is only 1 module init function.
    ///  - Create one if there are none.
    ///  - Check that we have a program entry point
    ///  - Request resolution of the module "new" method
    ///
    void moduleFullyParsed() {
        /// Only do this once
        if(mainParseComplete) return;

        /// Ensure no more than one module new() function exists
        auto fns = module_.getFunctions("new");
        if(fns.length>1) {
            module_.addError(fns[1], "Multiple module 'new' functions are not allowed", true);
        }
        bool hasModuleInit = fns.length==1;
        bool isMainModule  = module_.isMainModule;

        /// Add a module new() function if it does not exist
        Function initFunc;
        if(hasModuleInit) {
            initFunc = fns[0];
        } else {
            /// No module init function exists
            initFunc = makeNode!Function;
            initFunc.name       = "new";
            initFunc.moduleName = module_.canonicalName;
            module_.add(initFunc);

            auto params = makeNode!Parameters;
            auto type   = makeNode!FunctionType;
            type.params = params;
            auto lit    = makeNode!LiteralFunction;
            lit.add(params);
            lit.type = type;
            initFunc.add(lit);
        }

        if(isMainModule) {
            /// Check for a program entry point
            auto mainfns = module_.getFunctions(module_.config.getEntryFunctionName());

            if(mainfns.length > 1) {
                module_.addError(mainfns[1], "Multiple program entry points found", true);
            } else if(mainfns.length==0) {
                module_.addError(module_, "No program entry point found", true);
            } else {
                /// Add an external ref to the entry function
                mainfns[0].numRefs++;

                /// Add a ref to the main module
                module_.numRefs++;

                addRealProgramEntry(mainfns[0]);
            }
        }

        /// Request init function resolution
        module_.buildState.functionRequired(module_.canonicalName, "new");
    }
    ///
    /// Rename main function to __user_main
    /// Add main {void->int} function that calls __user_main
    ///
    /// See https://docs.microsoft.com/en-us/cpp/build/reference/entry-entry-point-symbol?view=vs-2017
    ///
    void addRealProgramEntry(Function main) {
        auto b = module_.builder(main);

        /// Rename "main"/"WinMain" to "__user_main"
        main.name = "__user_main";

        bool mainReturnsAnInt = main.getBody().getReturns().any!(it=>it.hasExpr);
        Type gc = module_.typeFinder.findType("GC", main);

        /// Create a new "main"/"WinMain" function
        auto func = b.function_(module_.config.getEntryFunctionName());

        /// Add GC.start()
        auto start = b.dot(b.typeExpr(gc), b.call("start"));

        /// Exit code
        auto retVar = b.variable("__exitCode", TYPE_INT);
        auto ret = b.return_(b.identifier("__exitCode"));

        /// Call main
        Expression call = b.call("__user_main");

        if(mainReturnsAnInt) {
            call = b.assign(b.identifier("__exitCode"), call, TYPE_INT);
        }

        /// Add GC.stop()
        auto stop = b.dot(b.typeExpr(gc), b.call("stop"));

        func.getBody().add(start);
        func.getBody().add(retVar);
        func.getBody().add(call);
        func.getBody().add(stop);
        func.getBody().add(ret);

        func.numRefs++;
        module_.add(func);
        module_.buildState.functionRequired(module_.canonicalName, "__user_main");
    }
}