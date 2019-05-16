module ppl.ppl3;

import ppl.internal;

final class PPL3 {
    static shared PPL3 _instance;
    this() {}
public:
    static auto instance() {
        auto i = cast(PPL3)atomicLoad(_instance);
        if(!i) {
            i = new PPL3;
            atomicStore(_instance, cast(shared)i);
        }
        return i;
    }
    ProjectBuilder createProjectBuilder(Config config) {
        return new ProjectBuilder(g_llvmWrapper, config);
    }
}
