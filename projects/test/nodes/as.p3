 
pub fn testAs() {
    const a = 10 as byte              ; assert @typeOf(a) is byte
    const a1 = 10.3d as int           ; assert @typeOf(a1) is int and a1==10
    const a2 = (3 as float) as byte   ; assert @typeOf(a2) is byte
    const a3 = (3 as long) as int*    ; assert @typeOf(a3) is int*

    // tuples
    alias Tuple = struct(int,byte,short)
    const b  = @structOf(1, 2 as byte, 3 as short) as struct(int,byte,short)
    const b2 = @structOf(1, 2 as byte, 3 as short) 
    struct Name(int a)
    const b3 = null as Name*
    const b4 = @structOf(3 as byte) as struct(int)  

    // arrays
    const d  = @arrayOf(int, 1,2,3) as int[3]  
    const d2 = @arrayOf(int, 1,2,3) as int[3]   ; assert @typeOf(d2) is int[3]



}
