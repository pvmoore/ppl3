
pub struct Static(
    pub int m = 10,
    pub static int s = 20,
    pub int rm = 30,
    pub static int rs = 40,
    int pm = 50,
    static int ps = 60)
{
    pub fn foo(/* Static* this */) {
        return 10
    }
    pub static fn bar() {
        return 20
    }
    pub static fn bar2(int a) {
        return 30
    }

    pub fn rfoo(/* Static* this */) {
        return 40
    }
    pub static fn rbar() {
        return 50
    }
    pub static fn rbar2(int a) {
        return 60
    }

    fn pfoo(/* Static* this */) {
        return 70
    }
    static fn pbar() {
        return 80
    }
    static fn pbar2(int a) {
        return 90
    }
}
pub struct Statics2 <T>(
    pub T m = 1,
    pub static T s = 2)
{
    pub fn orange<G>(G g) { return 6 }

    pub static fn foo() { return 3 }
    pub static fn foo(int a) { return 4 }

    pub static fn yellow<K>(K k) { return 5 }
}
