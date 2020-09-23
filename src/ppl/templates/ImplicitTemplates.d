module ppl.templates.ImplicitTemplates;

import ppl.internal;
import common : contains;

final class ImplicitTemplates {
private:
    Module module_;
    Tokens nav;
    ParamTypeMatcherRegex typeMatcherRegex;
    ResolveIdentifier identifierResolver;
    bool doChat;
public:
    this(Module module_) {
        this.module_            = module_;
        this.nav                = new Tokens(module_, null);
        this.typeMatcherRegex   = new ParamTypeMatcherRegex(module_);
        this.identifierResolver = new ResolveIdentifier(module_);
    }
    bool find(Struct ns, Call call, DynamicArray!Function templateFuncs) {
        //doChat = call.name=="__nullCheck";// && module_.canonicalName=="test_optional";

        chat("================== Get implicit function templates for call %s(%s)",
            call.name, call.argTypes.toString());

        /// Exit if call is already templated or there are no non-this args
        if(call.name.contains("<")) return false;
        if(call.numArgs==0) return false;
        if(call.implicitThisArgAdded && call.numArgs==1) return false;

        /// The call has at least 1 arg that we can use to match to a template param type

        auto matchingParams = appender!(Type[][]);
        auto matchingFuncs  = appender!(Function[]);


        foreach(f; templateFuncs) {
            if(f.blueprint.numFuncParams == call.numArgs) {
                chat("  Trying template %s", f);

                Type[] templateTypes;

                if(typeMatcherRegex.getEstimatedParams(call, f, templateTypes)) {
                    chat("   MATCH <%s>", templateTypes.toString());

                    matchingParams ~= templateTypes;
                    matchingFuncs  ~= f;
                }
            }
        }

        if(matchingParams.data.length > 1) {
            /// Found multiple matches
            module_.buildState.addError(new AmbiguousCall(module_, call, matchingFuncs.data, matchingParams.data), true);
            return false;
        } else if(matchingParams.data.length==1) {
            /// Found a single match.
            /// Set the template types on the call
            call.templateTypes = matchingParams.data[0];
            return true;
        }

        /// No matches
        return false;
    }
private:
    void chat(A...)(lazy string fmt, lazy A args) {
        if(doChat) {
            dd(format(fmt, args));
        }
    }
}