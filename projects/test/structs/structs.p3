/**
 *  Test accessing struct members.
 */
struct Fruit(
    pub int a,
    pub int b = 1,   // This initialisation will be moved to 'new' func
    //short b, // duplicate
    pub bool isABanana,
    //pub static int ss = 3,
    pub int z,
    //static foobar = { int a ->
    //}
) {
    pub fn new(/* Fruit* this */) {
        // All struct var initialisers will be put in here
        // This will be called before properties are set manually during initialisation

        this.b += 3
    }
    pub fn foo(/* Fruit* this */) {
        this.boo(inc:1)
    }
    pub fn bar(/* Fruit* this, */ int a) {
        struct Vegetable(bool isGreen)
        this.isABanana := true
        return a
    }
    pub fn baz(/* Fruit* this, */ bool sing) {
        int loc
        const localFunc = | /* Fruit* this, */ | {
            // inner func
        }

        this.z += 1
    }
    pub fn boo(/* Fruit* this, */ float inc) {

        this.a += 1
    }
    pub fn retThis() {
        return this
    }
}
struct Colour() {
    fn new() {}
    fn new(int a) {}
    fn new(int thing, bool a, int b) {}
}

int global = 99

struct Alpha(pub int a) {
    pub fn init(int v) { this.a := v }
}
struct Beta() {}
struct Gamma(int g)
struct Delta<T>(pub T a) {
    pub fn init(T v) { this.a := v }
}
struct Epsilon<T>(T a)

pub fn testStructs() {
    Fruit t

    const a = t.a + 2

    t.foo()
    //t.boo(3.1)

    //Fruit::foobar(1)

    t.retThis().foo()

    //Colour col

    Alpha alpha
    Beta beta
    Gamma gamma
    Delta<float> delta
    Epsilon<double> epsilon

    alpha.init(7)
    delta.init(9.0)

    import structs::inner_structs
    testInnerStructs()
}
