<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Object Declarations

The general form of an object declaration is "<code><em>type</em>
<em>name</em> <em>extras</em> is (<em>template</em>, ...) <em>desc</em> {
... }</code>" or "<code><em>type</em> <em>name</em> <em>extras</em> is
(<em>template</em>, ...) <em>desc</em>;</code>", where *`type`*
is an object type such as `bank`, *`name`* is an
identifier naming the object, and *`extras`* is optional
special notation which depends on the object type. The <code>is
(<em>template</em>, ...)</code> part is optional and will make the object
inherit the named templates. The surrounding parenthesis can be omitted if
only one template is inherited. The *`desc`* is an optional
string constant giving a very short summary of the object. It can consist
of several string literals concatenated by the '+' operator. Ending the
declaration with a semicolon is equivalent to ending with an empty
pair of braces. The *body* (the section within the braces) may
contain *parameter declarations*, *methods*, *session
variable declarations*, *saved variable declarations*,
*in each declarations* and
*object declarations*.

For example, a `register` object may be declared as

```
register r0 @ 0x0100 "general-purpose register 0";
```

where the "<code>@ <em>offset</em></code>" notation is particular for the
`register` object type; see below for details.

Using <code>is (<em>template1</em>, <em>template2</em>)</code> is equivalent to
using `is` statements in the body, so the following two
declarations are equivalent:

```
register r0 @ 0x0100 is (read_only,autoreg);

register r0 @ 0x0100 {
    is read_only;
    is autoreg;
}
```

An object declaration with a *`desc`* section, on the form

<pre>
<em>type</em> <em>name</em> ... <em>desc</em> { ... }
</pre>

is equivalent to defining the parameter `desc`, as in

<pre>
<em>type</em> <em>name</em> ... {
    param desc = <em>desc</em>;
    ...
}
</pre>

In the following sections, we will leave out *`desc`* from
the object declarations, since it is always optional. Another parameter,
`documentation` (for which there is no short-hand), may also be
defined for each object, and for some object types it is used to give a
more detailed description.
See Section [Universal Templates](dml-builtins.html#universal-templates)
for details.)

If two object declarations with the same name occur within the same
containing object, and they specify the same object type, then the
declarations are concatenated; e.g.,

<pre>
bank b {
    register r size 4 { ...<em>body1</em>... }
    ...
    register r @ 0x0100 { ...<em>body2</em>... }
    ...
}
</pre>

is equivalent to

<pre>
bank b {
    register r size 4 @ 0x0100  {
        ...<em>body1</em>...
        ...<em>body2</em>...
    }
    ...
}
</pre>

However, it is an error if the object types should differ.

Most object types (`bank`, `register`,
`field`,
`group`, `attribute`, `connect`,
`event`, and `port`) may be used
in *arrays*. The general form of an object array declaration is

<pre>
<em>type</em> <em>name</em>[<em>var</em> &lt; <em>size</em>]... <em>extras</em> { ... }
</pre>

Here each <code>[<em>var</em> &lt; <em>size</em>]</code> declaration defines
a dimension of resulting array. *var* defines the name of the
index in that dimension, and *size* defines the size of the dimension.
Each *variable* defines a parameter in the object scope, and thus must
be unique.
The size must be a compile time constant. For instance,

```
register regs[i < 16] size 2 {
    param offset = 0x0100 + 2 * i;
    ...
}
```

or written more compactly

```
register regs[i < 16] size 2 @ 0x0100 + 2 * i;
```

defines an array named `regs` of 16 registers (numbered from 0 to
15) of 2 bytes each, whose offsets start at 0x0100.
See Section [Universal Templates](dml-builtins.html#universal-templates)
for details about arrays and index parameters.

The size specification of an array dimension may be replaced with `...` if the
size has already been defined by a different declaration of the same object
array. For example, the following is valid:

```
register regs[i < 16][j < ...] size 2 @ 0x0100 + 16 * i + 2 * j;
register regs[i < ...][j < 8] is (read_only);
```

The following sections give further details on declarations for object
types that have special conventions.

### Register Declarations

The general form of a `register` declaration is

<pre>
register <em>name</em> size <em>n</em> @ <em>d</em> is (<em>templates</em>) { ... }
</pre>

Each of the "<code>size <em>n</em></code>", "<code>@ <em>d</em></code>", and "<code>is
(<em>templates</em>)</code>" sections is optional, but if present, they must
be specified in the above order.

* A declaration

  <pre>
  register <em>name</em> size <em>n</em> ... { ... }
  </pre>

  is equivalent to

  <pre>
  register <em>name</em> ... { param size = <em>n</em>; ... }
  </pre>

* A declaration

  <pre>
  register <em>name</em> ... @ <em>d</em> ... { ... }
  </pre>

  is equivalent to

  <pre>
  register <em>name</em>  ... { param offset = <em>d</em>; ... }
  </pre>

### Field Declarations

The general form of a [`field` object](dml-builtins.html#field-objects)
declaration is

<pre>
field <em>name</em> @ [<em>highbit</em>:<em>lowbit</em>] is (<em>templates</em>) { ... }
</pre>

or simply

<pre>
field <em>name</em> @ [<em>bit</em>] ... { ... }
</pre>

specifying a range of bits of the containing register, where the syntax
<code>[<em>bit</em>]</code> is short for <code>[<em>bit</em>:<em>bit</em>]</code>.
Both the "`@ [...]`" and the <code>is (<em>templates</em>)</code>
sections are optional; in fact, the "`[...]`" syntax is merely a
much more convenient way of defining the (required) field parameters
`lsb` and `msb`.

For a range of two or more bits, the first (leftmost) number always
indicates the *most significant bit*, regardless of the bit
numbering scheme used in the file. This corresponds to how bit fields
are usually visualized, with the most significant bit to the left.

The bits of a register are always numbered from zero to *n* - 1,
where *n* is the width of the register. If the default
little-endian bit numbering is used, the least significant bit has index
zero, and the most significant bit has index *n* - 1. In this case,
a 32-bit register with two fields corresponding to the high and low
half-words may be declared as

```
register HL size 4 ... {
    field H @ [31:16];
    field L @ [15:0];
}
```

If instead big-endian bit numbering is selected in the file, the most
significant bit has index zero, and the least significant bit has the
highest index. In that case, the register above may be written as

```
register HL size 4 ... {
    field H @ [0:15];
    field L @ [16:31];
}
```

This is useful when modeling a system where the documentation uses
big-endian bit numbering, so it can be compared directly to the model.

