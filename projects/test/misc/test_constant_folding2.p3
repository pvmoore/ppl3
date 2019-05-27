
// public struct with unreferenced members
pub struct P(           // cannot be removed
    pub int v1,         // cannot be removed
    int v2,             // check targets within struct
    pub static int v3,  // cannot be removed
    static int v4)      // check targets within struct
{
    pub fn f1() {}      // cannot be removed
    fn f2() {}          // check targets within struct

    pub struct P1()     // cannot be removed
    pub enum E1 { E1 }  // cannot be removed
    
    struct P2()         // check types within struct   
    enum E2 { E2 }      // check types within struct   
}
// private struct with unreferenced members
struct Q(               // check types from parent scope
    pub int v1,         // check targets of parent scope
    int v2,             // check targets within struct
    pub static int v3,  // check targets of parent scope
    static int v4)      // check targets within struct 
{
    pub fn f1() {}      // check targets within module
    fn f2() {}          // check targets within struct

    pub struct Q1()     // cannot be removed
    pub enum E1 { E1 }  // cannot be removed
    
    struct Q2()         // check types within struct   
    enum E2 { E2 }      // check types within struct 
}

struct R()  // check types from parent scope(Module)

pub fn globalFuncPub() {}   // cannot be removed

fn globalFuncPriv() {       // check targets of parent scope
    struct A(               // check types from parent scope
        pub int v1,         
        int v2,
        pub static int v3,
        static int v4)
    {
        pub fn f1() {}  // check targets of struct parent scope
        fn f2() {}      // check targets within struct
        pub static fn f3() {}
        static fn f4() {}
        
        pub struct A2() {}
        struct A3() {}
    }
    
    A a
    a.v1
    //a.v2    // private
    A.v3
    //A.v4    // private
    a.f1()
    //a.f2()  // private
    A.f3()
    //A.f4()  // private
    
    A::A2 a2
    //A::A3 a3    // private
}

pub fn testConstantFolding2() {
    P p
    p.v1
    //p.v2    // private
    p.f1()
    //p.f2()  // private
    P::P1 p1
    //P::P2 p2    // private
    P::E1 pe1
    //P::E2 pe2    // private
    
    Q q
    q.v1
    //q.v2    // private
    q.f1()
    //q.f2()  // private
    Q::Q1 q1
    //Q::Q2 q2 // private
    Q::E1 qe1
    //Q::E2 eq2   // private
    
    globalFuncPub()
    globalFuncPriv()
}