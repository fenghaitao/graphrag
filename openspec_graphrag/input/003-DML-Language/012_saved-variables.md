<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Saved variables

A *saved* declaration creates a named storage location for an
arbitrary run-time value, and automatically creates an attribute
that checkpoints this variable. Saved variables can be declared in
object or statement scope, and the name will belong to the namespace
of other declarations in that scope. The general form is:

<pre>
saved <em>declaration</em> = <em>initializer</em>;
</pre>

where *`= initializer`* is optional
and *`declaration`* is similar to a C variable
declaration; for example,

```
saved int id = 1;
saved bool active;
saved double table[4] = {0.1, 0.2, 0.4, 0.8};
```

In the absence of explicit initializer expression, a default
"all zero" initializer will be applied to the declared object.

Note that the number of elements in the initializer must match with
the number of elements or fields of the type of the *saved*
variable. This also implies that each sub-element, if itself being a
compound data structure, must also be enclosed in braces.

C99-style designated initializers are supported for `struct`, `layout`, and
`bitfields` types:
```
typedef struct { int x; struct { int i; int j; } y; } struct_t;
saved struct_t s = { .x = 1, .y = { .i = 2, .j = 3 } }
```
Unlike C, partial initialization is not allowed implicitly; a designated
initializer for each member must be specified.
However, partial initialization can be done explicitly through the use of
trailing `...` syntax:
```
session struct_t s = { .y = { .i = 2, ... }, ... }
```

Also unlike C, designator lists are not supported, and designated initializers
for arrays are not supported.

In addition, the types of saved declaration variables are currently
restricted to primitive data types, or structs or arrays containing
only data types that could be saved. Such types are called
[*serializable*](#serializable-types).

> [!NOTE]
> Saved variables are primarily intended for making checkpointable
> state easier. For configuration, `attribute` objects should
> be used instead. Additional data types for saved declarations are planned to
> be supported.



## Code Examples

### Example: Saved Variable Usage

Using saved variables for checkpointable state

```dml
dml 1.4;

device saved_example;

bank regs {
    register control size 4 @ 0x0000 is (read, write) {
        // Saved variable - persists in checkpoints
        saved bool device_enabled = false;
        saved uint32 last_command = 0;
        
        method write(uint64 value) {
            this.val = value;
            device_enabled = (value & 0x1) != 0;
            last_command = cast(value >> 8, uint32);
            
            if (device_enabled) {
                log info: "Device enabled with command %d", last_command;
            }
        }
    }
}
```
