module ppl.check.AfterSemantic;

import ppl.internal;

final class AfterSemantic {
private:
    BuildState state;
public:
    this(BuildState state) {
        this.state = state;
    }
    void process() {
        foreach(m; state.allModules) {

        }
    }
}