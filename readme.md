# PPL 3
Prototype Programming Language

## Requirements
- Dlang https://dlang.org/
- Dlang-common https://github.com/pvmoore/dlang-common
- Dlang-llvm https://github.com/pvmoore/dlang-llvm
- LLVM 9 static libs

## Quick Syntax Overview

### Variables
```
var a = 0       // int
const b = 3.2   // const float
int c = 0
float d = 3.0 + b
```
### Types
```
bool a; byte b; short c; int d; long e;
float f; double g
int[5] intArray
fn(int)void fnPtr
```
### Functions
```
pub fn foo(int param) {}

foo(3)

fn bar<T>(T p) {}

bar<double>(3.14)
bar(3.14)           // bar<float>(3.14) inferred

const lambda = |int a| { return a*10 }

assert 30 == lambda(3)

extern fn putchar(int) int

putchar('0')
```
### Structs
```
[[pod]] struct Point(int x, iny y)

const p = Point(10,20)

struct Vector<T>(T x, T y, T z) {
    pub fn new(T x, T y, T z) {
        this.x = x; this.y = y; this.z = z
    }
    [[inline]]
    pub fn dot(Vector<T> b) {
        ret x*b.x + y*b.y + z*b.y
    }
    pub operator[](int index) {
        return *((&x)+index)
    }
    pub operator==(Vector<T>* o) {
        return x==o.x and y==o.y and z==o.z
    }
    pub operator==(Vector<T> o) {
        return this is o
    }
}

const v = Vector<float>(1.0, 2.0, 3.0)

alias Vec = Vector<float>
const v2 = v.dot(Vec(4.0, 5.0, 6.0))
```
### Enums
```
enum Flag : int {
    A = 1,
    B,
    C = 9
}
Flag f = Flag.B
```