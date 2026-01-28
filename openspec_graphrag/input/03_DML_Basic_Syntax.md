# DML Basic Syntax and Structure

## Overview

This document covers the fundamental DML syntax, device structure, compilation setup, and basic programming constructs needed to write Simics device models.

## Table of Contents

1. [DML Compilation Setup](#dml-compilation-setup)
2. [Basic DML Syntax](#basic-dml-syntax)
3. [Device Structure](#device-structure)
4. [DML Core Constructs](#dml-core-constructs)
5. [File Organization](#file-organization)
6. [Naming Conventions](#naming-conventions)

---

## DML Compilation Setup

### Required Compiler Flags

The key to successful DML compilation is using the correct compiler flags:

```bash
dmlc --simics-api=7 -I ../linux64/bin/dml/api/7/1.4 -I ../linux64/bin/dml/1.4 input.dml output
```

**Critical Points:**
- `--simics-api=7`: Specifies Simics API version
- `-I ../linux64/bin/dml/api/7/1.4`: Include path for Simics API
- `-I ../linux64/bin/dml/1.4`: Include path for DML builtins

### Environment Setup

Ensure the DML compiler has UTF-8 mode enabled:

```bash
# Method 1: Environment variable
export PYTHONUTF8=1

# Method 2: Modified dmlc script (recommended)
exec env PYTHONUTF8=1 "$_MINI_PYTHON" "$DMLC_DIR/dml/python" "$@"
```

---

## Basic DML Syntax

### DML Language Overview

DML (Device Modeling Language) is an object-oriented, C-like language designed for modeling hardware devices in Simics. Each device is implemented as a module containing one or multiple .dml files.

### Device Module Structure

Each device module has:
- A **main .dml file** that imports all dependencies
- **One device definition** per module (across all imported files)
- See [Minimal DML Device](#minimal-dml-device) below for a basic example

### Object Hierarchy and Scope

The **device** is the root object in DML and can be referenced as:
- `dev` - explicit device reference (preferred in sub-object scopes)
- `this` - refers to current object (device at root, sub-object within sub-objects)

#### Device Sub-Objects

The device contains several types of sub-objects:

| Sub-Object | Purpose | Example |
|------------|---------|---------|
| `port` | Input interfaces (receive signals/data) | `reset_in` |
| `connect` | Output interfaces (send signals/data) | `reset_out` |
| `attribute` | Persistent device state | `counter`, `enabled` |
| `event` | Timer objects for scheduled hardware tasks | `timeout_event` |
| `bank` | Memory-mapped register interface (most important) | `regs` |

#### Bank Sub-Objects

The `bank` object hosts register definitions and contains:
- `register` - 32-bit or 64-bit memory locations matching hardware specifications
- `field` - Bit ranges within registers (minimal data definition unit)

**Note**: Both `register` and `field` can be treated as specialized attributes.

#### Scope Rules

**CRITICAL**: Understanding scope is essential for correct DML code:

1. **At device scope** (root level):
   - `this` or `dev` refers to the device
   - Access sub-objects directly: `attribute_name`, `bank_name`, etc.

2. **Within sub-object scope** (port, connect, attribute, event, bank):
   - `this` refers to the sub-object itself
   - Use `dev` to reference the device: `dev.attribute_name`, `dev.bank_name`

3. **Within register/field scope** (inside bank):
   - `this` refers to the register/field itself
   - Access parent bank: `bank_name` (direct reference from same bank context)
   - Access device: `dev.attribute_name`, `dev.bank_name`, `dev.event_name`
   - Access sibling registers: `bank_name.register_name` or from device scope `dev.bank_name.register_name`
   - **Important**: Python syntax `dev_name.bank.<bank_name>` is only for Python scripts; in DML files, always use `dev.<bank_name>` or `<bank_name>` directly (no `.bank.` prefix)

### Object Declaration Syntax

```dml
// Port - input interface
port port_name {
    // port-specific implementation
}

// Connect - output interface
connect connect_name {
    // connect-specific implementation
}

// Attribute - persistent state
attribute attr_name {
    // attribute-specific configuration
}

// Event - hardware timer
event event_name {
    // event-specific implementation
}

// Bank - register interface
bank bank_name {
    register reg_name1 @ 0x00 {
        field fld_name1 @ [0] {
            // field-specific behavior
        }
        field fld_name2 @ [1] {
            // field-specific behavior
        }
    }
}
```

### Accessing Sub-Objects from Device Scope

```dml
method example_access_patterns() {
    // Accessing attributes
    dev.attr_name.val = 0;
    
    // Accessing registers
    dev.bank_name.reg_name1.val = 10;
    
    // Accessing fields
    dev.bank_name.reg_name1.fld_name1.val = 3;
}
```

### Common Attribute Templates

Use built-in templates for simple attribute types:

```dml
attribute is_enabled is bool_attr {
    param documentation = "Device enable state";
}

attribute counter is uint64_attr {
    param documentation = "Operation counter";
}

attribute elapsed_time is double_attr {
    param documentation = "Elapsed time in seconds";
}
```

### Port Definitions

Ports provide input interfaces and must specify the interface type:

```dml
// Empty port as connection point
port dummy_port {
}

// Port with signal interface
port reset_in {
    interface signal;
}
```

### Connect Definitions

Connects provide output interfaces, either empty (for linking) or implementing interfaces:

```dml
// Empty connect as connection point
connect dummy_conn {
}

// Connect implementing signal interface
connect reset_out {
    implement signal {
        method signal_raise() {
            log info: "Raising reset signal";
            // Concrete implementation
        }
        
        method signal_lower() {
            log info: "Lowering reset signal";
            // Concrete implementation
        }
    }
}
```

### Interface Overview

Interfaces are Simics pre-defined function-like structures that define method signatures for device communication. Common interfaces include:
- `signal` - For binary signals (raise/lower)
- `simple_interrupt` - For interrupt handling
- `io_memory` - For memory-mapped I/O

### Device Connections (Python)

**Important**: Device connections are made in Python scripts, not in DML code.

```python
import conf

# Connect two devices
dev1 = conf.my_device1
dev2 = conf.my_device2

# Connect output to input (must implement same interface, e.g., 'signal')
dev1.reset_out = dev2.port.reset_in

# Call interface methods on connect object
dev1.reset_out.iface.signal.signal_raise()

# Call interface methods on port object (note the 'port.' prefix)
dev2.port.reset_in.iface.signal.signal_raise()
```

**Key Differences**:
- **Connect reference**: `<dev_name>.<connect_name>`
- **Port reference**: `<dev_name>.port.<port_name>` (note the `port.` prefix)
- **Interface method invocation**: `<object>.iface.<interface_name>.<method_name>()`

### Minimal DML Device

```dml
dml 1.4;

device simple_device;

param classname = "simple_device";
param desc = "A simple device for learning";
```

**Key Points:**
- Start with `dml 1.4;`
- Device declaration is a single line: `device device-name;`
- **NO braces after device declaration**
- Parameters go at top level, not inside device blocks

### Common Imports

```dml
dml 1.4;

device my_device;

import "simics/device-api.dml";  // Always needed for devices
```

---

## Device Structure

### Correct vs. Incorrect Syntax

❌ **WRONG**:
```dml
device my_device {
    param classname = "my_device";
    // ...
}
```

✅ **CORRECT** (DML 1.4 style):
```dml
device my_device;

param classname = "my_device";
param desc = "Device description";
```

### Memory-Mapped Device with Registers

```dml
dml 1.4;

device uart_device;

import "simics/device-api.dml";

param classname = "uart_device";
param desc = "Simple UART device";

bank regs {
    param function = 0x3f8;        // Base address
    param register_size = 1;       // 1 byte registers

    register data @ 0x00 {
        param size = 1;
        param desc = "Data register";

        method write(uint64 value) {
            log info: "UART data write: 0x%02x", value;
        }

        method read() -> (uint64 value) {
            log info: "UART data read";
            return 0x00;
        }
    }

    register status @ 0x05 {
        param size = 1;
        param desc = "Line status register";
        param init_val = 0x60;  // TX empty and ready
    }
}
```

---

## DML Core Constructs

### Device Declaration

Each DML file mentioned in the module's Makefile defines a Simics class automatically. The class name is provided by the device statement at the beginning of the DML file.

```dml
device my_device;
```

**Important**: `device` statements must be placed immediately after the DML version declaration. Only one device statement is allowed per device (including all imported DML files).

### Parameters

Parameters are mostly compile-time constant-valued object members. You can only set their value once. A parameter can be set to a value of any of the types integer, float, string, bool, list, reference or undefined. The type is automatically set from the value.

```dml
param classname = "my_device";
param desc = "This is my device";

method print_info() {
    log info: "Device description: %s", desc;
}
```

### Attributes

An attribute declaration, including name and type. If the type of the attribute is simple then using a built-in template is advised, this will setup the storage for the attribute and provide default set and get methods.

```dml
// A simple integer attribute with built-in storage and methods
attribute counter is int64_attr {
    param documentation = "A sample counter attribute";
}

// A complex attribute with custom storage and methods
attribute add_counter is write_only_attr {
    param documentation = "A sample pseudo attribute";
    param type = "i";

    method set(attr_value_t val) throws {
        counter.val += SIM_attr_integer(val);
    }
}
```

### Banks and Registers

DML uses registers and banks to model hardware registers. Banks represent continuous address ranges containing registers. The registers are mapped in their banks with an offset and size.

```dml
bank regs {
    register r0 size 4 @ 0x0000;
    register r1 size 4 @ 0x0004;
    register r2 size 4 @ 0x0008;
}
```

**Customizing Register Behavior:**

```dml
bank regs {
    // Customize with read_register and write_register methods
    register r0 {
        method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
            log info: "Reading register r returns a constant";
            return 42;
        }

        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            log info: "Wrote register r";
            this.val = value;
        }
    }
    
    // Or customize with read and write templates
    register r1 is (read, write) {
        method read() -> (uint64) {
            log info: "Reading register r returns a constant";
            return 42;
        }

        method write(uint64 value) {
            log info: "Wrote register r";
            this.val = value;
        }
    }
    
    // Register with fields, behavior customized at field level
    register r2 {
        field status @ [0];
        field counter @ [4:1] is read {
            method read() -> (uint64) {
                log info: "read from counter";
                return default() + 1;
            }
        }
    }
}
```

### Interfaces

Interfaces is the mechanism used in Simics when Simics objects, such as device models, need to communicate with each other. A DML device can both implement interfaces to provide additional services which other devices and objects can call, and call methods in interfaces implemented by other objects.

#### Using Interfaces (Outgoing Connections)

```dml
connect irq_dev {
    param documentation = "The device that interrupts are sent to.";
    param configuration = "required";
    interface signal;
}

method trigger_interrupt() {
    if (!irq_raised.val && irq_dev.obj) {
        log info, 3: "Raising interrupt";
        irq_dev.signal.signal_raise();
    }
}
```

**Python connection example:**
```python
dev = SIM_create_object("my_device", "my_device_instance")
intc = SIM_get_object("irq_device", "interrupt_controller")
dev.irq_dev = intc

# if the interrupt signal interface is implemented as a port
dev.irq_dev = (intc, "input_levels")
```

#### Implementing Interfaces (Incoming Connections)

```dml
implement ethernet_common {
    // Called when a frame is received from the network.
    method frame(const frags_t *frame, eth_frame_crc_status_t crc_status) {
        if (crc_status == Eth_Frame_CRC_Mismatch) {
            log info, 2: "Bad CRC for received frame";
        }
        receive_packet(frame);
    }
}

port pin0 {
    implement signal {
        method signal_raise() {
            log info: "pin0 raised";
        }
        method signal_lower() {
            log info: "pin0 lowered";
        }
    }
}

port pin1 {
    implement signal {
        method signal_raise() {
            log info: "pin1 raised";
        }
        method signal_lower() {
            log info: "pin1 lowered";
        }
    }
}
```

### Templates

Templates are a powerful tool when programming in DML. The code in a template can be used multiple times. A template can also implement other templates.

```dml
template spam is write {
    method write(uint64 value) {
        log error: "spam, spam, spam, ...";
    }
}

bank regs {
    // [...]
    register A size 4 @ 0x0 is spam;
}
```

### Methods

Methods are similar to C functions, but also have an implicit (invisible) parameter which allows them to refer to the current device instance, i.e., the Simics configuration object representing the device.

```dml
method m1() -> () {...}
method m2(int a) -> () {...}
method m3(int a, int b) -> (int) {
    return a + b;
}
method m4() -> (int, int) {
    ...;
    return (x, y);
}
method m5(int x) -> (int) throws {
    if (x < 0)
        throw;
    return x * x;
}
```

**Calling methods with struct parameters:**
```dml
typedef struct {
    int x;
    int y;
} struct_t;

method copy_struct(struct_t *tgt, struct_t src) {
    *tgt = src;
}

method m() {
    local struct_t s;
    copy_struct(&s, {1, 4});
    copy_struct(&s, {.y = 1, .x = 4});
    copy_struct(&s, {.y = 1, ...}); // Partial designated initializer
}
```

### Session and Saved Variables

A **session** declaration creates a number of named storage locations for arbitrary run-time values. The names belongs to the same namespace as objects and methods.

A **saved** declaration creates a named storage location for an arbitrary run-time value, and automatically creates an attribute that checkpoints this variable.

```dml
// session declarations
session int id = 1;
session bool active;
session double table[4] = {0.1, 0.2, 0.4, 0.8};
session (int x, int y) = (4, 3);
session conf_object_t *obj;
typedef struct { int x; struct { int i; int j; } y; } struct_t;
session struct_t s = { .x = 1, .y = { .i = 2, .j = 3 } }

// saved declarations (checkpointed)
saved int id = 1;
saved bool active;
saved double table[4] = {0.1, 0.2, 0.4, 0.8};
```

---

## File Organization

### Recommended Project Structure

```
simics-project/
├── modules/
│   ├── device1/
│   │   ├── device.dml
│   │   └── Makefile
│   └── device2/
│       ├── device.dml
│       └── Makefile
├── common/
│   └── device-common.dml
└── Makefile
```

---

## Naming Conventions

- **Device names**: lowercase_with_underscores
- **Bank names**: lowercase_with_underscores
- **Register names**: descriptive_uppercase
- **Field names**: descriptive_camelCase
- **Parameters**: lowercase or camelCase
- **Methods**: lowercase_with_underscores

---

## Documentation Best Practices

Always include meaningful descriptions:

```dml
param desc = "Detailed description of what this device does";

register CONTROL @ 0x00 {
    param desc = "Main control register - bit 0 enables device";
}
```

---

## Error Handling

```dml
method write(uint64 value) {
    if (value > 0xFF) {
        log error: "Invalid value written to 8-bit register: 0x%x", value;
        return;
    }
    this.val = value;
}
```

---

## Logging

Use appropriate log levels:

```dml
log info: "Device initialized";
log warning: "Unusual register access pattern";
log error: "Invalid operation attempted";
```

---

## Quick Reference: Minimal Device Template

```dml
dml 1.4;

// `device` statements must be placed immediately after the DML version declaration
// Only one device statement is allowed per device (including all imported DML files)
device DEVICE_NAME;

import "simics/device-api.dml";

param classname = "DEVICE_NAME";
param desc = "Device description";

// Add banks, registers, methods here
```

---

**Document Status**: ✅ Complete  
**Extracted From**: DML_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Tested With**: Simics 7.57.0, DML 1.4, API version 7
