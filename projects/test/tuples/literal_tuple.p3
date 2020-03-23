
pub fn testLiteralTuple() {

    const test1 = || {
        // zero initialised
        struct(bool a, int b, float c) s

        assert s.a==false
        assert s.b==0
        assert s.c==0.0

        assert @typeOf(s[0]) is bool
        assert @typeOf(s[1]) is int
        assert @typeOf(s[2]) is float

        assert s[0]==false
        assert s[1]==0
        assert s[2]==0.0  
    }
    const test2 = || {
        // user initialised
        struct(int a, double b) s = @structOf(1,2 as double)

        assert s.a==1
        assert s.b==2.0d

        assert @typeOf(s.a) is int
        assert @typeOf(s.b) is double

        assert s[0]==1
        assert s[1]==2d
    }
    const test3 = || {
        struct(int a, float b, bool c) s = @structOf(1, 3.1, true)

        assert s.a==1
        assert s.b==3.1
        assert s.c==true

        assert s[0]==1
        assert s[1]==3.1
        assert s[2]==true
    }
    const test6 = || {
        // implicit [int,int]
        const s = @structOf(7,8)   ; assert @typeOf(s) is struct(int,int)
        assert @typeOf(s[0]) is int
        assert @typeOf(s[1]) is int

        // [byte,int]
        const s2 = @structOf(7 as byte, 8)
        assert @typeOf(s2[0]) is byte
        assert @typeOf(s2[1]) is int
    }
    const test7 = || {
        // [bool, float, long]

        const s = @structOf(true, 2.0, 3 as long)    ; assert @typeOf(s) is struct(bool,float,long)

        assert s[0] == true
        assert s[1] == 2
        assert s[2] == 3
    }
    const test8 = || {
        // standalone
        @structOf(7,8)

        // index
        const s = @structOf(9,10) [1]
        assert @typeOf(s) is int
        assert s==10
    }
    const test9 = |struct(int) a| {
        assert(a[0]==66)
    }
    const shouldNotCompile = || {
        // too few values
        //[double a, int b, bool c] s = @structOf(3.1d)

        // too many values
        //[int] s = @structOf(1,2)

        // bad casts
        //[int] a = @structOf(3.1f)
        //[float a, int b] s = @structOf(1, 3.14f)
    }
    test1()
    test2()
    test3()
    test6()
    test7()
    test8()
    test9(@structOf(66))
    shouldNotCompile()
}
