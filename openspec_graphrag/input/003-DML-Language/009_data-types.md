<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Data types

The type system in DML builds on the type system in C, with a few
modifications.  There are eight kinds of data types.  New names for
types can also be assigned using a `typedef` declaration.

<dl><dt>

Integers
</dt><dd>

Integer types guarantee a certain *minimum* bit width and
may be signed or unsigned.  The basic integer types are
named `uint1`,
`uint2`, ..., `uint64` for the unsigned types, and
`int1`, `int2`, ..., `int64` for the signed
types. Note that the size of the integer type is only a hint and the
type is guaranteed to be able to hold at least that many
bits. Assigning a value that would not fit into the type is
undefined, thus it is an error to assume that values will be
truncated. For bit-exact types, refer to `bitfields`
and `layout`.

The familiar integer types `char` and `int` are
available as aliases for `int8` and `int32`,
respectively. The C keywords `short`, `signed` and `unsigned`
are reserved words in DML and not allowed in type
declarations.

The types `size_t` and `uintptr_t`, `long`, `uint64_t`, `int64_t`, are defined
as in C. The types `long`, `uint64_t` and `int64_t` are provided mainly for
compatibility with third party libraries; they are needed because they are
incompatible with the corresponding Simics types (`uint64`, etc) on some
platforms.  </dd><dt>

Endian integers
</dt><dd>

Endian integer types hold similar values as
integer types, but in addition have the following attributes:

* *They are guaranteed to be stored in the exact number of bytes
  required for their bitsize, without padding.*

* *They have a defined byte order.*

* *They have a natural alignment of 1 byte.*

Endian integer types are named after the integer type
with which they share a bitsize and sign but in addition
have a `_be_t` or `_le_t` suffix, for big-endian
and little-endian integers, respectively. The full list of endian types is:

<!-- A markdown table would have been nice here, but that's currently (2021)
too poorly rendered (SIMICS-18374) -->
```
int8_be_t    int8_le_t    uint8_be_t    uint8_le_t
int16_be_t   int16_le_t   uint16_be_t   uint16_le_t
int24_be_t   int24_le_t   uint24_be_t   uint24_le_t
int32_be_t   int32_le_t   uint32_be_t   uint32_le_t
int40_be_t   int40_le_t   uint40_be_t   uint40_le_t
int48_be_t   int48_le_t   uint48_be_t   uint48_le_t
int56_be_t   int56_le_t   uint56_be_t   uint56_le_t
int64_be_t   int64_le_t   uint64_be_t   uint64_le_t
```

These types can be transparently
used interchangeably with regular integer types, values of one
type will be coerced to the other as needed. Note that operations
on integers will always produce regular integer types, even
if all operands are of endian integer type.

</dd><dt>

Floating-point numbers
</dt><dd>

There is only one floating-point type, called `double`.
It corresponds to the C type `double`.
</dd><dt>

Booleans
</dt><dd>

The boolean type `bool` has two values, `true` and
`false`.
</dd><dt>

Arrays
</dt><dd>

An array is a sequence of elements of another type, and works as
in C.
</dd><dt>

Pointers
</dt><dd>

Pointers to types, work as in C. String literals have the
type `const char *`. A pointer has undefined meaning
if the pointer target type is an integer whose bit-width is neither 8,
16, 32, nor 64.
</dd><dt>

Structures
</dt><dd>

A `struct` type defines a composite type that contains
named members of different types.  DML makes no assumptions about the
data layout in struct types, but see the layout types below for that.
Note that there is no struct label as in C, and struct member declarations
are permitted to refer to types that are defined further down in the file.
Thus, new struct types can always be declared using the following syntax:
<pre>
typedef struct { <em>member declarations</em> } <em>name</em>;
</pre>

</dd><dt>

Layouts
</dt><dd>

A layout is similar to a struct in many ways.  The important
difference is that there is a well-defined mapping between a layout
object and the underlying memory representation, and layouts may
specify that in great detail.

A basic layout type looks like this:

```
layout "big-endian" {
    uint24 x;
    uint16 y;
    uint32 z;
}
```

By casting a pointer to a piece of host memory to a pointer of this
layout type, you can access the fourth and fifth byte as a 16-bit
unsigned integer with big-endian byte order by simply writing
`p->y`.

The allowed types of layout members in a layout type declaration
are integers, endian integers, other layout types,
bitfields (see below), and arrays of these.

The byte order declaration is mandatory, and is
either `"big-endian"` or `"little-endian"`.

Access of layout members do not always provide a value of the
type used for the member in the declaration. Bitfields and
integer members (and arrays of similar) are translated
to endian integers (or arrays of such) of similar size,
with endianness matching the layout. Layout and endian integer
members are accessed normally.
</dd><dt>

Bitfields
</dt><dd>

A bitfield type works similar to an integer type where you use bit
slicing to access individual bits, but where the bit ranges are
assigned names. A `bitfields` declaration looks like this:

```
bitfields 32 {
    uint3  a @ [31:29];
    uint16 b @ [23:8];
    uint7  c @ [7:1];
    uint1  d @ [0];
}
```

The bit numbering is determined by the `bitorder` declaration
in the current file.

Accessing bit fields is done as with a struct or layout, but the whole
bitfield can also be used as an unsigned integer. See the following
example:

```
local bitfields 32 { uint8 x @ [7:0] } bf;
bf = 0x000000ff;
bf.x = bf.x - 1;
local uint32 v = bf;
```

</dd></dl>

### Serializable types
_Serializable types_ are types that the DML compiler knows how to serialize and
deserialize for the purposes of checkpointing. This is important for the use of
[`saved` variables](#saved-variables) and the [`after`
statement](#after-statements).

All primitive non-pointer data types (integers, floating-point types, booleans,
etc.) are considered serializable, as is any struct, layout, or array type
consisting entirely of serializable types. [Template types](#templates-as-types)
and [hook reference types](#hook-declarations) are also considered serializable.

Any type not fitting the above criteria is not considered serializable:
in particular, any pointer type is not considered serializable, nor is any
[`extern`](#typedef-declarations) struct type; the latter is because it's
impossible for the compiler to ensure it's aware of all members of the struct
type.

