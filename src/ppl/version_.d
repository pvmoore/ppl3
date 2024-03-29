module ppl.version_;

public:

enum VERSION = "3.51.0";

/*

// todo -
        // Implement LiteralMap @mapOf(string,int, key=value, key=value)

        // No need for Access. Use bool isPublic instead

        // Don't use Logger for writing .ast files. Change the extension to .ast3 and
        // copy the extension from ppl4

        // Remove vscode server and extension code

        // Add fold phase which is separate from resolve phase. This will run after resolve on each
        // pass. eg. Pass = parse -> resolve -> fold

        // Remove 'var' and 'const'. Or just remove const and assume name = Expression is const




        // -----------------------------------------------------------------------------------------




        // todo - allow names in function types?

        // why are we adding function import proxies to module and not to
        // an import node?

        // We need to add any struct/enum etc to the template module as a reference

        - Add formatted string f"My name is ${name}, age ${04f:age}"
        - Implement regex strings

        - Rename loop to for?

        - Use fast math option when generating code


        - Add evaluation phase alongside parse and resolve. This will try to evaluate compile time values (CTValue)
            where possible. This should mean we will not need to fold away expressions so much which means
            it should be easier to offser suggestions to the IDE. Also, we should be able to cache whether or
            not a node has been resolved if we don't keep changing the structure. When the structure changes this flag
            will need to be reset though but it should be faster.
            - Also keep a isZombie flag on statement to aid in evaluating.

        - IDE: Requires evaluation refactor otherwise certain positions in the code cannot provide suggestions
            because they have been folded away.


3.51.0 -

3.50.0 - Fix parenthesis required bug

3.49.0 - Add (optional) null check whenever a pointer member variable or function is accessed

3.48.0 - Add ':=' as an alias for '=' for reassigning a variable.
       - Assume 'name = value' is a variable declaration and definition (use ':=' re reassignment)
       - Add error for unnecessary extra semi-colon

3.47.0 - Add simple control flow check to ensure functions are not missing a required return

3.46.0 - Fix compilation errors due to changes in common.class MyClass
       - Change function ptr syntax to fn(int a return int)

3.45.0 - Refactor parseConstructor so that any structural changes are done during the resolve phase.

3.44.0 - More work on Server.
         Make class types implicitly pointer. eg. class C() ; @isPointer(C) == true
         Add @pointerDepth and @isClass builtin functions.

3.43.0 - Refactor logging.
         Add end position to Token.
         Add end position to ASTNode.

3.42.0 - Add class - needs more work.
         Add server and incremental builder - needs more work.

3.41.0 - Change attributes syntax to --attribute.

3.40.0 - Record and display number of inactive modules.
         Change attributes syntax to !!attribute [=value]
         Fix bugs.

3.39.0 - Check that parameters, properties and return types of public structs/functions and enums
         have types that are also public.

3.38.0 - Remove 'f' suffix for number literals since by default any float literals are float.
         Force lambda literals to begin with '|' even if there are no parameters.

3.37.0 - Add missing ppl.build src folder. Add multiline sttings. Disallow auto string concatenation eg. "a" "b".

3.36.0 - Force 'this.' prefix when accessing functions or members from within a class function.

3.35.0 - Rename 'ret' back to 'return'

3.34.0 - Remove operator overloads other than ==, != and []

3.33.0 - Show first couple of errors in detail. Subsequent errors are shown one per line.
         Change <> operator to !=.

3.32.0 - Tidy up Alias. Remove all Aliases other than STANDARD once they've been resolved.

3.31.0 - Remove numRefs from Alias, Enum and struct.

3.30.0 - Refactor DeadCodeEliminator. Enum and Struct numRefs properties should not be required
         any more. Due to be removed in the next version.

3.29.0 - Rename Variable isStructMember() to isStructVar() to separate the isStatic check.
         No need to store memberIndex in Target. It can be calculated.

3.28.0 - Tidy up some more node folding.
         Remove concept of active/inactive nodes for resolution. Everything is now expected
         to be resolved.
         Make pub variables at module scope an error since this does not make any sense.
         Fix bug allowing access to private struct members.

3.27.0 - Add back // line comments

3.26.0 - Change struct decl syntax to struct Name <...> (Variables) { ... }

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

    - Add integration tests folder and create a script to run through all tests in the folder,
      asserting compiler errors.

    - Add checks if boundsChecks=true

    - Add null checks if nullChecks=true

    - Replace pointers with ref / const ref

    - Add coroutine intrinsics eg. @coroPrelude, @coroHandle, @coroSuspend, @coroResume

    - Ensure only basic optimisations get done if we are in DEBUG mode

    - Cache debug ir, optimised ir and bc for modules. Store keyed by a sha1 of the
      program args and the update timestamp.

    - Think about const. If a struct value is const we should not allow any modifying
      member property updates or function calls.

    - Fold for/loop (wait for syntax change?)

    ** Change 'loop' to 'for' eg.
        - for(i in 0..10) {}
        - for(i in @range(0,10,1)) {}
            struct Range<T>(T start, T end, T step)

TODO Lib:
    - Create a work-stealing thread pool in libs/core or libs/std using coroutines
    - Implement @mapOf, @listOf



TODO Known bugs:

- ParseExpression/parseConstructor
    If the type is an alias we may not know at that point whether or not it is a ptr.
    We should write the constructor code in ResolveConstructor instead after the type is resolved.

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

- Should be able to determine type of null
    func {
        if(int a=0; true) return &a
        return null // <--- int*
    }

-   Determine type of null

    call(null)

-   config.enableOptimisation = false produces link errors

-   fn indexOf(string s) {
        indexOf(s, 0)   // this.indexOf(s,0) works
    }

 */
