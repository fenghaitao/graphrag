<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## The Object Model

DML is structured around an *object model*, where each DML model
describes a single *device object*, which can contain a number of
*member objects*. Each member object can in its turn have a number of
members of its own, and so on in a nested fashion.

Every object (including the device itself) can also have
[*methods*](#methods-brief), which implement the functionality of the object,
and [*parameters*](#parameters), which are members that describe static
properties of the object.

Each object is of a certain *object type*, e.g., `bank` or
`register`. There is no way of adding user-defined object types in
DML; however, each object is in general locally modified by adding (or
overriding) members, methods and parameters - this can be viewed as
creating a local one-shot subtype for each object.

A DML model can only be instantiated as a whole: Individual
objects can not be instantiated standalone; instead, the whole
hierarchy of objects is instantiated atomically together with the model. This
way, it is safe for sibling objects in the hierarchy to assume each
other's existence, and any method can freely access state from any
part of the object hierarchy.

Another unit of instantiation in DML is the *template*. A template
contains a reusable block of code that can be instantiated in an
object, which can be understood as expanding the template's code into
the object.

Many parts of the DML object model are automatically mapped onto the
Simics *configuration object* model; most importantly, the device
object maps to a Simics configuration class, such that configuration
objects of that class correspond to instances of the DML model, and
the attribute and interface objects of the DML model map to Simics
attributes and interfaces associated with the created Simics
configuration class (See *Simics Model Builder User's Guide* for
details.)

### Device Structure

A device is made up of a number of member objects and methods, where any object
may contain further objects and methods of its own. Many object types only make
sense in a particular context and are not allowed elsewhere:

* There is exactly one [`device`](#the-device) object. It resides on the top
  level.

* Objects of type [`bank`](#register-banks), [`port`](#ports) or
  [`subdevice`](#subdevices) may only appear as part of a `device` or
  `subdevice` object.

* Objects of type [`implement`](#implements) may only appear as part of a
  `device`, `port`, `bank`, or `subdevice` object.

* Objects of type [`register`](#registers) may only appear as part of a `bank`.

* Objects of type [`field`](#fields) may only appear as part of a `register`.

* Objects of type [`connect`](#connects) may only appear as part of a `device`,
  `subdevice`, `bank`, or `port` object.

* Objects of type [`interface`](#interfaces) may only appear directly below a
  `connect` object.

* Objects of type [`attribute`](#attributes) may only appear as part of a
  `device`, `bank`, `port`, `subdevice`, or `implement` object.

* Objects of type [`event`](#events) may appear anywhere **except** as part of a
  `field`, `interface`, `implement`, or another `event`.

* Objects of type [`group`](#groups) are neutral: Any object may contain a
  `group` object, and a `group` object may contain any object that its parent
  object may contain, with the exception that a `group` cannot contain an
  object of type `interface` or `implement`.

### Parameters

Parameters (shortened as "`param`") are a kind of object members that *describe
expressions*. During compilation, any parameter reference will be expanded to
the definition of that parameter. In this sense, parameters are similar to
macros, and indeed have some usage patterns in common - in particular,
parameters are typically used to represent constant expressions.

Like macros, no type declarations are necessary for parameters, and every usage
of a parameter will re-evaluate the expression. Unlike macros, any parameter
definition must be a syntactically valid expression, and every unfolded
parameter expression is always evaluated using the scope in which the
parameter was defined, rather than the scope in which the parameter is
referenced.

Parameters cannot be dynamically updated at run-time; however, a parameter
can be declared to allow it being overridden by later definitions -
see [Parameters detailed](#parameters-detailed).

Within DML's built-in modules and standard library, parameters are used to
describe static properties of objects, such as names, sizes, and offsets. Many
of these are overridable, allowing some properties to be configured by users.
For example, every bank object has a `byte_order` parameter that controls the
byte order of registers within that bank. By default, this parameter is defined
to be `"little-endian"` - but by overriding it, users may specify the byte
order on a bank-by-bank basis.

### Methods
<a id="methods-brief"/>

Methods are object members providing implementation of the functionality of the
object. Although similar to C functions, DML methods can have any number of
input parameters and return values. DML methods also support a basic exception
handling mechanism using `throw` and `try`.

[In-detail description of method declarations are covered in a separate
section.](#methods-detailed)

### The Device

The *device* defined by a DML model corresponds
directly to a Simics *configuration object*, i.e., something
that can be included in a Simics configuration.

In DML's object hierarchy, the device object is represented by the
top-level scope.

The DML file passed to the DML compiler must *start* with a `device`
declaration following the language version specification:

<pre>
dml 1.4;
device <em>name</em>;
</pre>

A `device` declaration may not appear anywhere else, neither in the
main file or in imported files. Thus, the device declaration is
limited to two purposes:
* to give a *name* to the configuration class registered with Simics
* to declare which DML file is the top-level file in a DML model

### Register Banks and Registers

For detailed documentation on register banks, registers, and fields, see 
[Register Banks and Registers](007_registers.md).

This includes:
- Register bank declarations and bank arrays
- Register size, offset, and byte order configuration
- Mapped and unmapped registers
- Register fields and bit ranges
- Read/write behavior and templates

### Attributes

An [`attribute` object](dml-builtins.html#attribute-objects) in DML represents a
Simics configuration object attribute of the device. As mentioned above, Simics
attributes are created automatically for [`register`](#registers) and
[`connect`](#connects) objects to allow external inspection and modification;
explicit `attribute` objects can be used to expose additional data. There are
mainly three use cases for explicit attributes:

* Exposing a parameter for the end-user to configure or
  tweak. Such attributes can often be *required* in order to
  instantiate a device, and they usually come with documentation.

* Exposing internal device state, required for checkpointing to work correctly.
  Most device state is usually saved in registers or saved variables, but
  attributes may sometimes be needed to save non-trivial state such as FIFOs.

* Attributes can also be created as synthetic back-doors for
  additional control or inspection of the device. Such attributes
  are called *pseudo attributes*, and are not saved in
  checkpoints.


An attribute is basically a name with an associated pair of `get` and `set`
functions. The type of the value read and written through the get/set functions
is controlled by the `type` parameter. More information about configuration
object attributes can be found in *Simics Model Builder User's Guide*.

The [`init`](dml-builtins.html#init) template and associated method is often
useful together with `attribute` objects to initialize any associated state.

Four standard templates are provided for attributes: `bool_attr`, `int64_attr`,
`uint64_attr` and `double_attr`. They provide overridable `get` and `set`
methods, and store the attribute's value in a session variable named `val`,
using the corresponding type. For example, if `int64_attr` is used in the
attribute `a`, then one can access it as follows:

```
log info: "the value of attribute a is %d", dev.a.val;
```

These templates also provide an overridable implementation of
[`init()`](dml-builtins.html#init) that initializes the `val` session variable.
The value that `val` is initialized to is controlled by the `init_val`
parameter, whose default definition simply causes `val` to be zero-initialized.

Defining `init_val` is typically the most convenient way of initializing any
attribute instantiating any one of the these templates &mdash; however,
overriding the default `init()` implementation with a custom one may still be
desirable in certain cases. In particular, the definition of `init_val` must be
constant, so a custom `init()` implementation is necessary if `val` should be
initialized to a non-constant value.

Note that using an attribute object purely to store and checkpoint simple
internal device state is not recommended; prefer
[Saved Variables](#saved-variables) for such use cases.

#### Attribute Example

```dml
dml 1.4;

device attr;
param desc = "example of attribute";
import "utility.dml";

// Simple integer attribute using standard template
attribute int_attr is int64_attr "An integer attribute";

// Attribute with custom set method
attribute int_attr {
    method set(attr_value_t value) throws {
        local uint64 before = this.val;
        default(value);
        log info: "Updated from %d to %d", before, this.val;
    }
}
```

### Connects

A [`connect` object](dml-builtins.html#connect-objects)
is a container for a reference to an
arbitrary Simics configuration object. An attribute with the same name
as the connect is added to the Simics configuration class generated
from the device model. This attribute can be assigned a value of type
"Simics object".

A `connect` declaration is very similar to a simple
`attribute` declaration, but specialized to handle
connections to other objects.

Typically, the connected object is expected to implement one or more
particular Simics interfaces, such as `signal`
or `ethernet_common` (see
*Simics Model Builder User's Guide* for details). This is described
using `interface` declarations inside the
`connect`.

Initialization of the connect (i.e., setting the object reference) is
done from outside the device, usually in a Simics configuration
file. Just like other attributes, the parameter
<code>configuration</code> controls whether the value must
be initialized when the object is created, and whether it is
automatically saved when a checkpoint is created.

The actual object pointer, which is of type
<code>conf_object_t*</code> is stored in a `session`
member called `obj`.  This means that to access the current
object pointer in a connect called *otherdev*, you need to
write `otherdev.obj`.

If the `configuration` parameter is not `required`,
the object pointer may have a null value, so any code that tries to
use it must check if it is set first.

This is an example of how a connect can be declared and used:

```
connect plugin {
    param configuration = "optional";
}

method mymethod() {
    if (plugin.obj)
        log info: "The plugin is connected";
    else
        log info: "The plugin is not connected";
}
```

#### Interfaces

In order to use the Simics interfaces that a connected object
implements, they must be declared within the `connect`.
This is done through [`interface` objects](dml-builtins.html#interface-objects).
These name the expected interfaces and may also specify additional properties.

An important property of an interface object is whether or not a
connected object is *required* to implement the interface. This
can be controlled through the interface parameter `required`,
which is `true` by default. Attempting to connect an object
that does not implement the required interfaces will cause a runtime
error. The presence of optional interfaces can be verified by testing
if the `val` member of the interface object has a null
value.

By default, the C type of the Simics interface corresponding to a
particular interface object is assumed to be the name of the object
itself with the string `"_interface_t"` appended. (The C type is
typically a `typedef`:ed name for a struct containing function
pointers).

The following is an example of a connect with two interfaces, one of
which is not required:

```
connect plugin {
    interface serial_device;
    interface rs232_device { param required = false; }
}
```

Calling interface functions is done in the same way as any C function
is called, but the first argument which is the target object
pointer is omitted.

The `serial_device` used above has a function with the
following definition:

```
int (*write)(conf_object_t *obj, int value);
```

This interface function is called like this in DML:

```
method call_write(int value) {
    local int n = plugin.serial_device.write(value);
    // code to check the return value omitted
}
```

#### Connect Example

```dml
dml 1.4;

device connect_device;
param desc = "sample DML device";

import "talk.dml";

connect plugin {
    interface talk {
        param required = true;
    }
}

bank regs {
     register r size 4 @ 0x0000 is read {
        method read() -> (uint64) {
            // Call interface method on connected object
            plugin.talk.hello();
            return 42;
        }
    }
}
```

### Implements

When a device needs to export a Simics interface, this is specified by an
`implement` object, containing the methods that implement
the interface. The name of the object is also used as the name of the
Simics interface registered for the generated device, and the names and
signatures of the methods must correspond to the C functions of the
Simics interface. (A device object pointer is automatically added as the
first parameter of the generated C functions.)

In most cases, a device exposes interfaces by adding `implement` object as
subobjects of named [`port` objects](#ports). A port object often represents a
hardware connection

The C type of the Simics interface is assumed to be the
value of the object's `name` parameter (which defaults to the name of
the object itself), with the string `"_interface_t"` appended.  The C
type is typically a `typedef`:ed name for a struct containing function
pointers.

For example, to implement the `ethernet_common` Simics interface, we can write:

```
implement ethernet_common {
    method frame(const frags_t *frame, eth_frame_crc_status_t crc_status) {
        ...
    }
}
```

This requires that `ethernet_common_interface_t` is defined as a struct type
with a field `frame` with the function pointer type
`void (*)(conf_object_t *, const frags_t *, eth_frame_crc_status_t)`.

Definitions of all standard Simics interface types are available as DML files named like the corresponding C header files;
for instance, the `ethernet_common` interface can be imported as follows:
```
import "simics/devs/ethernet.dml"
```

#### Implement Example

```dml
dml 1.4;

device impl;
param desc = "sample DML device";

import "simics/devs/ethernet.dml";

implement ethernet_common {
    // Called when a frame is received from the network.
    method frame(const frags_t *frame, eth_frame_crc_status_t crc_status) {
        if (crc_status == Eth_Frame_CRC_Mismatch) {
            log info, 2: "Bad CRC for received frame";
        }
        receive_packet(frame);
    }
}

method receive_packet(const frags_t *frame) {}
```

### Events

An *event* object is an encapsulation of a Simics event that can
be posted on a processor time or step queue. The location of event
objects in the object hierarchy of the device is not important, so an
event object can generally be placed wherever it is most convenient.

An event has a built-in `post` method, which inserts the
event in the default queue associated with the device. An event also
defines an abstract method `event`, which the user must
implement. That method is called when the event is triggered.

An event must instantiate one of six predefined
templates: `simple_time_event`, `simple_cycle_event`,
`uint64_time_event`, `uint64_cycle_event`,
`custom_time_event` or `custom_cycle_event`. The choice
of template affects the signature of the `post`
and `event` methods: In a time event, the delay is specified
as a floating-point value, denoting number of seconds, while in a
cycle event, the delay is specified in CPU cycles.

A posted event may have data associated with it. This data is given to
the `post` method and is provided to the `event`
callback method. They type of data depends on the template used: No
data is provided in simple events, and in uint64 events it is provided
as a uint64 parameter. In custom events, data is provided as
a `void *` parameter, and extra
methods `get_event_info` `set_event_info`
and `destroy` must be provided in order to provide proper
checkpointing of the event.

#### Event Example

```dml
dml 1.4;

device events;
param desc = "example of event";

// Define a time-based event with uint64 data
event future is uint64_time_event {
    method event(uint64 data) {
        log info, 1 : "The future is here";
    }
}

method my_method() { }

method init() {
    local uint64 some_data = 0;
    
    // Post an event 0.1 seconds in the future
    future.post(0.1, 0);
    
    // Remove a posted event
    future.remove(some_data);
    
    // Check if event is posted
    local bool is_this_event_posted = future.posted(some_data);
    
    // Get time until event fires
    local double when_is_this_event_posted = future.next(some_data);
    
    // Alternative: use 'after' statement for simple delayed calls
    // Call my_method() after 10.5 seconds
    after 10.5 s: my_method();
}
```

### Groups

Objects of type `attribute`, `connect`, `event`, `field`, `register`, `bank`,
`port` and `subdevice` can be organized into *groups*. A group is a neutral
object, which can be used just for namespacing, or to help structuring an array
of a collection of objects. Groups may appear anywhere, but are most commonly
used to group registers: If a bank has a sequence of blocks, each containing
the same registers, it can be written as a group array. In the following
example eight homogeneous groups of registers are created, resulting in
8&#215;6 instances of register `r3`.

```
bank regs {
    param register_size = 4;
    group blocks[i < 8] {
        register r1 @ i * 32 + 0;
        register r2 @ i * 32 + 4;
        register r3[j < 6] @ i * 32 + 8 + j * 4;
    }
}
```

Another typical use of `group` is in combination with a
template for the group that contains common registers and
more that are shared between several groups, as in the following
example.

```
template weird {
    param group_offset;
    register a size 4 @ group_offset is (read, write);
    register b size 4 @ group_offset + 4 is (read, write) {
        method read() -> (uint64) {
            // When register b is read, return a
            return a.val;
        }
    }
}

bank regs {
    group block_a is (weird) { param group_offset = 128; }
    group block_b is (weird) { param group_offset = 1024; }
}
```

In addition, groups can be nested.

```
bank regs {
    param register_size = 4;
    group blocks[i < 8] {
        register r1 @ i * 52 + 0;
        group sub_blocks[j < 4] {
            register r2 @ i * 52 + j * 12 + 4;
            register r3[k < 3] @ i * 52 + j * 12 + k * 4 + 8;
        }
    }
}
```

Banks, ports and subdevices can be placed inside groups; in this case, the
Simics configuration object that represents the bank, port or subdevice will be
placed under a namespace object; for instance, if a device with `group g { bank
regs; }` is instantiated as `dev`, then the bank is represented by an object
`dev.g.bank.regs`, where `g` and `bank` are both `namespace` objects.

As groups have no special properties or restrictions, they can be used as a tool
for building abstractions &mdash; in particular in combination with templates.

For example, a template can be used to create an abstraction for finite state
machine objects, by letting users create FSMs by declaring group objects
instantiating that template. FSM states can also be represented through a
template instantiated by groups.

#### Finite State Machines using groups

The following demonstrates a simple example of how a finite state machine may be implemented using templates and group objects:

```
// Template for finite state machines
template fsm is init {
    saved fsm_state curr_state;

    // The initial FSM state.
    // Must be defined by any object instantiating this template.
    param init_fsm_state : fsm_state;

    shared method init() default {
        curr_state = init_fsm_state;
    }

    // Execute the action associated to the current state
    shared method action() {
        curr_state.action();
    }
}

// Template for states of an FSM. Such states must be sub-objects
// of an FSM.
template fsm_state {
    param parent_fsm : fsm;
    param parent_fsm = cast(parent, fsm);

    // The action associated to this state
    shared method action();

    // Transitions the parent FSM to this state
    shared method set() {
        parent_fsm.curr_state = cast(this, fsm_state);
    }
}
```

These templates can then be used as follows:

```
group main_fsm is fsm {
    param init_fsm_state = cast(init_state, fsm_state);

    group init_state is fsm_state {
        method action() {
          log info: "init_state -> second_state";
          // Transition to second_state
          second_state.set();
        }
    }

    group second_state is fsm_state {
        method action() {
          log info: "second_state -> final_state";
          // Transition to final_state
          final_state.set();
        }
    }

    group final_state is fsm_state {
        method action() {
            log info: "in final_state";
        }
    }
}

method trigger_fsm() {
    // Execute the action of main_fsm's current state.
    main_fsm.action();
}
```

### Ports

An interface port is a structural element that groups implementations
of one or more interfaces. When one configuration object connects to
another, it can connect to one of the target object's ports, using the
interfaces in the port. This way, the device model can expose
different interfaces to different objects.

Sometimes a port is as simple as a single pin, implementing
the `signal` interface, and sometimes it can be more complex,
implementing high-level communication interfaces.

It is also possible to define port arrays that are indexed
with an integer parameter, to model a row of similar connectors.

In Simics, a port is represented by a separate configuration object, named like
the port but with a `.port` prefix. For instance, if a device model has a
declaration `port p[i<2]` on top level, and a device instance is named `dev` in
Simics, then the two ports are represented in Simics by objects named
`dev.port.p[0]` and `dev.port.p[1]`.

#### Port Example

```dml
dml 1.4;

device ports;
param desc = "sample DML device";

import "simics/devs/signal.dml";

// Define signal ports for pins
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

### Subdevices

A subdevice is a structural element that represents a distinct subsystem of the
device. Like a `group`, a subdevice can be used to group a set of related
banks, ports and attributes, but a subdevice is presented to the end-user as a
separate configuration object. If a subdevice contains `attribute` or `connect`
objects, or `saved` declarations, then the corresponding configuration
attributes appears as members of the subdevice object rather than the device.
