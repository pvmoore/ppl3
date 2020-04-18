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
    BuildState state;
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
    Set!string publicFunctions;

    Set!string classes;
    Set!string structs;

    ulong getElapsedNanos()   { return watch.peek().total!"nsecs"; }
    Tokens getInitialTokens() { return mainTokens; }
    auto getSourceTextHash()  { return sourceTextHash; }
    bool isParsed()           { return mainParseComplete && templateParseComplete; }

    this(Module module_) {
        this.module_          = module_;
        this.state            = module_.buildState;
        this.lexer            = new Lexer(module_);
        this.publicTypes      = new Set!string;
        this.classes          = new Set!string;
        this.structs          = new Set!string;
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
        state.logParse("Parser: %s src -> %s bytes hash:%s", module_.fullPath, sourceText.length, sourceTextHash);

        tokenise();
        collectTypesAndFunctions();

        // Set Module endPos
        Token last = mainTokens.peek(mainTokens.length()-1);
        if(last != NO_TOKEN) {
            module_.endPos = last.end;
        }
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

        state.logParse("[%s] Parsing", module_.canonicalName);

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

        state.logParse("[%s] Parsing finished", module_.canonicalName);
        moduleFullyParsed();

        mainParseComplete     = true;
        templateParseComplete = true;
        watch.stop();
    }
    void appendTokensFromTemplate(ASTNode afterNode, Token[] tokens) {
        auto t = new Tokens(module_, tokens);
        t.isTemplateExpansion = true;

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
        state.logParse("... found %s tokens", tokens.length);

        lexer.dumpTokens(tokens);

        this.mainTokens = new Tokens(module_, tokens);
        watch.stop();
    }
    ///
    /// Look for module scope functions, aliases and structs
    ///
    void collectTypesAndFunctions() {
        watch.start();
        state.logParse("Parser: %s Extracting exports", module_.canonicalName);

        auto t = mainTokens;

        bool isStruct() {
            return t.isKeyword("struct");
        }
        bool isClass() {
            return t.isKeyword("class");
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

                if(isStruct()) {
                    t.next;
                    structs.add(t.value);
                    publicTypes.add(t.value);
                } else if(isClass()) {
                    t.next;
                    classes.add(t.value);
                    publicTypes.add(t.value);
                } else if(isAlias() || isEnum()) {
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
            } else {
                // Check for private types

                if(isStruct()) {
                    t.next;
                    structs.add(t.value);
                } else if(isClass()) {
                    t.next;
                    classes.add(t.value);
                }
            }
            t.next;
        }

        //if(module_.canonicalName=="imports::imports") dd("publicTypes", publicTypes.values);

        t.reset();
        watch.stop();
    }
    Token[] getImplicitImportsTokens() {
        auto tokens = appender!(Token[]);

        Token tok(string value) {
            return Token.make(TT.IDENTIFIER, value, 0, INVALID_POSITION, INVALID_POSITION);
        }

        __gshared static string[] IMPORTS = [
            "core::c",
            "core::memory",
            "core::core",
            "core::assert",
            "core::string",
            "core::unsigned",
            "core::sequence",


            "std::optional",
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
    ///     - Create one if there are none.
    ///  - For main module:
    ///     - Check that we have a program entry point
    ///     - Add __runModuleConstructors function and call it
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
        if(hasModuleInit==false) {
            addModuleInitFunction();
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
    }
    void addModuleInitFunction() {
        auto initFunc = makeNode!Function;
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
    /**
     *  Rename main function to __user_main
     *  Add main {void->int} function that calls __user_main
     *  Add __runModuleConstructors function to module
     *  Call __runModuleConstructors
     *
     *  See https://docs.microsoft.com/en-us/cpp/build/reference/entry-entry-point-symbol?view=vs-2017
     */
    void addRealProgramEntry(Function main) {
        auto b = module_.nodeBuilder;

        /// Rename "main"/"WinMain" to "__user_main"
        main.name = "__user_main";

        bool mainReturnsAnInt = main.getBody().getReturns().any!(it=>it.hasExpr);
        Type gc = module_.typeFinder.findType("GC", main);

        /// Create a new "main"/"WinMain" function
        auto func = b.function_(module_.config.getEntryFunctionName());

        /// Add GC.start()
        auto callGCStart = b.dot(b.typeExpr(gc), b.call("start"));

        /// Create __runModuleConstructors function
        auto rmcFunc = b.function_("__runModuleConstructors");
        rmcFunc.access = Access.PUBLIC;
        rmcFunc.getBody().add(b.returnVoid());
        module_.add(rmcFunc);

        /// Call __runModuleConstructors
        auto callRMC = b.call("__runModuleConstructors");

        /// Exit code
        auto allocStatusCodeVar = b.variable("__exitCode", TYPE_INT);
        auto returnStatusCode = b.return_(b.identifier("__exitCode"));

        /// Call main
        Expression callUserMain = b.call("__user_main");

        if(mainReturnsAnInt) {
            callUserMain = b.assign(b.identifier("__exitCode"), callUserMain, TYPE_INT);
        }

        /// Add GC.stop()
        auto callGCStop = b.dot(b.typeExpr(gc), b.call("stop"));

        func.getBody().add(callGCStart);
        func.getBody().add(callRMC);
        func.getBody().add(allocStatusCodeVar);
        func.getBody().add(callUserMain);
        func.getBody().add(callGCStop);
        func.getBody().add(returnStatusCode);

        func.numRefs++;
        module_.add(func);
        module_.buildState.moduleRequired(module_.canonicalName);
    }
}