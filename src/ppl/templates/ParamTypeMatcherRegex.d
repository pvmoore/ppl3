module ppl.templates.ParamTypeMatcherRegex;
///
/// Match a template function using regex.
/// eg.
///     call     func   ( int[2] )
///     template func<A>( A  [2] )
///     regex pattern =  (.*)\[2\] => this matches with the capture being "int"
///
/// The captures are converted to types and used as the template parameters.
///
import ppl.internal;
import std.regex;

final class ParamTypeMatcherRegex {
private:
    Module module_;
    Call call;
    Function func;
    string[] proxies;
    Type[string] hash;
    StringBuffer buf, buf2;
    Lexer lexer;
    bool doChat;
public:
    this(Module module_) {
        this.module_ = module_;
        this.lexer   = new Lexer(module_);
        this.buf     = new StringBuffer;
        this.buf2    = new StringBuffer;
    }
    bool getEstimatedParams(Call call, Function f, ref Type[] estimatedParams) {
        assert(estimatedParams.length==0);

        //doChat = call.name=="foo0" && module_.canonicalName=="template_functions";

        this.call    = call;
        this.func    = f;
        this.proxies = f.blueprint.paramNames;
        this.hash.clear();

        chat("====> ParamTypeMatcherRegex for %s(%s) => template %s<%s>(%s)",
            f.name,
            call.argTypes.toString,
            f.name,
            f.blueprint.paramNames.toString(),
            f.blueprint.getParamTokens().getTokensForAllParams().map!(it=>it.toSimpleString));

        auto paramTokens = f.blueprint.getParamTokens();

        foreach(i, callType; call.argTypes) {
            matchArg(paramTokens, i.as!int, callType);
        }

        if(hash.length==f.blueprint.numTemplateParams) {
            chat("Hash = %s", hash);
            estimatedParams = new Type[proxies.length];

            for(auto n=0; n<estimatedParams.length; n++) {
                auto t = hash.get(proxies[n], TYPE_VOID);

                estimatedParams[n] = t;
            }
            bool result = checkEstimate(f, estimatedParams);
            chat("Match: %s<%s> --> %s", f.name, estimatedParams.toString(), result ? "Pass" : "Fail");
            return result;
        }
        chat("No match");
        return false;
    }
private:
    void chat(A...)(lazy string fmt, lazy A args) {
        if(doChat) {
            dd(format(fmt, args));
        }
    }
    void addToHash(string proxy, Type type) {
        import common : containsKey;

        if(hash.containsKey(proxy)) {
            Type old = hash[proxy];
            if(areCompatible(old, type)) {
                hash[proxy] = getBestFit(old, type);
            } else {
                hash[proxy] = type;
            }
        } else {
            hash[proxy] = type;
        }
    }
    bool checkEstimate(Function f, Type[] estimatedParams) {
        Type[] paramTypes = f.blueprint.getFuncParamTypes(module_, call, estimatedParams);
        Type[] argTypes   = call.argTypes;
        chat("  argTypes   = %s", argTypes);
        chat("  paramTypes = %s", paramTypes);

        foreach(i; 0..paramTypes.length) {
            if(paramTypes[i].isAlias) {
                // assume this will work
            } else if(argTypes[i].canImplicitlyCastTo(paramTypes[i])) {
                // this one is good
            } else {
                return false;
            }
        }
        return true;
    }
    Type getType(string str) {
        auto tokens = lexer.tokenise!true(str);
        chat("\t\ttype tokens = %s", tokens.toSimpleString());
        auto nav = new Tokens(null, tokens);
        return module_.typeParser.parseForTemplate(nav, call);
    }
    ///
    /// Check template parameter tokens against call type.
    ///
    void matchArg(ParamTokens paramTokens, int argIndex, Type callType) {
        chat("Arg %s", argIndex);
        if(!paramTokens.paramContainsProxies(argIndex)) {
            chat("No proxies");
            return;
        }

        Token[] tokens     = paramTokens.getTokensForParam(argIndex);
        string typeString  = "%s".format(callType);

        auto rx = paramTokens.getRegexForParam(argIndex);
        string[] proxyList = paramTokens.getProxiesForParam(argIndex);

        chat("tokens : %s", tokens.toSimpleString);
        chat("proxies: %s", proxyList);
        chat("regex  : %s", paramTokens.getRegexStringForParam(argIndex));
        chat("type   : %s", typeString);
        chat("--------------------------");

        auto m = matchAll(typeString, rx);
        if(m.empty) {
            chat("\t\tNo match");
        } else {
            chat("\t\tMatch: %s", m.front[0]);
            int i = 0;
            foreach(r; m.front) {
                if(i>0) {
                    auto type = getType(r);
                    chat("\t\t[%s] %s = %s (type = %s)", i-1, proxyList[i-1], r, type);

                    addToHash(proxyList[i-1], type);
                }
                i++;
            }
        }
    }
}