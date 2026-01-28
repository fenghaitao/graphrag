<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Expressions

All ISO C operators are available in DML, except for certain limitations
on the comma-operator, the `sizeof` operator, and type casts; see
Section [Comparison to C/C++](#comparison-to-c). Operators have the same
precedences and semantics as in C

DML adds the following expressions:

### The Undefined Constant

```
undefined
```

The constant `undefined` is an abstract *compile-time
only* value, mostly used as a default for parameters that are
intended to optionally be overridden. The `undefined` expression may only
appear as a parameter value and as argument to
the <code>defined <em>expr</em></code> test (see below).

### References

<pre>
<em>identifier</em>
</pre>

To reference something in the DML object structure, members may be
selected using
`.` and `->` as in C. (However, most objects in the DML
object structure are proper substructures selected with the `.`
operator.) For example,

```
this.size # a parameter
dev.bank1 # a bank object
bank1.r0.hard_reset # a method
```

The DML object structure is a compile-time construction; references to
certain objects are not considered to be proper values, and result in
compile errors if they occur as standalone expressions.

Some DML objects are proper values, while others are not:

* `session`/`saved` variables are proper values

* Composite object references (to `bank`, `group`, `register`, etc.) are not
  proper values unless cast to a [template type](#templates-as-types).

* Inside an object array, the index variable (named `i` by
  default) may evaluate to an *unknown index* if accessed
  from a location where the index is not statically known. For
  instance, in `group g[i < 4] { #if (i == 0) { ... } }`,
  the `#if` statement is invoked once, statically, across all
  indices, meaning that the `i` reference is an unknown
  index, and will yield a compile error.

* A reference to a `param` member is a proper value
  only if the parameter value is a proper value: A parameter value
  can be a reference to an object, an object array, a list,
  the `undefined` expression, or a static index (discussed
  above), in which case the parameter is not allowed as a standalone
  expression.

* When the object structure contains an array of objects,
  e.g. `register r[4] { ... }`, then a reference to the array
  itself (i.e. `r` as opposed to `r[0]`), is not
  considered a proper value.

If a DML object is not a proper value, then a reference to the object
will give a compile error unless it appears in one of the following contexts:

* As the left operand of the `.` operator

* As the definition of a `param`

* As a list element in a compile-time list

* As the operand of the `defined` operator

* A `method` object may be called

* An object array may appear in an index
  expression <code><em>array</em>[<em>index</em>]</code>

* An unknown index may be used as an index to an object array; in the
  resulting object reference, the corresponding index variable of
  the object array will have an unknown value.

### Method References as Function Pointers
It is possible to retrieve a function pointer for a method by using the prefix
operator `&` with a reference to that method. The methods this is possible with
are subject to the same restrictions as with the [`export` object
statement](#export-declarations): it's not possible to retrieve a function
pointer to any inline method, shared method, method that throws, method with
more than one return argument, or method declared inside an object array.

For example, with the following method in DML:
```
method my_method(int x) { ... }
```

then the expression `&my_method` will be a function pointer of type:
```
void (*)(conf_object_t *, int);
```

The `conf_object_t *` parameter corresponds to the device instance, and is
omitted when the referenced method is [independent](#independent-methods).

Note that due to the precedence rules of `&`, if you want to immediately call a
method reference converted to a function pointer, then you will need to wrap
parentheses around the converted method reference. An example of where this may
be useful is in order to call a non-independent method from within an
independent method:
```
independent method callback(int i, void *aux) {
  local conf_object_t *obj = aux;
  (&my_method)(obj, i);
}
```

### New Expressions

<pre>
new <em>type</em>

new <em>type</em>[<em>count</em>]
</pre>

Allocates a chunk of memory large enough for a value of the specified
type.  If the second form is used, memory for *count* values will
be allocated.  The result is a pointer to the allocated memory. (The
pointer is never null; if allocation should fail, the Simics
application will be terminated.)

When the memory is no longer needed, it should be deallocated using a
`delete` statement.

### Cast Expressions

<pre>
cast(<em>expr</em>, <em>type</em>)
</pre>

Type casts in DML must be written with the above explicit `cast`
operator, for syntactical reasons.

Semantically, <code>cast(<em>expr</em>, <em>type</em>)</code> is equivalent to
the C expression <code>(<em>type</em>) <em>expr</em></code>.

### Sizeoftype Expressions

<pre>
sizeoftype <em>type</em>
</pre>

The `sizeof` operator in DML can only be used on expressions,
not on types, for syntactical reasons. To take the size of a datatype,
the `sizeoftype` operator must be used, as in

```
int size = sizeoftype io_memory_interface_t;
```

Semantically, <code>sizeoftype <em>type</em></code> is equivalent to the C
expression <code>sizeof (<em>type</em>)</code>.

DML does not know the sizes of all types statically; DML usually regards a
`sizeoftype` expression as non-constant and delegates size calculations
to the C compiler. DML does evaluate the sizes of integer types, layout types,
and constant-sized arrays thereof, as constants.

### Defined Expressions

<pre>
defined <em>expr</em>
</pre>

This compile-time test evaluates to `false` if
*`expr`* has the value `undefined`, and to
`true` otherwise.

### Each-In Expressions

An expression `each`-`in` is available to traverse all objects
that implement a specific template. This can be used as a generic hook
mechanism for a specific template, e.g. to implement custom reset patterns.
For example, the following can be used to reset all registers in the bank
`regs`:
```
foreach obj in (each hard_reset_t in (regs)) {
    obj.hard_reset();
}
```

An `each`-`in` expression can currently only be used for
iteration in a `foreach` statement. The expression's type
is <code>sequence(<em>template-name</em>)</code>.

An `each`-`in` expression searches recursively in the
object hierarchy for objects implementing the template, but once it
finds such an object, it does not continue searching inside that
subobject. Recursive traversal can be achieved by letting the
template itself contain a method that descends into subobjects; the
implementation of `hard_reset` in `utility.dml`
demonstrates how this can be done.

The order in which objects are given by a specific `each`-`in` expression is not
defined, except for that it is deterministic. That is, for a particular choice
of template `X` and object `Y` in an `each X in (Y)` expression, for a
particular iteration of the device model, and for the particular DMLC build
used, the order in which objects are given by that expression is guaranteed to
be consistent.

### List Expressions

<pre>
[<em>e1</em>, ..., <em>eN</em>]
</pre>

A list is a *compile-time only* value, and is an ordered sequence
of zero or more expressions. Lists are in particular
used in combination with `foreach` and `select`
statements.

A list expression may only appear in the following contexts:

* As the list to iterate over in a `#foreach`
  or `#select` statement

* As the value in a `param` or `constant` declaration

* As a list element in another compile-time list

* In an index expression, <code><em>list</em>[<em>index</em>]</code>

* As the operand of the `defined` operator

### Length Expressions

<pre>
<em>list</em>.len

<em>sequence</em>.len

<em>object-array</em>.len

<em>value-array</em>.len
</pre>

Used to obtain the length of a *`list`*,
*`sequence`*, *`object-array`*,
or *`value-array`* expression.
This expression is constant for each form but *`sequence`*
expressions.

The *`value-array`* form can only be used with arrays of known
constant size: it can't be used with pointers, arrays of unknown size,
or variable-length arrays.

### Bit Slicing Expressions

<pre>
<em>expr</em>[<em>e1</em>:<em>e2</em>]

<em>expr</em>[<em>e1</em>:<em>e2</em>, <em>bitorder</em>]

<em>expr</em>[<em>e1</em>]

<em>expr</em>[<em>e1</em>, <em>bitorder</em>]
</pre>

If *`expr`* is of integer type, then the above
*bit-slicing* syntax can be used in DML to simplify extracting or
updating particular bit fields of the integer. Bit slice syntax can be
used both as an expression producing a value, or as the target of an
assignment (an L-value), e.g., on the left-hand side of an `=`
operator.

Both *`e1`* and *`e2`* must be integers. The
syntax <code><em>expr</em>[<em>e1</em>]</code> is a short-hand for
<code><em>expr</em>[<em>e1</em>:<em>e1</em>]</code> (but only evaluating
*`e1`* once).

The *`bitorder`* part is optional, and selects the bit
numbering scheme (the "endianness") used to interpret the values of
*`e1`* and *`e2`*. If present, it must be one
of the identifiers `be` or `le`, just as in the
`bitorder` device-level declaration.  If no
*`bitorder`* is given in the expression, the global bit
numbering (as defined by the `bitorder` declaration) is used.

The first bit index *`e1`* always indicates the *most
significant bit* of the [field](#field-declarations),
regardless of the bit numbering scheme. If the default
little-endian bit numbering is used, the least significant bit of the
integer has index zero, and the most significant bit of the integer has
index *n* - 1, where *n* is the width of the integer type.

If big-endian bit numbering is used, e.g., due to a `bitorder
be;` declaration in the file, or using a specific local bit
numbering as in <code><em>expr</em>[<em>e1</em>:<em>e2</em>, be]</code>, then
the bit corresponding to the little-endian bit number *n* - 1 has
index zero, and the least significant bit has the index *n* - 1,
where *n* is the bit width of *`expr`*.  Note that
big-endian numbering is illegal if *`expr`* isn't a simple
expression with a well-defined bit width.  This means that only local
variables, method parameters, device variables (registers, data etc),
and explicit cast expressions are allowed.  For little-endian
numbering, any expressions are allowed, since there is never any doubt
that bit 0 is the least significant bit.

If the bit-slicing expression results in a zero or negative sized
range of bits, the behavior is undefined.

### Stringify Expressions

<pre>
stringify(<em>expr</em>)
</pre>

Translates the value of *`expr`* (which must be a
compile-time constant) into a string constant. This is similar to the
use of `#` in the C preprocessor, but is performed on the level
of compile time values, not tokens. The result is often used with the
`+` string operator.

### String Concatenation Expressions

<pre>
<em>expr1</em> + <em>expr2</em>
</pre>

If both *`expr1`* and *`expr2`* are compile-time
string constants, the expression <code><em>expr1</em> + <em>expr2</em></code>
concatenates the two strings at compile time. This is often used in
combination with the `#` operator, or to break long lines for
source code formatting purposes.

### Compile-Time Conditional Expressions

<pre>
<em>condition</em> #? <em>expr1</em> #: <em>expr2</em>
</pre>

Similar to the C `conditional` expression, with the difference
that the *condition* must have a constant value and the
expression is evaluated at compile-time.
*expr1* is only processed if the
*condition* is `true` and *expr2* is only processed
if *condition* is `false`, so an expression like
`false #? 1/0 #: 0` is equivalent to `0`.
