<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Register Banks and Registers

This document covers the fundamental building blocks for hardware register modeling in DML: **register banks** and **registers**. These are central to creating device models that expose memory-mapped I/O interfaces.

### Register Banks

A *register bank* (or simply *bank*) is an abstraction that is used to
group *registers* in DML, and to expose these to the outside
world. Registers are exposed to the rest of the simulated system
through the Simics interface `io_memory`, and exposed to scripting and
user interfaces through the `register_view`, `register_view_read_only`,
`register_view_catalog` and `bank_instrumentation_subscribe` Simics interfaces.

It is possible to define *bank arrays* to model a row of similar banks. Each
element in the bank array is a separate configuration object in Simics, and can
thus be individually mapped in a memory space.

Simics configuration objects for bank instances are named like the bank but
with a `.bank` prefix. For instance, if a device model has a declaration `bank
regs[i < 2]` on top level, and a device instance is named `dev` in Simics, then
the two banks are represented in Simics by configuration objects named
`dev.bank.regs[0]` and `dev.bank.regs[1]`.

#### Bank Example

```dml
dml 1.4;

device banks;
param desc = "example bank register";

// Simple register bank with a single register
bank regs {
    register r size 4 @ 0x0000;
}

// Register with custom read method
bank regs2 {
    register r size 4 @ 0x0000 is read {
        method read() -> (uint64) {
            log info: "read from r";
            return 42;
        }
    }
}
```

#### Bank Array Example

```dml
dml 1.4;

device bank_array;
param desc = "example bank array";

bank func[i < 2] {
    register ctrl[j < 2] size 4 @ 4 * j is read {
        method read() -> (uint64) {
            log info: "read from %s -> %#x", qname, this.val;
            return this.val;
        }
    }
}
```

### Registers

A *register* is an object that contains an integer value. Normally, a register
corresponds to a segment of consecutive locations in the address space of the
bank; however, it is also possible (and often useful) to have registers that are
not mapped to any address within the bank. All registers must be part of a
register bank.

Every register has a fixed *size*, which is
an integral, nonzero number of 8-bit bytes. A single register cannot
be wider than 8 bytes. The size of the register is given by the
`size` parameter,
which can be specified either by a normal parameter assignment, as in

```
register r1 {
    param size = 4;
    ...
}
```

or, more commonly, using the following short-hand syntax:

```
register r1 size 4 {
    ...
}
```

which has the same meaning. The default size is provided by the
`register_size`
parameter of the containing register bank, if that is defined.

There are multiple ways to manipulate the value of a register: the simplest
approach is to make use of the `val` member of registers, as in:

```
log info: "the value of register r1 is %d", r1.val;
```

or

```
++r1.val;
```

