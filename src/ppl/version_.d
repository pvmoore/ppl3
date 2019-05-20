module ppl.version_;

public:

const string VERSION = "3.25.0";

/*

3.25.0 - Remove more declarations in the resolve phase.
         Prevent casting enum to different enum.

3.24.0 - Added @ctUnreachable()

3.23.0 - Simplify Composite.Usage

3.22.0 - Remove unreferenced variables and functions within the resolve phase.

3.21.0 - Constant fold 'if'.
         Add @ctAssert builtin compile time assert.
         Add [[noopt]] attribute. Currently accepted but does not affect the generation.

3.20.0 - Rename a lot of files to more closely reflect the class names.
         Remove some unused inner function code.

3.19.0 - Disallow (type is expression) and vice versa. Use @typeOf.

3.18.0 - Change tuple declaration syntax to 'struct(variable_list)'.
         Change @tupleOf to @structOf.

3.17.0 - Add error for incorrect 'pub' placement.

3.16.0 - Disallow inner functions. Add @isFunctionPtr builtin.

3.15.0 - Add new closure/lambda syntax eg. |a| {}

3.14.0 - Add new function declaration syntax. fn(type)type and fn id(type)type {}

3.13.0 - Refactor variable parsing again.

3.12.0 - Refactor variable parsing. Disallow duplicate modifiers.
         Disallow const and var on the same declaration

3.11.0 - Change attribute syntax from $attrib(...) to [[attrib ...]]

3.10.0 - Add @expect builtin function.
         Remove expect attribute.

3.9.0 - Add @arrayOf and @tupleOf. Remove old array and tuple literal square bracket syntax.

3.8.0 - Refactor access. 'pub' keyword only applies to subsequent declaration.
        Remove 'private' and 'readonly' keywords.
        Struct properties accessed from outside the struct are considered as
        either private if they are not 'pub', or readonly if they are marked as pub.
        Functions are only callable from outside a struct if they are pub.

3.7.0 - Rename 'public' to 'pub'.

3.6.0 - Add # as a line comment. Remove // line comment.

3.5.0 - Change 'return' to 'ret'.

3.4.0 - Add more builtins and change them to camel case.

3.3.0 - Use @ for builtins eg @typeof, @sizeof etc instead of #

3.2.0 - Use $ for attributes instead of @.

3.1.0 - Change source file extensions from p2 to p3.

3.0.0 - Initial clone from PPL2. Remove IDE code.


TODO Compiler:

    - Look at projects/dev/test2.p3 for examples of the new syntax

    - Add integration tests folder and create a script to run through all tests in the folder,
      asserting compiler errors.

    - Implement ControlFlow to check that every route through a function returns
      correctly

    - Implement [[range]] attribute and add checks if boundsChecks=true

    - Replace pointers with ref / const ref
    - Remove module, replace with struct for entire file??
    - Change import syntax
    - Add coroutine intrinsics eg. @coroPrelude, @coroHandle, @coroSuspend, @coroResume

    - Ensure only basic optimisations get done if we are in DEBUG mode
    - Panic - Null references
    - Add fast math option
    - Cache debug ir, optimised ir and bc for modules. Store keyed by a sha1 of the
      program args and the update timestamp.
    - Think about const. If a struct value is const we should not allow any modifying
      member property updates or function calls.

    - Fold for/loop (wait for syntax change?)

    ** foldable()

    ** Fold more EnumMemberValues

    ** struct decl syntax change:
        struct A <T> (pub int a, bool b) {
            # functions
        }
      so that it is similar to tuple decl syntax eg. struct(int a)

    ** Change 'loop' to 'for' eg. for(array) v, i {}
        - for(i in 0..10) {}
        - for(i in @range(0,10,1)) {}
            struct Range<T>(T start, T end, T step)

TODO Lib:
    - Create a work-stealing thread pool in libs/core or libs/std using coroutines
    - Implement @mapOf, @listOf



TODO Known bugs:

- Infinite struct should not be allowed:

    struct A {
        A a
    }

- Cryptic IR generation error produced:

    var c = A::ONE
    assert c.value = 1      // = instead of ==

- Assert this

    struct A {
        foo {
            assert this     // <--- error
        }
    }

- Missing return at end of function
    func {
        if(var a=0; true) return a

        // should be a return here
    }

- Should be able to determine type of null
    func {
        if(int a=0; true) return &a
        return null // <--- int*
    }

-   Determine type of null

    call(null)

-   config.enableOptimisation = false produces link errors


-   indexOf { string s ->
        indexOf(s, 0)   // this.indexOf(s,0) works
    }


 */
