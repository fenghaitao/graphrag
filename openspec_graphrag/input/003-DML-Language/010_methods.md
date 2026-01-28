<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Methods
<a id="methods-detailed"/>

Methods are similar to C functions, but also have an implicit
(invisible) parameter which allows them to refer to the current device
instance, i.e., the Simics configuration object representing the device.
Methods also support exception handling in DML, using `try` and
`throw`. The body of the method is a compound statement in an
[extended subset of C](#comparison-to-c).
It is an error to have more than one method declaration using the same
name within the same scope.

### Input Parameters and Return Values

A DML method can have any number of return values, in contrast to C
functions which have at most one return value. DML methods do not use
the keyword `void` — an empty pair of parentheses always
means "zero parameters". Furthermore, lack of return value can even be
omitted. Apart from this, the parameter declarations of a method are
ordinary C-style declarations.

For example,

```
method m1() -> () {...}
```

and

```
method m1() {...}
```

are equivalent, and define a method that takes no input parameters and
returns nothing.

```
method m2(int a) -> () {...}
```

defines a method that takes a single input parameter, and also returns
nothing.

```
method m3(int a, int b) -> (int) {
    return a + b;
}
```

defines a method with two input parameters and a single return value.
A method that has a return value must end with a return statement.

```
method m4() -> (int, int) {
    ...;
    return (x, y);
}
```

has no input parameters, but two return values.

A method that can throw an exception must declare so, using
the `throws` keyword:

```
method m5(int x) -> (int) throws {
    if (x < 0)
        throw;
    return x * x;
}
```

### Default Methods

A parameter or method can now be overridden more than once.

When there are multiple declarations of a parameter, then the template
and import hierarchy are used to deduce which declaration to use: A
declaration that appears in a block that instantiates a template will
override any declaration in that template, and a declaration that
appears in a file that imports another file will override any
declaration from that file. The declarations of one parameter must
appear so that one declaration overrides all other declarations of he
parameter; otherwise the declaration is considered ambiguous and an
error is signalled.

Examples: A file `common.dml` might contain:

```
param num_banks default 2;
bank banks[num_banks] {
    ...
}
```

Your device `my-dev.dml` can then contain:

```
device my_dev;
import "common.dml";
// overrides the declaration in common.dml
param num_banks = 4;
```

The assignment in `my-dev.dml` takes precedence,
because `my-dev.dml` imports `common.dml`.

Another example: The following example gives an compile error:

```
template my_read_constant {
    param value default 0;
    ...
}
template my_write_constant {
    param value default 0;
    ...
}
bank b {
    // ERROR: Two declarations exist, and neither takes precedence
    register r is (my_read_constant, my_write_constant);
}
```

The conflict can be resolved by declaring the parameter a third time,
in a location that overrides both the conflicting declarations:

```
bank b {
    register r is (my_read_constant, my_write_constant) {
        param value default 0;
    }
}
```

Furthermore, an assignment (`=`) of a parameter may not be
overridden by another declaration.

If more than one declaration of a method appears in the same object,
then the template and import hierarchies are used to deduce the
override order. This is done in a similar way to how parameters are
handled:

* A method declaration that appears in a block that instantiates a
  template will override any declaration from that template

* A method declaration that appears in a file that imports another
  file will override any declaration from that file.

* The declarations of one method must appear so that one
  declaration overrides all other declarations of the method; otherwise
  the declaration is considered ambiguous and an error is signalled.

* A method can only be overridden by another method if it is declared
  `default`.

> [!NOTE]
> An overridable built-in method is defined by a template
> named as the object type. So, if you want to write a template that
> overrides the `read` method of a register, and want to make
> your implementation overridable, then your template must explicitly
> instantiate the `register` template using a statement `is
> register;`.

### Calling Methods

In DML, a method call looks much like in C, with some exceptions. For instance,

```
(a, b) = access(...);
```

calls the method 'access' in the same object, assigning the return values to
variables `a` and `b`.

If one method overrides another, it is possible to refer to the overridden
method from within the body of the overriding method using the identifier
`default`:

```
x = default(...);
```

In addition to `default`, there exists the [`templates` member of
objects](#template-qualified-method-implementation-calls) which allows for
calling the particular implementation of a method as provided by a specified
template. This is particularly useful when `default` _can't_ be used due to the
method overriding implementations provided by multiple hierarchically unrelated
templates, such that `default` can't be unambiguously resolved (see [Resolution
of overrides](#resolution-of-overrides).) Unlike `default`, `templates` can also
be used even outside the body of the overriding method.

DML supports _compound initializer syntax_ for the arguments of called methods,
meaning arguments of struct-like types can be constructed using
<tt>{<em>...</em>}</tt>. For example:
```
typedef struct {
    int x;
    int y;
} struct_t;

method copy_struct(struct_t *tgt, struct_t src) {
    *tgt = src
}

method m() {
    local struct_t s;
    copy_struct(&s, {1, 4});
    copy_struct(&s, {.y = 1, .x = 4});
    copy_struct(&s, {.y = 1, ...}); // Partial designated initializer
}
```
This syntax can't be used for variadic arguments or [inline
arguments](#inline-methods).

### Inline Methods

Methods can also be defined as inline, meaning that at
least one of the input arguments is declared `inline` instead
of declaring a type. The method body is re-evaluated every time it is
invoked, and when a constant is passed for an inline argument, it will
be propagated into the method as a constant.

Inline methods were popular in previous versions of the language, when
constant folding across methods was a useful way to reduce the size of
the compiled model. DML 1.4 provides better ways to reduce code size,
and inline methods remain mainly for compatibility reasons.

### Exported Methods

In DML 1.4, methods can be `exported` using the
[`export` declaration](#export-declarations).

### Retrieving Function Pointers to Methods

In DML 1.4, [method references can be converted to function pointers using
`&`](#method-references-as-function-pointers).

### Independent Methods

Methods that do not rely on the particular instance of the device model may
be declared `independent`:
```
independent method m(...) -> (...) {...}
```
[Exported](#export-declarations) independent methods do not have the input
parameter corresponding to the device instance, allowing them to be called
in greater number of contexts. The body of independent methods may not contain
statements or expressions that rely on the device instance in any way; for
example, `session` or `saved` variables may not be referenced, `after` and `log`
statements may not be used, and non-`independent` methods may not be called.

Within a template, `shared` independent methods may be declared.

When independent methods are used as callbacks, it can sometimes be desirable to
mutate device state. In order to do this safely, device state should be mutated
within a method not declared `independent`, which can called from independent
methods [through the use of `&`](#method-references-as-function-pointers).
Device state should not be mutated directly within an independent method as this
could cause certain Simics breakpoints to not function correctly; for example,
an independent method should not mutate a session variable through a pointer to
that variable.

#### Independent Startup Methods

Independent methods may also be declared `startup`, which causes them to be
called when the model is loaded into the simulation, *before* any device is
created. In order for this to be possible, `independent startup methods` may not
have any return values nor be declared `throw`s. In addition, independent
startup methods may not be declared with an overridable definition due to
technical limitations &mdash; this restriction can be worked around by having an
independent startup method call an overridable independent method. Note that
abstract `shared` independent startup methods are allowed.

The order in which independent startup methods are implicitly called at model
load is not defined, with the exception that independent startup methods not
declared memoized are called before any independent startup methods that are.

#### Independent Startup Memoized Methods
Independent startup methods may also be declared `memoized`. Unlike regular
`independent startup` methods, `independent startup memoized` methods may
&mdash; indeed, are required to &mdash; have return values and/or be
declared `throws`.

After the first call of a memoized method, all subsequent calls for the
simulation session return the results of the first call without executing the
body of the method. If a memoized method call throws, then subsequent calls will
throw without executing the body.

The first call to an independent startup memoized method will typically be the
one implicitly performed at model load, but it may also occur beforehand (for
example, if the method is called as part of another independent startup method).

Result caching is shared across all instances of the device model. This
mechanism can be used to compute device-independent data which is then shared
across all instances of the device model.

The results of `shared` memoized methods are cached per template instance, and
are not shared across all objects instantiating the template.

(Indirectly) recursive memoized method calls are not allowed; the result of
such a call is a run-time critical error.



## Code Examples

The following examples demonstrate the concepts described in this section.


### Example: logging.dml

Method examples with logging

```dml
dml 1.4;

device logging;
param documentation = "Logging example for Model Builder User's Guide";
param desc = "example of logging";

loggroup example;

method m(uint32 val) {
    log info, 4, example : "val=%u", val;
}

method init() {
    m(42);
}
```
