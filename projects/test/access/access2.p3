
pub struct Access(
    int a,
    pub int b,
    pub int c,
    int d)
{
    fn foo() {}
    fn foo<T>(T t) {}

    pub fn foo1() {
        // i can see private member
        this.a
        this.a += 1
    }
    pub fn foo1<T>(T t) {}

    pub fn foo2() {}
    pub fn foo2<T>(T t) {}

    fn foo3() {}
    fn foo3<T>(T t) {}
}

pub struct Access2 <T>(
    T a,
    pub T b,
    pub T c)
{
    fn foo() {}
    fn foo<U>(U u) {}

    pub fn foo1() {}
    pub fn foo1<U>(U u) {}
}

pub fn testAccess2() {
    // Access within same module is ok
    Access a

    // call access
    //a.foo()    // private
    a.foo1()
    a.foo2()
    //a.foo3()   // private

    // explicit template call
    //a.foo<int>(1)  // private
    a.foo1<int>(1)
    a.foo2<int>(1)
    //a.foo3<int>(1) // private

    // implicit template call
    //a.foo(1)   // private
    a.foo1(1)
    a.foo2(1)
    //a.foo3(1)  // private

    // read access
    //a.a    // private
    a.b
    a.c
    //a.d    // private

    // no write access
    //a.a += 1
    //a.b += 1
    //a.c += 1
    //a.d += 1

    // same for templated structs
    Access2<int> a2
    //a2.foo()   // private
    a2.foo1()
    //a2.foo<int>(1)  // private
    a2.foo1<int>(1)
    //a2.foo(1)  // private
    a2.foo1(1)
    //a2.a   // private
    a2.b
    a2.c

    //a2.a += 1
    //a2.b += 1
    //a2.c += 1
}
