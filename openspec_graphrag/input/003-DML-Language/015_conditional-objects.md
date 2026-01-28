<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Conditional Objects

It is also possible to conditionally include or exclude one or more
object declarations, depending on the value of a boolean
expression. This is especially useful when reusing source files
between several similar models that differ in some of the details.

The syntax is very similar to the [`#if` statements](#if-else-statements)
used in methods.

```
#if (enable_target) {
    connect target (
        interface signal;
    }
}
```

One difference is that the braces are required.  It is also possible
to add else branches, or else-if branches.

```
#if (modeltype == "Mark I") {
    ...
} #else #if (modeltype == "Mark II" {
    ...
} #else {
    ...
}
```

The general syntax is

<pre>
#if ( <em>conditional</em> ) { <em>object declarations</em> ... }
#else #if ( <em>conditional</em> ) { <em>object declarations</em> ... }
...
#else { <em>object declarations</em> ... }
</pre>

The *conditional* is an expression with a constant boolean value.  It
may reference parameters declared at the same level in the object
hierarchy, or in parent levels.

The *object declarations* are any number of declarations of objects, session
variables, saved variables, methods, or other `#if` statements, but not
parameters, `is` statements, or `in each` statements . When the conditional is
`true` (or if it's the else branch of a false conditional), the object
declarations are treated as if they had appeared without any surrounding *#if*.
So the two following declarations are equivalent:

```
#if (true) {
    register R size 4;
} #else {
    register R size 2;
}
```

is equivalent to

```
register R size 4;
```

