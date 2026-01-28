<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Global Declarations

The following sections describe the global declarations in DML. These
can only occur on the top level of a DML model, i.e., not within an
object or method. Unless otherwise noted, their scope is the entire
model.

### Import Declarations

<pre>
import <em>filename</em>;
</pre>

Imports the contents of the named file. *filename* must be a string
literal, such as `"utility.dml"`. The `-I` option to the
`dmlc` compiler can be used to specify directories to be searched
for import files.

If *filename* starts with `./` or `../`, the
compiler disregards the `-I` flag, and the path is instead
interpreted relative to the directory of the importing file.

Note that imported files are parsed as separate units, and use their
own language version and bit order declarations. A DML 1.4 file is not
allowed to import a DML 1.2 file, but a DML 1.2 file may import a DML
1.4 file.

### Template Declarations

[Templates](#templates) may only be declared on the top level, and the syntax
and semantics for such declarations have been described previously.

Templates share the same namespace as types, as each template declaration
defines a corresponding template type of the same name. It is illegal to define
a template whose name conflicts with that of another type.

### Bitorder Declarations

<pre>
bitorder <em>order</em>;
</pre>

Selects the default bit numbering scheme to be used for interpreting
bit-slicing expressions and bit field declarations in the file. The
*`order`* is one of the identifiers `le` or
`be`, implying little-endian or big-endian, respectively.  The
little-endian numbering scheme means that bit zero is the least
significant bit in a word, while in the big-endian scheme, bit zero is
the most significant bit.

A `bitorder` declaration should be placed before any other
global declaration in each DML-file, but must follow immediately after
the `device` declaration if such one is present.
The scope of the declaration is the whole of the file it
occurs in. If no `bitorder` declaration is present in a file, the
default bit order is `le` (little-endian). The bitorder does not
extend to imported files; for example, if a file containing a
declaration "`bitorder be;`" imports a file with no bit order
declaration, the latter file will still use the default `le`
order.

### Constant Declarations

<pre>
constant <em>name</em> = <em>expr</em>;
</pre>

Defines a named constant.
*`expr`* must be a constant-valued expression.

Parameters have a similar behaviour as constants but are more
powerful, so constants are rarely useful. The only advantage of
constants over parameters is that they can be used in `typedef`
declarations.

### Loggroup Declarations

<pre>
loggroup <em>name</em>;
</pre>

Defines a log group, for use in [`log` statements](#log-statements).
More generally,
the identifier *`name`* is bound to an unsigned integer
value that is a power of 2, and can be used anywhere in C context; this
is similar to a `constant` declaration, but the value is
allocated automatically so that all log groups are represented by
distinct powers of 2 and can be combined with bitwise *or*.

A maximum of 63 log groups may be declared per device (61 excluding the built-in
`Register_Read` and `Register_Write` log groups.)

### Typedef Declarations

<pre>
typedef <em>declaration</em>;
extern typedef <em>declaration</em>;
</pre>

Defines a name for a [data type](#data-types).

When the `extern` form is used, the type is assumed to exist in
the C environment. No definition of the type is added to the
generated C code, and the generated C code blindly assume that the
type exists and has the given definition.

An `extern typedef` declaration may not contain a `layout` or
`endian int` type.

If a `struct` type appears within an `extern typedef`
declaration, then DMLC will assume that there is a corresponding C
type, which has members of given types that can be accessed with
the `.` operator. No assumptions are made on completeness or
size; so the C struct may have additional fields, or it might be
a `union` type. An empty member list is even allowed; this can
make sense for opaque structs. DML variables of `extern` struct type are
initialized such that any members of the C struct which are unknown to DML are
initialized to 0.

Nested struct definitions are permitted in an `extern typedef`
declaration, but an inner struct type only supports member access; it
cannot be used as a standalone type. For instance, if you have:
```
extern typedef struct {
    struct { int x; } inner;
} outer_t;
```

then you can declare `local outer_t var;` and access the member
`var.inner.x`, but the inner type is unknown to DML so you cannot
declare a variable `local typeof var.inner *inner_p;`.

### Extern Declarations

<pre>
extern <em>declaration</em>;
</pre>

Declares an external identifier, similar to a C `extern`
declaration; for example,

```
extern char *motd;
extern double table[16];
extern conf_object_t *obj;
extern int foo(int x);
extern int printf(const char *format, ...);
```

Multiple `extern` declarations for the same identifier are permitted as long as
they all declare the same type for the identifier.

### Header Declarations

```
header %{
...
%}
```

Specifies a section of C code which will be included verbatim in the
generated C header file for the device. There must be no whitespace
between the `%` and the corresponding brace in the `%{`
and `%}` markers. The contents of the header section are not
examined in any way by the `dmlc` compiler; declarations made
in C code must also be specified separately in the DML code proper.

This feature should only be used to solve problems that cannot easily be
handled directly in DML. It is most often used to make the generated
code include particular C header files, as in:

```
header %{
#include "extra_defs.h"
%}
```

The expanded header block will appear in the generated C file, which
usually is in a different directory than the source DML
file. Therefore, when including a file with a relative path, the C
compiler will not automatically look for the `.h` file in
the directory of the `.dml` file, unless a corresponding
`-I` flag is passed. To avoid this problem, DMLC inserts a C
macro definition to permit including a *companion header
file*. For instance, if the
file `/path/to/hello-world.dml` includes a header block,
then the macro `DMLDIR_HELLO_WORLD_H` is defined as the
string `"/path/to/hello-world.h"` within this header
block. This allows the header block to contain `#include
DMLDIR_HELLO_WORLD_H`, as a way to include `hello-world.h`
without passing `-I/path/to` to the C compiler.

DMLC only defines one such macro in each header block, by taking the
DML file name and substituting the `.dml` suffix
for `.h`. Furthermore, the macro is undefined after the
header. Hence, the macro can only be used to access one specific
companion header file; if other header files are desired, then
`#include` directives can be added to the companion header
file, where relative paths are expanded as expected.

See also `footer` declarations, below.

### Footer Declarations

```
footer %{
...
%}
```

Specifies a piece of C code which will be included verbatim at the end
of the generated code for the device. There must be no whitespace
between the `%` and the corresponding brace in the `%{`
and `%}` markers. The contents of the footer section are not
examined in any way by the `dmlc` compiler.

This feature should only be used to solve problems that cannot easily be
handled directly in DML. See also `header` declarations, above.

### Export Declarations

<pre>
export <em>method</em> as <em>name</em>;
</pre>

Exposes a method specified by *`method`* to other C modules within the
same Simics module under the name *`name`* with external linkage. Note
that inline methods, shared methods, methods that throw, methods with
more than one return argument, and methods declared inside object
arrays cannot be exported. It is sometimes possible to write wrapper
methods that call into non-exportable methods to handle such cases,
and export the wrapper instead.

Exported methods are rarely used; it is better to use Simics
interfaces for communication between devices. However, exported
methods can sometimes be practical in tight cross-language
integrations, when the implementation of one device is split between
one DML part and one C/C++ part.

Example: the following code in DML:

```
method my_method(int x) { ... }
export my_method as "my_c_function";
```

will export `my_method` as a C function with external linkage,
using the following signature:

```
void my_c_function(conf_object_t *obj, int x);
```

The `conf_object_t *obj` parameter corresponds to the device instance, and is
omitted when the referenced method is [independent](#independent-methods).



## Code Examples

The following examples demonstrate the concepts described in this section.


### Example: plugin_module.dml

Import declaration example

```dml
dml 1.4;
device plugin_module;
param documentation =
    "Plugin module example for Model Builder User's Guide";
param desc = "example plugin module";
import "talk.dml";

implement talk {
    method hello() {
        log info: "Hi there!";
    }
}
```

### Example: constant.dml

Constant declaration example

```dml
dml 1.4;

device constant;
param documentation = "Constant register example for"
    + " Model Builder User's Guide";
param desc = "example constant register";

import "utility.dml";

bank regs {
    register counter size 4 @ 0x0000  is constant {
        param init_val = 42;
    }
}

bank regs2 {
    register counter size 4 @ 0x0000  is (constant, read) {
        param init_val = 42;
        method read() -> (uint64) {
            local uint64 to_return = default();
            log info, 1: "read from counter";
            return to_return;
        }
    }
}
```
