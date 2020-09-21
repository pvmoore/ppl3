
pub fn testCalls() {
    const a = || {
        return 0
    }
    const c = |int a, int b| {
        return 5
    }

    //a()   // ambiguous
    //b(3)  // ambiguous

	assert 2 == b(3 as int) // b(int) exact match
    assert 3 == b(3.1)      // b(float)
    assert 3 == b(p1:3.1)
    assert 4 == b(1,2)
    assert 4 == b(p1:1, p2:3.1)
    assert 4 == b(p2:3.1, p1:1)
    assert 5 == c(7,8)
    assert 5 == c(a:7, b:8)
    assert 5 == c(b:7, a:9)

    const testGroovyStyleCall = || {
        println("Test ... Groovy type function calls")

        // declarations
		const blah = |fn(return void) closure| {
            closure()
        }
        const blah2 = |int a, fn(return void) closure| {
            closure()
        }


        //blah()   { println("hello") }     // missing ||
        //blah2(1) { println("hello2") }    // missing ||
        //blah { println("hello halh") }    // missing ||

        blah3<int> |int a| {}


        //blah3 |int a| {}      // BUG!! should be inferred but isn't


        blah || { println("hello halh") }
        blah() || { println("hello halh") }
        blah2(2) || { println("hello blah2") }
    }
    testGroovyStyleCall()
}

fn blah3<T>(fn(T p return void) closure) {

}

fn a() {
    return 1
}
fn b(int p1) {
    return 2
}
fn b(float p1) {
    return 3
}
fn b(int p1, float p2) {
    return 4
}
