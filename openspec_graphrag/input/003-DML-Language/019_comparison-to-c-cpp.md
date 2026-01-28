<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Comparison to C/C++
<a id="comparison-to-c"/>

The algorithmic language used to express method bodies in DML is an extended
subset of ISO C, with some C++ extensions such as `new` and `delete`. The
DML-specific statements and expressions are described in Sections
[Method Statements](#method-statements) and [Expressions](#expressions).

DML defines the following additional built-in data types:

<dl><dt>

`int1`, ..., `int64`, `uint1`, ...,
`uint64`
</dt><dd>

Signed and unsigned specific-width integer types. Widths from 1 to
64 are allowed.
</dd><dt>

`bool`
</dt><dd>

The generic boolean datatype, consisting of the values `true`
and `false`. It is not an integer type, and the only implicit
conversion is to `uint1`
</dd></dl>

DML also supports the non-standard C extension
<code>typeof(<em>expr</em>)</code> operator, as provided by some modern C
compilers such as GCC.

DML deviates from the C language in a number of ways:

* All integer arithmetic is performed on 64-bit numbers in DML,
  and truncated to target types on assignment. This is similar to how
  arithmetic would work in C on a platform where the `int` type
  is 64 bits wide (though in DML, `int` is an alias
  of `int32`). Similarly, all floating-point arithmetic is
  performed on the `double` type.

  For instance, consider the following:

  ```
  local int24 x = -3;
  local uint32 y = 2;
  local uint64 sum = x + y;
  ```

  In C, the expression `x + y` would cast both operands up to unsigned
  32-bit integers before performing a 32-bit addition; overflow gives
  the result is 2<sup>32</sup> - 1, which is promoted without sign
  extension into a 64-bit integer before stored in the `sum`
  variable. In DML, both operands are instead promoted to 64-bit
  signed integers, so the addition evaluates to -1, which is stored as
  2<sup>64</sup> - 1 in the `sum` variable.

  Formally, if any of the two operands of an arithmetic binary
  operator (including bitwise operators) has the type `uint64`, then
  both operands are promoted into `uint64` before the operation;
  otherwise, both operands are promoted into `int64` before the
  operation. If any operand has floating-point type, then both
  operands are promoted into the `double` type.

* Comparison operators
  (`==`, `!=`, `<`, `<=`, `>`
  and `>=`) do *not* promote signed integers to
  unsigned before comparison. Thus, unlike in C, the following
  comparison yields `true`:

  ```
  int32 x = -1;
  uint64 val = 0;
  if (val > x) { ... }
  ```

* The shift operators (`<<` and `>>`) have well-defined semantics when
  the right operand is large: Shifting by more than 63 bits gives zero
  (-1 if the left operand is negative). Shifting a negative number of
  bits is an error.

* Division by zero is an error.

* Signed overflow in arithmetic operations (`+`, `-`, `*`, `/`, `<<`)
  is well-defined. The overflow value is calculated assuming two's
  complement representation; i.e., the result is the unique value *v*
  such that *v* ≡ *r* (mod 2<sup>64</sup>), where *r* is the result of
  operation using arbitrary precision arithmetic.

* Local variable declarations must use the keyword [local](#local-statements),
[session](#session-statements), or [saved](#saved-statements); as in

  ```
  method m() {
      session int call_count = 0;
      saved bool called = false;
      local int n = 0;
      local float f;
      ...
  }
  ```

  Session and saved variables have a similar meaning to static variables as in
  C: they retain value over function calls.
  However, such variables in DML are allocated per device object, and are not
  globally shared between device instances.

  Unlike C, multiple simultaneous variable declaration and
  initialization is done through tuple syntax:
  <pre>
  method m() {
      local (int n, bool b) = (0, true);
      local (float f, void *p);
      ...
  }
  </pre>
* Plain C functions (i.e., not DML methods) can be called using normal
  function call syntax, as in `f(x)`.

  In order to call a C function from DML, three steps are needed:

  * In order for DML to recognize an identifier as a C function, it
    must be declared in DML, using an [`extern`
    declaration](#extern-declarations).

  * In order for the C *compiler* to recognize the identifier when
    compiling generated C code, a function declaration must also be
    declared in a [`header`](#header-declarations) section, or in a
    header file included from this section.

  * In order for the C *linker* to resolve the symbol, a function
    definition must be present, either in a separate C file or in a header or
    [`footer`](#footer-declarations) section.


  **foo.c**

  ```
  int foo(int i)
  {
      return ~i + 1;
  }
  ```

  **foo.h**

  ```
  int foo(int i);
  ```

  **bar.dml**

  ```
  // tell DML that these functions are available
  extern int foo(int);
  extern int bar(int);

  header %{
      // tell generated C that these functions are available
      #include "foo.h"
      int bar(int);  // defined in the DML footer section
  %}

  footer %{
      int bar(int i)
      {
          return -i;
      }
  %}
  ```

  **Makefile**

  ```
  SRC_FILES=foo.c bar.dml
  ```

* Assignments (`=`) are required to be separate statements.
  You are still allowed to assign multiple variables in one statement, as in:
  ```
  i = j = 0;
  ```

* Multiple simultaneous assignment can be performed in one statement
  through tuple syntax, allowing e.g. the following:
  ```
  (i, j) = (j, i);
  ```
  However, such assignments are not allowed to be chained.

* If a method can throw exceptions, or if it has more than one return argument, then the call must be a separate statement. If it has one or more return values, these must be assigned. If a method has multiple return arguments, these are enclosed in a parenthesis, as in:
  ```
  method divmod(int x, int y) -> (int, int) {
      return (x / y, x % y);
  }
  ...
  (quotient, remainder) = divmod(17, 5);
  ```

* Type casts must be written as <code>cast(<em>expr</em>,
  <em>type</em>)</code>.

* Comparison operators and logical operators produce results of type
  `bool`, not integers.

* Conditions in `if`, `for`, `while`, etc. must
  be proper booleans; e.g., `if (i == 0)` is allowed, and `if
  (b)` is allowed if `b` is a boolean variable, but `if
  (i)` is not, if `i` is an integer.

* The `sizeof` operator can only be used on lvalue expressions. To
  take the size of a datatype, the `sizeoftype` operator must be
  used.

* Comma-expressions are only allowed in the head of
  `for`-statements, as in

  ```
  for (i = 10, k = 0; i > 0; --i, ++k) ...
  ```

* `delete` and `throw` can only be used as statements
  in DML, not as expressions.

* `throw` does not take any argument, and `catch` cannot
  switch on the type or value of an exception.

* Type declarations do not allow the use of `union`.
  However, the `extern typedef` construct can be used to achieve
  the same result.  For example, consider the union data type declared in C
  as:

  ```
  typedef union { int i; bool b; } u_t;
  ```

  The data type can be exposed in DML as follows:

  ```
  header %{
      typedef union { int i; bool b; } u_t;
  %}
  extern typedef struct { int i; bool b; } u_t;
  ```

  This will make `u_t` look like a struct to DML, but since union
  and struct syntax is identical in C, the C code generated from uses
  of `u_t` will work correctly together with the definition from
  the `header` declaration.

