<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## In Each Declarations

In Each declarations are a convenient mechanism to apply a
pattern to a group of objects. The syntax is:

`in each` (`template-name`, ...) `{`
`body` `}`

where `template-name` is the name of a template
and `body` is a list of object statements, much like the body
of a template. The statements in `body` are expanded in any
subobjects that instantiate the template `template-name`,
either directly or indirectly. If more than
one `template-name` is given, then the body will be expanded
only in objects that instantiate *all* the listed templates.

The `in each` construct can be used as a convenient way to
express when many objects share a common property. For
example, a bank can contain the following to conveniently set the size
of all its registers:
```
in each register { param size = 2; }
```

Declarations in an `in each` block will override any
declarations in the extended template. Furthermore, declarations in
the scope that contains an `in each` statement, will override
declarations from that `in each` statement. This can be used
to define exceptions for the `in each` rule:
```
bank regs {
    in each register { param size default 2; }
    register r1 @ 0;
    register r2 @ 2;
    register r3 @ 4 { param size = 1; }
    register r4 @ 5 { param size = 1; }
}
```

An `in each` block is only expanded in subobjects; the
object where the `in each` statement is present is
unaffected even if it instantiates the extended template.

An `in each` statement with multiple template names can be used
to cause a template to act differently depending on context:
```
template greeting { is read; }
template field_greeting is write {
    method write(uint64 val) {
        log info: "hello";
    }
}
in each (greeting, field) { is field_greeting; }
template register_greeting is write {
    method write(uint64 val) {
        log info: "world";
    }
}
in each (greeting, register) { is register_greeting; }

bank regs {
    register r0 @ 0 {
        // logs "hello" on write
        field f @ [0] is (greeting);
    }
    // logs "world" on write
    register r1 @ 4 is (greeting);
}
```

