module ppl.templates.ImplicitTemplates;

import ppl.internal;
import common : contains;

final class ImplicitTemplates {
private:
    Module module_;
    Tokens nav;
    ParamTypeMatcherRegex typeMatcherRegex;
    ResolveIdentifier identifierResolver;
public:
    this(Module module_) {
        this.module_            = module_;
        this.nav                = new Tokens(module_, null);
        this.typeMatcherRegex   = new ParamTypeMatcherRegex(module_);
        this.identifierResolver = new ResolveIdentifier(module_);
    }
    bool find(Struct ns, Call call, DynamicArray!Function templateFuncs) {
        //dd("================== Get implicit function templates for call", call.name, "(", call.argTypes,")");

        /// Exit if call is already templated or there are no non-this args
        if(call.name.contains("<")) return false;
        if(call.numArgs==0) return false;
        if(call.implicitThisArgAdded && call.numArgs==1) return false;

        /// The call has at least 1 arg that we can use to match to a template param type

        auto matchingParams = appender!(Type[][]);
        auto matchingFuncs  = appender!(Function[]);

        foreach(f; templateFuncs) {
            if(f.blueprint.numFuncParams == call.numArgs) {

                Type[] templateTypes;

                if(typeMatcherRegex.getEstimatedParams(call, f, templateTypes)) {
                    //dd("   MATCH", "<", templateTypes.prettyString, ">");

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
}