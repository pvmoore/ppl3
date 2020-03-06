
pub fn testExternalInnerStructs() {
    const testAccess = || {
        import structs::inner_structs
        // these are all pub structs
        A a
        A::B ab
        A::B::C abc
        A::B::C::D abcd

        TA<int> ta
        TA<float>::TB<int> tab
        TA<double>::TB<long>::TC<int> tabc
        TA<int>::TB<int>::TC<float>::TD<int> tabcd

        // this is a pub struct but a and b are private, c and d are pub
        const ae = A::E()
        //assert ae.a == 98     // private
        //assert A::E.b == 99   // private
        assert ae.c == 100      // pub
        assert A::E.d == 101    // pub

        //var af = A::F()       // A::F is private
        //var ago = A::G.ONE    // G is private

        // TA::TE is pub
        const te = TA<int>::TE<int>()
        assert te.a == 50                   // pub
        assert TA<int>::TE<int>.b == 51     // pub
        //assert te.c == 52                 // private
        //assert TA<int>::TE<int>.d == 52   // private
    }
    const testImportAlias = || {
        import imp = structs::inner_structs

        imp.A a
        imp.A::B ab
        imp.A::B::C abc
        imp.A::B::C::D abcd

        imp.TA<int> ta
        imp.TA<float>::TB<int> tab
        imp.TA<double>::TB<long>::TC<int> tabc
        imp.TA<int>::TB<int>::TC<float>::TD<int> tabcd

        alias AL = imp.A::B
        AL al = imp.A::B()

        //var af = imp.A::F()       // A::F is private
        //var ago = imp.A::G.ONE    // G is private
    }
    testAccess()
    testImportAlias()
}
