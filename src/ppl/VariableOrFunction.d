module ppl.VariableOrFunction;

import ppl.internal;

interface VariableOrFunction {}

// static struct VariableOrFunction {
//     union {
//         Variable var;
//         Function func;
//     }
//     bool found() { return var !is null; }
// }