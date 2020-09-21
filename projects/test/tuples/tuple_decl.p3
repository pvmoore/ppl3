


pub fn testTupleDecl() {
    struct(int t, bool b) a
    alias tupe = struct(int s)

    tupe tup           = @structOf(1)
    struct(int s) tup2 = @structOf(2)
    @typeOf(a) tup3    = @structOf(3, false)

    const r = returnTuple();    assert @typeOf(r) is struct(int)
    const r2 = returnTuple2();
}

fn returnTuple(return struct(int)) {
    return @structOf(1)
}
fn returnTuple2(return struct(fn(int return void))) {
    return @structOf(|int a| {})
}