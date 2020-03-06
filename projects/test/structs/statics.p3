
import structs::statics2

struct A(
    pub int m = 1,
    pub static int s = 2,
    //pub const int T = 4,           // fixme
    //pub const static int S = 9,    // fixme
    pub int rm = 3,
    pub static int rs = 4,
    int pm = 5,
    static int ps = 6,
)
{
    pub fn foo() /* A* this */  {
        return 1
    }
	pub static fn foo() { return 99 }
    pub static fn bar() {

        //foo() // require A.foo()
        A.foo() // ok

        //s     // require A.s
        A.s     // ok

        return 2
    }
    pub static fn bar2(int v) {
        return 3
    }

    pub fn rfoo( /* A* this */ ) {
        return 4
    }
    pub static fn rbar() {
        return 5
    }
    pub static fn rbar2(int v) {
        return 6
    }

    fn pfoo(/* A* this */ ) {
        return 7
    }
    static fn pbar() {
        return 8
    }
    static fn pbar2(int v) {
        return 9
    }
}
struct B <T>(
    pub T m = 1,
    static T s = 2)
{
    pub fn orange<G>(G g) { return 6 }

    pub static fn foo() { return 3 }
    pub static fn foo(int a) { return 4 }

    pub static fn yellow<K>(K k) { return 5 }
}

//static int globalStatic // not allowed
//globalFoo { static int a -> } // not allowed

pub fn testStatics() {
	const testLocal = || {
        const a = A()
        // member access
        assert a.m == 1
        assert a.foo() == 1

        // static access
        //var ss = a.s      // not allowed

		assert A.s == 2
		assert A.rs == 4
        //assert A.ps == 6      // private
        assert @sizeOf(A) == 12
        assert A.bar() == 2
        assert A.bar2(8) == 3
        assert A.rbar() == 5
        assert A.rbar2(5) == 6
        //assert A.pbar() == 8      // private
        //assert A.pbar2(10) == 9   // private
        assert A.foo() == 99
        const a1 = A.s as float  ; assert @typeOf(a1) is float; assert a1 == 2.0

        const b = B<int>()
        // member access
        assert b.m == 1
        assert b.orange<float>(3.14) == 6
        // static access
        assert @sizeOf(B<int>) == 4
        //assert B<int>.s == 2  // private
        assert B<int>.foo() == 3
        assert B<int>.foo(7) == 4
        assert B<int>.yellow<float>(3.14) == 5

        //A::foo()         // not allowed - (fixme.needs better error msg)
        //a.bar()           // not allowed
        //[static int] anon // not allowed
        //static int nope   // not allowed
        //globalFoo(1)
    }
    const testExternal = || {
        const a = Static()
        // member access
        assert a.m == 10
        assert a.foo() == 10

        // static access
        assert Static.s == 20
        assert Static.rs == 40
        //assert Static::ps == 60     // private external
        assert @sizeOf(Static) == 12

        assert Static.bar() == 20
        assert Static.bar2(1) == 30
        assert Static.rbar() == 50
        assert Static.rbar2(5) == 60
        //assert Static::pbar() == 80       // private external
        //assert Static::pbar2(10) == 90    // private external

        const b = Statics2<int>()
        // member access
        assert b.m == 1
        assert b.orange<float>(3.14) == 6
        // static access
        assert @sizeOf(Statics2<int>) == 4
        assert Statics2<int>.s == 2
        assert Statics2<int>.foo() == 3
        assert Statics2<int>.foo(7) == 4
        assert Statics2<int>.yellow<float>(3.14) == 5
    }
	const testNameClashes = || {
		const a = || {
			struct J1(static int a)
			J1 j1
		}
		const b = || {
			struct J1(static int a)
			J1 j1
		}
		const c = || {
			struct J1(static int a)
			J1 j1
		}
		a()
		b()
		c()
		struct test_statics(pub static bool boo)
		test_statics t
		test_statics.boo
        //test_statics.boo = true // can not be modified outside the struct
	}
    testLocal()
    testExternal()
	testNameClashes()
}
