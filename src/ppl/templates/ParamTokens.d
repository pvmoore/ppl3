module ppl.templates.ParamTokens;

import ppl.internal;
import std.regex;

final class ParamTokens {
private:
    Token[][] paramTokens;
    Set!string proxyNames;

    Regex!char[] regexes;
    string[] regexStrings;
    string[][] proxyLists;
public:
    int numParams;

    this(Struct ns, string[] proxyNames, Token[] tokens) {
        this.proxyNames = new Set!string;
        this.proxyNames.add(proxyNames);

        extractParams(ns, tokens);
    }

    bool paramContainsProxies(int paramIndex) {
        return proxyLists[paramIndex].length > 0;
    }
    Token[][] getTokensForAllParams() {
         return paramTokens;
    }
    Token[] getTokensForParam(int paramIndex) {
        return paramTokens[paramIndex];
    }
    auto getRegexForParam(int paramIndex) {
        return regexes[paramIndex];
    }
    string getRegexStringForParam(int paramIndex) {
        return regexStrings[paramIndex];
    }
    string[] getProxiesForParam(int paramIndex) {
        return proxyLists[paramIndex];
    }
private:
    void extractParams(Struct ns, Token[] tokens) {
        assert(tokens.length>0);
        assert(tokens[0].type==TT.LBRACKET);
        assert(tokens[$-1].type==TT.RCURLY);

        /// Add this* as first parameter if this is a struct function template
        if(ns) {
            this.paramTokens ~= [
                tokens[0].copy("__this*", Pointer.of(ns, 1)),
                tokens[0].copy("this")
            ];
            regexes      ~= regex("");
            regexStrings ~= "";
            proxyLists   ~= cast(string[])null;
        }

        auto nav = new Tokens(null, tokens);
        nav.next;

        int end = nav.findInScope(TT.RBRACKET);
        assert(end!=-1);

        nav.setLength(nav.index+end);

        int start = nav.index;


        auto reg  = new StringBuffer;
        string[] proxiesFound;

        void addParam() {
            this.paramTokens  ~= nav[start..nav.index];
            this.proxyLists   ~= proxiesFound.dup;
            this.regexStrings ~= reg.toString();
            this.regexes      ~= regex(regexStrings[$-1]);

            proxiesFound.length = 0;
            reg.clear();

            //dd("param  = ", paramTokens[$-1].toSimpleString);
            //dd("proxies= ", proxyLists[$-1]);
            //dd("regex  = ", regexStrings[$-1]);
        }

        bool flag = true;
        int br = 0, sq = 0, angle = 0;

        while(nav.hasNext) {
            bool endOfParam = br==0 && sq==0 && angle==0;

            if(nav.type==TT.IDENTIFIER) {
                if(nav.value=="return" && endOfParam) {
                    // end of param
                    addParam();
                    start = nav.index;
                    break;
                } else if(nav.value=="return") {
                    reg ~= " return ";
                    flag = true;
                } else if(flag) {
                    if(proxyNames.contains(nav.value)) {
                        reg          ~= "(.*)";
                        proxiesFound ~= nav.value;
                    } else {
                        reg ~= nav.value;
                    }
                    flag = false;
                }
                nav.next;
            } else {

                if(nav.type==TT.COMMA && endOfParam) {
                    /// end of param
                    addParam();
                    nav.next;
                    start = nav.index;
                    flag  = true;
                } else {
                    reg ~= escapeRegex(toSimpleString(nav.get));

                    switch(nav.type) {
                        case TT.LSQBRACKET: sq++;    flag = true;  break;
                        case TT.RSQBRACKET: sq--;    flag = false; break;
                        case TT.LANGLE:     angle++; flag = true;  break;
                        case TT.RANGLE:     angle--; flag = false; break;
                        case TT.LBRACKET:   br++;    flag = true;  break;
                        case TT.RBRACKET:   br--;    flag = false; break;
                        case TT.COMMA:
                            flag = true;
                            break;
                        default: break;
                    }
                    nav.next;
                }
            }
        }
        if(start != nav.index) {
            addParam();
        }
        this.numParams = paramTokens.length.as!int;

        assert(proxyLists.length==numParams);
        assert(regexes.length==numParams);
        assert(regexStrings.length==numParams);

        //if(proxyNames.contains("X")) {
        //if(ns && ns.name=="M1") {
        //    dd("-->", proxyNames.values);
        //    dd("   -->", regexStrings);
        //}
        //}
    }
}