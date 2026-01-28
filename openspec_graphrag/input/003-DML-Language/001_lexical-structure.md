<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Lexical Structure

A major difference from C is that names do not generally need to
be defined before their first use. This is quite useful, but might
sometimes appear confusing to C programmers.

<dl><dt>

Character encoding
</dt><dd>

DML source files are written using UTF-8 encoding.  Non-ASCII characters are
only allowed in comments and in string literals.  Unicode BiDi control
characters (U+2066 to U+2069 and U+202a to U+202e) are not allowed.  String
values are still handled as byte arrays, which means that a string value
written with a literal of three characters may actually create an array of more
than three bytes.  </dd><dt>

Reserved words
</dt><dd>

All ISO/ANSI C reserved words are reserved words in DML (even if
currently unused). In addition, the C99 and C++ reserved words
`restrict`, `inline`, `this`, `new`,
`delete`, `throw`, `try`, `catch`, and
`template` are also reserved in DML. The C++ reserved words
`class`, `namespace`, `private`,
`protected`, `public`, `using`, and
`virtual`, are reserved in DML for future use; as are
identifiers starting with an underscore (`_`).

The following words are reserved specially by DML: `after`,
`assert`, `call`, `cast`, `defined`, `each`,
`error`, `foreach`, `in`, `is`,
`local`, `log`, `param`, `saved`, `select`,
`session`, `shared`, `sizeoftype`, `typeof`, `undefined`,
`vect`, `where`, `async`, `await`,
`with`, and `stringify`.

</dd><dt>

Identifiers
</dt><dd>

Identifiers in DML are defined as in C; an identifier may begin
with a letter or underscore, followed by any number of letters,
numbers, or underscores. Identifiers that begin with an underscore (`_`)
are reserved by the DML language and standard library and should not
be used.

</dd><dt>

Constant Literals
</dt><dd>

DML has literals for strings, characters, integers, booleans, and
floating-point numbers.  The integer literals can be written in
decimal (`01234`), hexadecimal (`0x12af`), or binary
(`0b110110`) form.

Underscores (`_`) can be used between digits, or immediately
following the `0b`, `0x` prefixes, in integer literals
to separate groups of digits for improved readability. For example,
`123_456`, `0b10_1110`, `0x_eace_f9b6` are valid
integer constants, whereas `_78`, `0xab_` are not.

String literals are surrounded by double quotes (`"`). To
include a double quote or a backslash (`\`) in a string
literal, precede them with a backslash (`\"` and `\\`,
respectively). Newline, carriage return, tab and backspace characters
are represented by `\n`, `\r`, `\t` and
`\b`. Arbitrary byte values can be encoded as `\x`
followed by exactly two hexadecimal digits, such as `\x1f`.
Such escaped byte values are restricted to 00-7f for strings
containing Unicode characters above U+007F.

Character literals consist of a pair of single quotes (`'`)
surrounding either a single printable ASCII character or one of the
escape sequences `\'`, `\\`, `\n`, `\r`,
`\t` or `\b`. The value of a character literal is
the character's ASCII value.
</dd><dt>

Comments
</dt><dd>

C-style comments are used in DML.  This includes both in-line
comments (`/*`...`*/`) and comments
that continue to the end of the line (`//`...).
</dd></dl>
