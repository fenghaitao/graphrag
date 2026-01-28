<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Parameters detailed

Parameters may be typed or untyped.
Typed parameter declarations may only appear in template definitions.

Parameters are declared using one of the forms

```
param name;
param name: type
```

and assigned using the `=` operator. Parameters may also be given default values using the form `param name default expr`.
For example:

```
param offset = 8;
param byte_order default "little-endian";
```

A default value is overridden by an assignment (`=`).
There can be at most one assignment for each parameter.
Typically, a default value for a parameter is specified in a template, and the programmer may then choose to override it where the template is used.
See [Resolution of overrides](#resolution-of-overrides) for the resolution order when there are multiple definitions of the same parameter.

A parameter that is declared without an assignment or a default value must eventually be assigned elsewhere, or the model will not compile.
This pattern is sometimes useful in templates, as in:

```
template constant is register {
    param value;
    method get() -> (uint64) {
        return value;
    }
}
```

so that wherever the template `constant` is used, the programmer
is also forced to define the parameter `value`. E.g.:

```
register r0 size 2 @ 0x0000 is (constant) {
    param value = 0xffff;
}
```

> [!IMPORTANT]
> When writing templates, always declare parameters that are referenced.
> Enabling the provisional feature `explicit_param_decls` enforces this.
>
> Leaving out the parameter declaration from the template
> definition can have unwanted effects if the programmer forgets to
> specify its value where the template is used. At best, it will only
> cause a more obscure error message, such as "unknown identifier"; at
> worst, the scoping rules will select an unrelated definition of the same
> parameter name.

### `explicit_param_decls` provisional feature

There is a shorthand syntax for combined declaration and definition of a parameter, currently enabled by the [`explicit_param_decls` provisional feature](provisional-auto.html#explicit_param_decls):

```
param NAME: TYPE = value;
param NAME: TYPE default value;
param NAME := value;
param :default value;
```

`explicit_param_decls` enforces that parameters are declared before they are assigned, or that the combined syntax is used.
This distinguishes between the intent to declare a new parameter, and the intent to override an existing parameter.
This distinction allows DML to capture misspelled parameter overrides as compile errors.

DMLC signals an error if the combined declaration and definition syntax is used to override an existing parameter.
This guards against unintentional reuse of a parameter name. An example:

```
// Included file not using explicit_param_decls
template foo_capability {
    param foo_offset; // parameter which must be assigned by the device instantiating the template
    param has_foo_feature default false; // overridable parameter with a default value
    param id default 1; // overridable parameter with a generic name
}
```

```
// Device model file including the above
provisional explicit_param_decls;

template extended_foo_capability is foo_capability {
    param has_bar_feature: bool default false;

    // unintentional reuse of parameter name:
    param id := 5; // error: the parameter 'id' has already been declared
}

bank foo_config {
    is extended_foo_capability;

    // correct assignment to template parameter:
    param foo_offset = 0x10;

    // misspelled parameter override:
    param has_foo_featur = true;  // error: parameter 'has_foo_featur' not declared previously.
}
```

It is recommended to enable `explicit_param_decls` in new DML source files and to use the new combined syntax when applicable to reduce the risk of bugs caused by misspelled parameters.

In some rare cases, you may need to declare a parameter without
knowing if it's an override or a new parameter. In this case, one
can accompany a `param NAME = value;` or `param NAME default
value;` declaration with a `param NAME;` declaration in the same
scope/rank. This marks that the parameter assignment may be either
an override or a new parameter, and no error will be printed.

### Typed Parameters detailed
A typed parameter declaration adds a member to the template type with the same
name as the specified parameter, and with the specified type. That member is
associated with the specified parameter, in the sense that the definition of the
parameter is used as the value of the template type member.

A typed parameter declaration places a number of requirements on the
named parameter:
* The named parameter must be defined (through a regular [parameter
  declaration](#parameters-detailed)). This can be done either within the
  template itself, within sub-templates, or within individual objects
  instantiating the template.
* The parameter definition must be a valid expression of the specified type.
* The parameter definition must be free of side-effects, and must not rely on
  the specific device instance of the DML model &mdash; in particular, the
  definition must be independent of device state.

  This essentially means that the definition must be a constant expression,
  except that it may also make use of device-independent expressions whose
  values are known to be constant. For example, index parameters, [`each`-`in`
  expressions](#each-in-expressions), and object references cast to template
  types are allowed. It is also allowed to reference other parameters that obey
  this rule.

  Examples of expressions that may *not* be used include method calls and
  references to `session`/`saved` variables.
* The parameter definition must not contain calls to
  [independent methods](#independent-methods).

Typed parameters are most often used to allow a shared method defined within
the template to access parameters of the template. For example:

```
template max_val_reg is write {
    param max_val : uint64;

    shared method write(uint64 v) {
        if (v > max_val) {
            log info: "Ignoring write to register exceeding max value %u",
                      max_val;
        } else {
            default(v);
        }
    }
}

bank regs {
    register reg[i < 2] size 8 @0x0 + i*8 is max_val_reg {
        param max_val = 128 * (i + 1) - 1;
    }
}
```

### Special parameters in the DML standard library

You may see the following special form in some standard library files:

<pre>
param <em>name</em> auto;
</pre>

for example,

```
param parent auto;
```

This is used to explicitly declare the built-in automatic parameters,
and should never be used outside the libraries.

