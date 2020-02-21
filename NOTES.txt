
# Sequences and Ranges

Sequence<T>
    .hasNext():bool
    .next():T

Range<T>
    .isEOF():bool
    .isAtEnd():bool
    .current():T
    .next()

for(n in sequence {}

0..N
or
intRange(0,N).step(-1)



# Language Server Protocol

Look at lsp4j for example


# Add UFCS

```
fn foo(int i, bool b) {}

30.foo(true)
```