For more information, see Section
[Register Objects](dml-builtins.html#register-objects).

#### Register Declaration Examples

```dml
dml 1.4;

device regs;
param desc = "example of register";

// Simple register declaration
bank regs {
    register r size 4 @ 0x1000;
}

// Register with low-level read/write methods
bank regs2 {
    register r size 4 @ 0x1000 {
        method read_register(uint64 enabled_bytes, void *aux)-> (uint64) {
            log info: "Reading register r returns a constant";
            return 42;
        }

        method write_register(uint64 value, uint64 enabled_bytes, void *aux){
            log info: "Wrote register r";
            this.val = value;
        }
    }
}

// Register using read/write templates (recommended approach)
bank regs3 {
    register r size 4 @ 0x1000 is (read, write) {
        method read () -> (uint64) {
            log info: "Reading register r returns a constant";
            return 42;
        }

        method write (uint64 value) {
            log info: "Wrote register r";
            this.val = value;
        }
    }
}
```

#### Mapping Addresses To Registers

For a register to be mapped into the internal address space of the
containing bank, its starting address within the bank must be given by
setting the
<code>offset</code>
parameter. The address range occupied by the register is then from
`offset` to `offset` + `size` - 1. The offset
can be specified by a normal parameter assignment, as in

```
register r1 {
    param offset = 0x0100;
    ...
}
```

or using the following short-hand syntax:

```
register r1 @ 0x0100 {
    ...
}
```

similar to the `size` parameter above. Usually, a normal
read/write register does not need any additional specifications apart
from the size and offset, and can simply be written like this:

```
register r1 size 4 @ 0x0100;
```

or, if the bank contains several registers of the same size:

```
bank b1 {
    param register_size = 4;
    register r1 @ 0x0100;
    register r2 @ 0x0104;
    ...
}
```

The translation from the bank address space to the actual value of the
register is controlled by the `byte_order` parameter. When it is set to
`"little-endian"` (the default), the lowest address, i.e., that
defined by `offset`, corresponds to the least significant byte in
the register, and when set to `"big-endian"`, the lowest address
corresponds to the most significant byte in the register.

#### Not Mapping Addresses To Registers

An important thing to note is that registers do not have to be mapped at all.
This may be useful for internal registers that are not directly accessible from
software. By using an unmapped register, you can get the advantages of using
register, such as automatic checkpointing and register fields. This internal
register can then be used from the implementations of other registers, or other
parts of the model.

Historically, unmapped registers were commonly used to store simple device
state, but this usage is no longer recommended &mdash;
[Saved Variables](#saved-variables) should be preferred if possible.
Unmapped registers should only be used if saved variables do not fit a
particular use case.

To make a register unmapped, set the offset to `unmapped_offset`
or use the standard template `unmapped`:

```
register r is (unmapped);
```

#### Register Attributes

For every register, an attribute of integer type is automatically added
to the Simics configuration class generated from the device model. The
name of the attribute corresponds to the hierarchy in the DML model;
e.g., a register named `r1` in a bank named `bank0` will
get a corresponding attribute named `bank0_r1`.

The register value is automatically saved when Simics creates a checkpoint,
unless the `configuration` parameter indicates otherwise.

The value of a register is stored in a member named `val`. E.g., the `r1`
register will store its value in `r1.val`. This is normally the value that is
saved in checkpoints; however, checkpointing is defined by the `get` and `set`
methods, so if they are overridden, then some other value can be saved instead.

### Fields

Real hardware registers often have a number of *fields* with
separate meaning. For example, the lowest three bits of the register
could be a status code, the next six bits could be a set of flags, and
the rest of the bits could be reserved.

To make this easy to express, a `register` object can
contain a number of `field` objects. Each field is defined
to correspond to a bit range of the containing register.

The value of a field is stored in the corresponding bits of the containing
register's storage. The easiest way to access the value of a register or field
is to use the `get` and `set` methods.

The read and write behaviour of registers and fields is in most cases
controlled by instantiating *templates*. There are three
categories of templates:

* Registers and fields where a read or write just updates the
  value with no side-effects, should use the `read`
    and `write` templates, respectively.

* Custom behaviour can be supplied by instantiating
  the `read` or `write` template. The template leaves
    a simple method `read` (or `write`) abstract;
    custom behaviour is provided by overriding the method. There is
    also a pair of templates `read_field`
    and `write_field`, which similarly provide abstract
    methods `read_field` and `write_field`. These
    functions have some extra parameters, making them less convenient
    to use, but they also offer some extra information about the
    access.


* There are many pre-defined templates with for common specialized
  behaviour. The most common ones are `unimpl`, for registers
    or fields whose behaviour has not yet been implemented,
    and `read_only` for registers or fields that cannot be
    written.



A register or field can often instantiate two templates, one for reads
and one for writes; e.g., `read` to supply a read method
manually, and `read_only` to supply a standard write method. If
a register with fields instantiates a read or write template, then the
register will use that behaviour *instead* of descending into
fields. For instance, if a register instantiates
the `read_only` template, then all writes will be captured, and
only reads will descend into its fields.

The register described above could be modeled as follows,
using the default little-endian bit numbering.

```
bank b2 {
    register r0 size 2 @ 0x0000 {
        field status @ [2:0];
        field flags @ [8:3];
        field reserved @ [15:9];
    }
    ...
}
```

Note that the most significant bit number is always the first number (to
the left of the colon) in the range, regardless of whether little-endian
or big-endian bit numbering is used. (The bit numbering convention used
in a source file can be selected by a <code>bitorder</code>
declaration.)

The value of the field can be accessed by using the `get`
and `set` methods, e.g.:

```
log info: "the value of the status field is %d", r0.status.get();
```

#### Field Declaration Examples

```dml
dml 1.4;

device fields;
param desc = "example of field";

param ENABLED = 1;

bank regs {
    register r size 4 @ 0x0000 {
        // Single-bit field
        field status @ [0];
        // Multi-bit field with custom read method
        field counter @ [4:1] is read {
            method read() -> (uint64) {
                log info: "read from counter";
                return default() + 1;
            }
        }
    }
}

method init() {
    // Access field value
    if (regs.r.status.val == ENABLED) {
        // do something
    }
}
```

#### Alternative Field Declaration Syntax

Different ways to declare fields with bit ranges:

```dml
bank regs {
    register a size 4 @ 0x0 {
        field Enable   @ [0:0];   // Explicit single bit range
        field Disable  @ [4:1];   // Multi-bit field
        field Trigger  @ [31:11]; // Upper bits
    }
    register b size 4 @ 0x4 {
        field Enable  @ [0];      // Shorthand for single bit
        field Disable @ [4:1];
        field Trigger @ [31:11];
    }
}
```

#### Field Write Order

Field write order can affect behavior when fields interact:

```dml
bank regs {
    method triggered() {
        log info: "pow!!!";
    }
    register r size 4 @ 0x0000 {
        field Trigger @ [0] is write {
            method write(uint64 value) {
                log info: "Writing Trigger";
                if (Enabled.val)
                    triggered();
            }
        }
        field Enabled @ [1] is write {
            method write(uint64 value) {
                this.val = value;
                log info: "Writing Enabled";
            }
        }
    }
}
```

---

**See Also:**
- [Object Model Overview](006_object-model.md) - Device structure and other object types
- [Templates](008_templates.md) - Reusable register and field templates
- [Saved Variables](013_saved-variables.md) - Alternative for storing device state
