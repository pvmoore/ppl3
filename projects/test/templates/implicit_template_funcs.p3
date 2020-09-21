
struct Goo <T>(T a)
struct Gaa <T>(T a)
struct Gee <T>(T a)

fn func<X,Y>(fn(X return Y) a) { return 0 }
fn func<A>(A[2][1] a         ) { return 1 }
fn func<A>(A[3] a            ) { return 2 }
fn func<A>(A[2] a            ) { return 3 }
fn func<A>(Goo<A> a          ) { return 4 }
fn func<A>(Gaa<A> a          ) { return 5 }
fn func<A>(A* a              ) { return 6 }
fn func<A>(Gee<Gaa<A>> a     ) { return 7 }

fn func<A>(A a, int b) { return 10 }
fn func<A>(int a, int b, struct(A, A) c) { return 20 }
fn func<A>(int a, int b, A[2] c) { return 30 }
fn func<A>(int a, int b, struct(A a, A b ,A c) c) { return 40 }

pub fn testImplicitTemplateFunctions() {
    const singleArg = || {
        fn(int return bool) arg0
        assert 0 == func(arg0)

        short[2][1] arg1
        assert 1 == func(arg1)

        float[3] arg2
        assert 2 == func(arg2)

        byte[2] arg3
        assert 3 == func(arg3)

        Goo<int> arg4
        assert 4 == func(arg4)

        Gaa<short> arg5
        assert 5 == func(arg5)

        int* arg6
        assert 6 == func(arg6)

        Gee<Gaa<int>> arg7
        assert 7 == func(arg7)
    }
    const multipleArgs = || {
        assert 10 == func(5,6)
        assert 20 == func(2,3, @structOf(4,5) )
        assert 30 == func(2,3, @arrayOf(int,4,5) )
        assert 40 == func(2,3, @structOf(4,5,6) )
    }
    singleArg()
    multipleArgs()
}



