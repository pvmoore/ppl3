
struct A

pub fn testClosures() {
    A a = A()
    a.foo()

    int hello = 1

    // fn(bool)void
    const closure0 = |bool a| {}

    const lambda = || {}

    const closure1 = |int a| {
        // this     // nope
        // hello    // nope
        return 2
    }
    const closure2 = |int a| {
        return 3
    }
    fn(int return int) funcptr  = closure2
    fn(int return int) funcptr2 = closure2

    assert 2 == closure1(1)
    assert 3 == closure2(1)
    assert 3 == funcptr(1)
}
struct A(pub int member = 1) {
    pub fn foo() {
        assert @typeOf(this) is A*
        int hello = 1
        this.member

        const closure1 = |int a| {
            // this     // nope
            // hello    // nope
            // member   // nope
            return 1
        }
        fn(return int) closure2 = || {
            return 2
        }
        assert 1 == closure1(1)
        assert 2 == closure2()

        assert @typeOf(closure1) is fn(int return int)
        assert @typeOf(closure2) is fn(return int)
    }
}
