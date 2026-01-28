<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Templates

<pre>
template <em>name</em> { ... }
</pre>

Defines a *template*, a piece of code that can be reused in
multiple locations. The body of the template contains a number of
declarations that will be added to any object that uses the template.

Templates are imported into an object declaration body using
`is` statements, written as

<pre>
is <em>name</em>;
</pre>
for example:
```
field F {
    is A;
}
```

It is also possible to use templates when declaring an object, as in

<pre>
field F is (<em>name1</em>, <em>name2</em>);
</pre>

These can be used in any context where an object declaration may be written, and
has the effect of expanding the body of the template at the point of the `is`.
Using `is` together with object declarations is typically more idiomatic than
the standalone `is` object statement; however, the latter is useful in order
to instantiate templates in the top-level device object, and also for use in
conjunction with [`in each` declarations](#in-each-declarations); for example:

```
register r {
    in each field {
        is A;
    }

    field F1 @ [7:6];
    ...
}
```

If two templates define methods or parameters with the same name, then the
template instantiation hierarchy is used to deduce which method overrides the
other: If one template *B* instantiates another template *A*, directly or
indirectly, then methods from *B* override methods from *A*. Note, however, that
overrides can only happen on methods and parameters that are declared `default`.
Example:

```
template A {
    method hello() default {
        log info: "hello";
    }
}
template B is A {
    // this method overrides the
    // method from A
    method hello() default {
        default();
        log info "world";
    }
}
```

See [Resolution of Overrides](#resolution-of-overrides) for a formal
specification of override rules.

### Templates as types

Each template defines a *type*, which is similar to a class
in an object oriented language like Java. The type allows you to
store references to a DML object in a variable. Some, but not all,
top-level declarations inside a template appear as members of the template type.
A template type has the following members:

* All [session](#session-variables) and [saved](#saved-variables) variables
  declared within the template. E.g., the declaration `session int val;` gives a
  type member `val`.

* All declarations of typed parameters, further discussed below.
  E.g., the declaration `param foo : uint64;` gives a type member `foo`.

* All method declarations declared with the `shared` keyword,
  further discussed below. E.g., the declaration
  `shared method fun() { ... }`
  gives a type member `fun`, which can be called.

* Every `shared` [hook](#hook-declarations) declared within the template.
  E.g. the declaration `shared hook(int, bool) h;` gives a type member `h`.

* All type members of inherited templates. E.g., the declaration
  `is simple_time_event;`
  adds two type members `post` and `next`, since
  `post` and `next` are members of
  the `simple_time_event` template type.

* The `templates` member, which permits [template-qualified method
  implementation calls](#template-qualified-method-implementation-calls) to
  the `shared` method implementations of the template type's ancestor templates.

Template members are dereferenced using the `.` operator,
much like struct members.

A template's type is named like the template, and an object
reference can be converted to a value using the `cast`
operator.  For instance, a reference to the
register `regs.r0` can be created and used as follows
(all register objects automatically implement the template `register`):

```
local register x = cast(regs.r0, register);
x.val = 14;  // sets regs.r0.val
```

Two values of the same template type can be compared for equality, and are
considered equal when they both reference the same object.

A value of a template type can be upcast to an ancestor template type; for
example:
```
local uint64_attr x = cast(attr, uint64_attr);
local attribute y = cast(x, attribute);
```
In addition, a value of any template type can be cast to the template type
`object`, even if `object` is not an ancestor of the template.

### Shared methods
If a method is declared in a template, then one copy of the method
will appear in each object where the template is instantiated;
therefore, the method can access all methods and parameters of that
object. This is often convenient, but comes with a cost; in
particular, if a template is instantiated in many objects, then this
gives unnecessarily large code size and slow compilation. To address
this problem, a method can be declared *shared* to operate on
the template type rather than the implementing object. The
implementation of a shared method is compiled once and shared between
all instances of the template, rather than duplicated between
instances.

Declaring a method as shared imposes restrictions on its
implementation, in particular which symbols it is permitted to access:
Apart from symbols in the global scope, a shared method may only
access members of the template's type; it is an error to access any
other symbols defined by the template. Members can be referenced
directly by name, or as fields of the automatic `this`
variable.  When accessed in the scope of the shared method's body,
the `this` variable evaluates to a value whose type is the
template's type.

Example:

```
template base {
    // abstract method: must be instantiated in sub-template or object
    shared method m(int i) -> (int);
    shared method n() -> (int) default { return 5; }
}
template sub is base {
    // override
    shared method m(int i) -> (int) default {
        return i + this.n();
    }
}
```

If code duplication is not a concern, it is possible to define a shared method
whose implementation is not subject to above restrictions while still retaining
the benefit of having the method be a member of the template type.
This is done by defining the implementation separately from the declaration
of the shared method, for example:
```
template get_qname {
    shared method get_qname() -> (const char *);
    method get_qname() -> (const char *) {
        // qname is an untyped parameter, and would thus not be accessible
        // within a shared implementation of get_qname()
        return this.qname;
    }
}
```



## Code Examples

The following examples demonstrate the concepts described in this section.


### Example: tmpl.dml

Template definition and usage

```dml
dml 1.4;

device tmpl;
param desc = "sample DML device";
param documentation = "This is a very simple device.";


template spam is write {
    method write(uint64 value) {
        log error: "spam, spam, spam, ...";
    }
}

bank regs {
    register A size 4 @ 0x0 is spam;
}

template lucky_number is read {
    param extra_1 default 1;
    param extra_2;

    method read() -> (uint64) {
        local uint64 value = this.val * extra_1 + extra_2;
        log error: "my lucky number is %d", value;
        return value;
    }
}

bank regs {
    register B size 4 @ 0x4 is lucky_number {
        param extra_2 = 4711;
    }
}
```

### Example: Register Alias Template

Template to create an alias register that redirects to another register

```dml
dml 1.4;

device alias;
param desc = "sample DML device";

import "utility.dml";

bank regs {
    register X size 4 @ 0x00 "the X register";
    register Y size 4 @ 0x04 is alias { param alias_reg = X; }
}

template alias is (register, desc) {
    param alias_reg;
    param desc = "alias of " + alias_reg.name;

    method read_register(uint64 enabled_bytes, void *aux)-> (uint64) {
        log info, 4: "Redirecting read access to %s", alias_reg.qname;
        return alias_reg.read_register(enabled_bytes, aux);
    }

    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        log info, 4: "Redirecting write access to %s", alias_reg.qname;
        alias_reg.write_register(value, enabled_bytes, aux);
    }
}
```
