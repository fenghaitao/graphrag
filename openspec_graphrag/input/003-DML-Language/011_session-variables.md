<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Session variables

A *session* declaration creates a number of named storage locations for
arbitrary run-time values. The names belongs to the same namespace as
objects and methods. The general form is:

<pre>
session <em>declarations</em> = <em>initializer</em>;
</pre>

where *`= initializers`* is optional
and *`declarations`* is a variable declaration similar to C, or
a sequence of such declarations; for example,

```
session int id = 1;
session bool active;
session double table[4] = {0.1, 0.2, 0.4, 0.8};
session (int x, int y) = (4, 3);
session conf_object_t *obj;
```

In the absence of explicit initializer expressions, a default
"all zero" initializer will be applied to each declared object.

Note that the number of initializers &mdash; together given as a tuple
&mdash; must match the number of declared variables.
In addition, the number of elements in each initializer must match with
the number of elements or fields of the type of the declared *session*
variable. This also implies that each sub-element, if itself being a
compound data structure, must also be enclosed in braces.

C99-style designated initializers are supported for `struct`, `layout`, and
`bitfields` types:
```
typedef struct { int x; struct { int i; int j; } y; } struct_t;
session struct_t s = { .x = 1, .y = { .i = 2, .j = 3 } }
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

> [!NOTE]
> Previously `session` variables were known as `data`
> variables.



## Code Examples

### Example: Session Variable Usage

Using session variables to track access counts

```dml
dml 1.4;

device session_example;

bank regs {
    register counter size 4 @ 0x0000 is (read, write) {
        // Session variable - persists across method calls but not checkpoints
        session uint64 access_count = 0;
        
        method read() -> (uint64) {
            access_count++;
            log info: "Counter accessed %d times", access_count;
            return this.val;
        }
        
        method write(uint64 value) {
            access_count++;
            this.val = value;
        }
    }
}
```
