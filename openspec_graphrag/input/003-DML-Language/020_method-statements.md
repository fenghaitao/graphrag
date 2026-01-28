<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Method Statements

All ISO C statements are available in DML, and have the same semantics
as in C. Like ordinary C expressions, all DML expressions can also be
used in expression-statements.

DML adds the following statements:

### Assignment Statements
<pre>
<em>target1</em> [= <em>target2</em> = <em>...</em>] = <em>initializer</em>;
(<em>target1</em>, <em>target2</em>, ...) = <em>initializer</em>;
</pre>

Assign values to targets according to an initializer. Unlike C, assignments are
not expressions, and the right-hand side can be any initializer &mdash; such as
compound initializers (<tt>{<em>...</em>}</tt>) for struct-like types.

The first form is chaining assignments. The initializer is executed once and
the value it evaluates to is assigned to each target.

The second form is multiple simultaneous assignment. The initializer describes
multiple values &mdash; one for each target. This can be done either through:
* Providing an initializer for each target through tuple syntax, e.g.:
```
(a, i) = (false, 4);
```
* Performing a method call where each target is a return value recipient, e.g.:
```
method m() -> (bool, int) {
    ...
}
```
```
(a, i) = m();
```

Targets are updated simultaneously, meaning it's possible to e.g. swap the
contents of variables through the following:
```
(a, b) = (b, a)
```

### Local Statements
<pre>
local <em>type</em> <em>identifier</em> [= <em>initializer</em>];
local (<em>type1</em> <em>identifier1</em>, <em>type2</em> <em>identifier2</em>, <em>...</em>) [= <em>initializer</em>];
</pre>

Declares one or multiple local variables in the current scope. The right-hand
side is an initializer, meaning, for example, that compound initializers
(<tt>{<em>...</em>}</tt>) can be used.

The initializer must provide the exact number of values needed to initialize
the variables, and they must be of compatible type. Multiple values can be
provided either through:
* Providing an initializer for each variable through tuple syntax, e.g.:
```
local (bool a, int i) = (false, 4);
```
* Performing a method call where each return value initializes a variable, e.g.:
```
method m() -> (bool, int) {
    ...
}
```
```
local (bool a, int i) = m();
```

In the absence of explicit initializer expressions, a default
"all zero" initializer will be applied to each declared object.

### Session Statements
<pre>
session <em>type</em> <em>identifier</em> [= <em>initializer</em>];
session (<em>type1</em> <em>identifier1</em>, <em>type2</em> <em>identifier2</em>, <em>...</em>) [= (<em>initializer1</em>, </em>initializer2</em>, <em>...</em>)];
</pre>

Declares one or multiple [session variables](#session-variables) in the current
scope.
Note that initializers of such variables are evaluated *once* when
initializing the device, and thus must be a compile-time constant.

### Saved Statements
<pre>
saved <em>type</em> <em>identifier</em> [= <em>initializer</em>];
sabed (<em>type1</em> <em>identifier1</em>, <em>type2</em> <em>identifier2</em>, <em>...</em>) [= (<em>initializer1</em>, </em>initializer2</em>, <em>...</em>)];
</pre>

Declares one or multiple [saved variables](#saved-variables) in the current
scope.
Note that initializers of such variables are evaluated *once* when
initializing the device, and thus must be a compile-time constant.


### Return Statements
<pre>
return [<em>initializer</em>];
</pre>

Returns from method with the value(s) specified by the argument.
Unlike C, the argument is an *initializer*, meaning, for example, return
values of struct-like type can be constructed using <tt>{<em>...</em>}</tt>.

The initializer must provide the exact number of values corresponding as the
return values of the method, and they must be of compatible type. Multiple
values can be provided either through:
* Providing an initializer for each return value through tuple syntax, e.g.:
```
method m() -> (bool, int) {
    return (false, 4);
}
```
* Performing a method call and propagating the return values:
```
method n() -> (bool, int) {
    return m();
}
```

### Delete Statements

<pre>
delete <em>expr</em>;
</pre>

Deallocates the memory pointed to by the result of evaluating
*`expr`*. The memory must have been allocated with the
`new` operator, and must not have been deallocated previously.
Equivalent to `delete` in C++; however, in DML, `delete`
can only be used as a statement, not as an expression.

### Try Statements

<pre>
try <em>protected-stmt</em> catch <em>handle-stmt</em>
</pre>

Executes *`protected-stmt`*; if that completes normally,
the whole `try`-statement completes normally. Otherwise,
*`handle-stmt`* is executed. This is similar to exception
handling in C++, but in DML there is only one kind of exception. Note
that Simics C-exceptions are not handled. See also `throw`.

### Throw Statements

```
throw;
```

Throws (raises) an exception, which may be caught by a
`try`-statement. This is
similar to `throw` in C++, but in DML it is not possible to
specify a value to be thrown. Furthermore, in DML,
`throw` is a statement, not an expression.

If an exception is not caught inside a method body, then the method
must be declared as `throws`, and the exception is propagated
over the method call boundary.

### Method Calls

<pre>
(<em>d1</em>, ... <em>dM</em>) = <em>method</em>(<em>e1</em>, ... <em>eN</em>);
</pre>

A DML method is called similarly as a C function, with the exception that you
must have assignment destinations according to the number of return values of
the method. Here a DML method is called with input arguments *`e1`*, ... *`eN`*,
assigning return values to destinations *`d1`*, ... *`dM`*. The destinations are
usually variables, but they can be arbitrary L-values (even bit slices) as long
as their types match the method signature.

If the method has no return value, the call is simply expressed as:

```
p(...);
```

A method with exactly one return value can also be called in any
expression, unless it is an inline method, or a method that can throw
exceptions. For example:

```
method m() -> (int) { ... }
...
if (m() + i == 13) { ... }
```

A method call (even if it is throwing or has multiple return values) can be used
as an initializer in any context that accepts non-constant initializers; i.e.,
in [assignment statements](#assignment-statements) (as shown above), [local
variable declarations](#local-statements), and [return
statements](#return-statements). For example:
```
// declare multiple variables, and initialize them from one method call
local (int i, uint8 j) = m(e1);

// Propagate all return values from a method call as the return values of the
// caller.
return m(e1)
```

### Template-Qualified Method Implementation Calls
Every object, as well as [every template type](#templates-as-types), has a
`templates` member to allow for calling _particular_ implementations of that
object's methods, as opposed to only the final overriding implementations
that are reachable directly. Specifically, `templates` allows for invoking any
particular implementation as provided by a specified template instantiated by
the object. Such invocations are called _template-qualified method
implementation calls_, and are made as follows:
```
template t {
    method m() default {
        log info: "implementation from 't'"
    }
}

template u is t {
    method m() default {
        log info: "implementation from 'u'"
    }
}

group g is u {
    method m() {
        log info: "final implementation"
    }
}

method call_ms() {
    // Logs "final implementation"
    g.m();
    // Logs "implementation from 'u'"
    g.templates.u.m();
    // Logs "implementation from 't'"
    g.templates.t.m();
}
```

Template-qualified method implementation calls are primarily meant as a way
for an overriding method to reference overridden implementations, *even when*
the implementations are provided by hierarchically unrelated templates such that
`default` can't be used (see [Resolution of
overrides](#resolution-of-overrides).) In particular, this typically allows for
ergonomically resolving conflicts introduced when multiple orthogonal templates
are instantiated, as long as all conflicting implementations are overridable,
and one of the following is true:
* The implementations can be combined together by calling each one of them, as
  long as that can be done without risking e.g. side-effects being duplicated.
* The implementations can be combined by choosing one particular template's
  implementation to invoke (typically the one most complex), and then adding
  code around that implementation call in order to replicate the behaviour of
  the implementations of the other templates. Ideally, the other templates would
  provide methods that may be leveraged so that their behaviour may be
  replicated without the need for excessive boilerplate.

The following is an example of the first case:
```
template alter_write is write {
    method write(uint64 written) {
        default(alter_write(written));
    }

    method alter_write(uint64 curr, uint64 written) -> (uint64);
}

template gated_write is alter_write {
    method write_allowed() -> (bool) default {
        return true;
    }

    method alter_write(uint64 curr, uint64 written) -> (uint64) default {
        return write_allowed() ? written : curr;
    }
}

template write_1_clears is alter_write {
    method alter_write(uint64 curr, uint64 written) -> (uint64) default {
        return curr & ~written;
    }
}

template gated_write_1_clears is (gated_write, write_1_clears) {
    method alter_write(uint64 curr, uint64 written) default {
        local uint64 new = this.templates.write_1_clears.alter_write(
            curr, written);
        return this.templates.gated_write.alter_write(curr, new);
    }
}

// Resolve the conflict introduced whenever the two orthogonal templates are
// instantiated by also instantiating gated_write_1_clears when that happens
in each (gated_write, write_1_clears) { is gated_write_1_clears; }
```

The following is an example of the second case:
```
template very_complex_register is register {
    method write_register(uint64 written, uint64 enabled_bytes,
                          void *aux) default {
        ... // An extremely complicated implementation
    }
}

template gated_register is register {
    method write_allowed() -> (bool) default {
        return true;
    }

    method on_write_attempted_when_not_allowed() default {
        log spec_viol: "%s was written to when not allowed", qname;
    }

    method write_register(uint64 written, uint64 enabled_bytes,
                          void *aux) default {
        if (write_allowed()) {
            default(written, enabled_bytes, aux);
        } else {
            on_write_attempted_when_not_allowed();
        }
    }
}

template very_complex_gated_register is (very_complex_register,
                                         gated_register) {
    // No sensible way to combine the two implementations by calling both.
    // Even if there were, calling both implementations would cause each field
    // of the register to be written to multiple times, potentially duplicating
    // side-effects, which is undesirable.
    // Instead, very_complex_register is chosen as the base implementation
    // called, and the behaviour of gated_register is replicated around that
    // call.
    method write_register(uint64 written, uint64 enabled_bytes,
                          void *aux) default {
        if (write_allowed()) {
            this.templates.very_complex_register.write_register(
                written, enabled_bytes, aux);
        } else {
            on_write_attempted_when_not_allowed();
        }
    }
}

in each (gated_register, very_complex_register) {
    is very_complex_gated_register;
}
```

A template-qualified method implementation call is resolved by using
the method implementation provided to the object by the named template.
If no such implementation is provided (whether it be because the template does
not specify one, or specifies one which is not provided to the object due to its
definition being eliminated by an [`#if`](#conditional-objects)), then the
ancestor templates of the named template are recursively searched for the
highest-rank (most specific) implementation provided by them. If the ancestor
templates provide multiple hierarchically unrelated implementations, then the
choice is ambiguous and the call will be rejected by the compiler. In this case,
the modeller must refine the template-qualified method implementation call to
name the ancestor template whose implementation they would like to use.

A template-qualified method implementation call done via [a value of template
type](#templates-as-types) functions differently compared to compile-time
object references. In particular, `this.templates` within the bodies of `shared`
methods functions differently. The specified template must be an ancestor
template of the value's template type, the <tt>object</tt> template, or the
template type itself; furthermore, the specified template **must provide or
inherit a `shared` implementation of the named method**. It is not sufficient
that the method is simply _declared_ `shared` such that it is part of the
template type: the implementation itself must also be `shared`. For more
information, see the documentation of the [`ENSHAREDTQMIC` error
message.](messages.html#ENSHAREDTQMIC)

### After Statements

<pre>
after ...: <em>method</em>(<em>e1</em>, ... <em>eN</em>);
</pre>

The `after` statement sets up the given method call (the _callback_) such that
it will be performed with the provided arguments at a specified point in the
future. There are three different forms of the `after` statement, syntactically
determined through what appears before the `:` &mdash; each form corresponds
to different specifications of at what future point the method should be called.

A method call suspended using an `after` statement will be performed at most
once per execution of the `after` statement; it will not recur. If it's
desirable to have a suspended method call recur, then the called method must
itself make use of `after` to set up a method call to itself.

The referenced method must be a regular or [independent](#independent-methods)
method with no return values. It may not be a C function, or a [`shared`
method](#shared-methods). The only exception to this is that the [`send_now`
operation of hooks](#hook-declarations) is also supported for use as a callback.

All method calls suspended via an `after` statement are *associated* with the
object that contains the method containing the statement. It is possible to
cancel all suspended method calls associated with an object through that
object's `cancel_after()` method, as provided by the [`object`
template](dml-builtins.html#object).

> [!NOTE]
> We plan to extend the `after` statement to allow for users to
> explicitly state what objects the suspended method call is to be associated
> with.

#### After Delay Statements
<pre>
after <em>scalar</em> <em>unit</em>: <em>method</em>(<em>e1</em>, ... <em>eN</em>);
</pre>

In this form, the specified point in the future is given through a time delay
(in simulated time, measured in the specified time unit) relative to the time
when the after delay statement is executed. The currently supported time units
are `s` for seconds (with type `double`), `ps` for picoseconds
(with type `uint64`), and `cycles` for cycles (with type `uint64`).

Every argument to the called method is evaluated at the time the `after`
statement is executed, and stored so that they may be used when the method call
is to be performed. In order to allow the suspended method call to be
represented in checkpoints, every input parameter of the method must be of
[*serializable type*](#serializable-types). This means that after delay
statements cannot be used with methods that e.g. have pointer input parameters.
unless the arguments for those input parameters are message component parameters
of the `after`.

Example:

```
after 0.1 s: my_callback(1, false);
```

The after delay statement is equivalent to creating a named [`event`](#events)
object with an event-method that performs the specified call, and posting
that event at the given time, with associated data corresponding to the
provided arguments.

#### Hook-Bound After Statements
<pre>
after <em>hookref</em>[-> (<em>msg1</em>, ... <em>msgN</em>)]: <em>method</em>(<em>e1</em>, ... <em>eM</em>);
</pre>

In this form, the suspended method call is bound to the
[hook](#hook-declarations) specified by <tt><em>hookref</em></tt>. The point in
the future when the method call is executed is thus the next time a message is
sent through the specified hook.

The *binding syntax* <tt>-> (<em>msg1</em>, ... <em>msgN</em>)</tt> is used to
bind each component of the message received to a corresponding identifier,
called a *message component parameter*. These message component parameters can
be used as arguments of the called method, thus propagating the contents of the
message to the method call.

Every argument to the called method which isn't a message component parameter is
evaluated at the time the `after` statement is executed, and stored so that they
may be used when the method call is to be performed. In order to allow the
suspended method call to be represented in checkpoints, every input parameter of
the method must be of [*serializable type*](#serializable-types), unless that
input parameter receives a message component. This means that hook-bound after
statements cannot be used with methods that e.g. have pointer input parameters,
unless the arguments for those input parameters are message component parameters
of the `after`.

Example use:
```
hook(int, float) h;

method my_callback(int i, float f, bool b) {
    ...
}

method m() {
    after h -> (x, y): my_callback(x, y, false);
}

method send_message() {
    // Assuming m() has been called once before, this 'send_now' will result in
    // `my_callback(1, 3.7, false)` being called.
    h.send_now(1, 3.7);
}
```

If the hook has only one message component, the syntax <tt>-> <em>msg</em></tt>
can be used instead, and if the hook has no message components, then the binding
syntax can be entirely omitted. Any message component parameter can be used for
any number of arguments, but cannot be used as anything *but* a direct argument.
For example, using the definitions of `h` and `my_callback` as above, the
following use of `after` is valid:
```
after h -> (x, y): my_callback(x, x, false)
```
Note that the first message component is used multiple times, and the second
is not used at all.

In contrast, the following use of `after` is invalid:
```
after h -> (x, y): my_callback(i, y + 1.5, false)
```
as the message component parameter `y` is used, but not as a direct argument.

#### Immediate After Statements
<pre>
after: <em>method</em>(<em>e1</em>, ... <em>eN</em>);
</pre>

In this form, the specified point in the future is when control is given back to
the simulation engine such that the ongoing simulation of the current processor
may progress, and would otherwise be ready to move onto the next cycle.
This happens after all entries to devices on the call stack have been completed.

Immediate after statements are most useful to avoid ordering bugs. It can be
used to delay a method call until all current lines of execution into the device
have been completed, and the device is guaranteed to be in a consistent state
where it is ready to handle the method call.

Semantically, the immediate after statement is very close to
`after 0 cycles: ...`, but has a number of advantages. In general, the immediate
after statement is designed to execute the callback as promptly as possible
while satisfying the semantics stated above, while `after 0 cycles: ...` is not.
In particular, in Simics, callbacks delayed via `after 0 cycles` are always
bound to the clock associated with the device instance, which is not always
that of the processor currently under simulation &mdash; in such cases the
simulated processor may progress indefinitely without the posted callback being
executed. The immediate after statement does not have this issue.
In addition, if an immediate after statement is executed while the
simulation is stopped (due to a device entry such as an attribute get/set
performed from a script/CLI) then the callback is registered as *work*,
thus guaranteeing that it is called before the simulation starts again.

Within a particular device instance, method calls suspended by immediate
after statements are executed in order of least recently suspended; in other
words, FIFO semantics. The order in which method calls suspended by immediate
after statements are executed across multiple device instances is not defined.

Within an immediate after statement, every argument provided to the called
method is evaluated at the time the `after` statement is executed, and stored so
that they may be used when the method call is to be performed. Unlike the other
forms of `after` statements, the input parameters of the method are never
required to be of serializable type, meaning pointers can be passed as arguments
to the callback. But **beware**: pointers to stack-allocated data (pointers to
or within `local` variables) must **never** be passed as arguments. The
stack with which the `after` statement is executed is *not* preserved, so any
pointers to stack-allocated data will point to invalid data by the time the
callback is called. The DML compiler has some checks in place to warn about the
most obvious cases where pointers to stack-allocated data are provided as
arguments, but it is unable to detect all cases. It is ultimately the modeller's
responsibility to ensure it doesn't happen.

To detail a scenario exemplifying the kind of issues that immediate after may
be leveraged to solve, consider the following device, which needs to communicate
with a *manager* device and receive permission in order to perform a particular
action. Its function is simple: once prompted, the device will raise a signal to
the manager in order to request permission, and waits for it to respond with an
acknowledgement. Once received, the device lowers the signal to the manager and
performs the action it just received permission for.
In order to implement the asynchronous logic needed for this, a simple FSM is
used.
```
param STATE_IDLE = 0;
param STATE_EXPECTING_ACK = 1;
saved int curr_state = STATE_IDLE;

port manager_link {
    connect manager {
        interface signal;
    }

    implement signal {
        method signal_raise() {
            on_acknowledgement();
        }
    }
}

method request_permission_for_action() {
    if (curr_state != STATE_IDLE) {
        log error: "Request already in progress";
        return;
    }
    manager_link.manager.signal.signal_raise();
    curr_state = STATE_EXPECTING_ACK;
}

method on_acknowledgement() {
    if (curr_state != STATE_EXPECTING_ACK) {
        log spec_viol: "Received ack when not expecting it";
        return;
    }
    manager_link.manager.signal.signal_lower();
    perform_permission_gated_action();
    curr_state = STATE_IDLE;
}
```
This device has a subtle bug: it can't handle if the manager responds to the
`signal_raise()` call synchronously.
The FSM transitions to the state capable of handling the acknowledgement
only after the `signal_raise()` call returns, so if the manager responds
synchronously &mdash; as part of the `signal_raise()` call &mdash; then
`on_acknowledgement` will be called while the device still considers itself to
be in its idle state.

This bug can be solved in numerous ways &mdash; the most obvious is to
transition the state before making the `signal_raise()` call &mdash; but
immediate after provides a solution which doesn't require carefully managing
the FSM's logic, by delaying the call to `on_acknowledgement` until the device
is done with all other logic.
```
implement signal {
    method signal_raise() {
        after: on_acknowledgement();
    }
}
```
This guarantees that the FSM is able to finish its current line of execution and
properly transition itself to its new state before it's asked to manage any
response of manager, even if the manager responds synchronously.


### Log Statements

<pre>
log <em>log-type</em>[, <em>level</em> [ then <em>subsequent-level</em> ] [, <em>groups</em>] ]: <em>format-string</em>, <em>e1</em>, ..., <em>eN</em>;
</pre>

Outputs a formatted string to the Simics logging facility. The string
following the colon is a normal C `printf` format string,
optionally followed by one or more arguments separated by commas. (The
format string should not contain the name of the device, or the type of
the message, e.g., "error:..."; these things are automatically prefixed.)
Either both of *`level`* and *`groups`* may be
omitted, or only the latter; i.e., if *`groups`* is
specified, then *`level`* must also be given explicitly.

A Simics user can configure the logging facility to show only specific
messages, by matching on the three main properties of each message:

* The *`log-type`* specifies the general category
  of the message. The value must be one of the identifiers
  `info`, `warning`, `error`, `critical`,
  `spec_viol`, or `unimpl`.

* The *`level`* specifies at what verbosity level the log
  messages are displayed. The value must be an integer from 1 to 4; if
  omitted, the default level is 1. The different levels have the following
  meaning:

  1. Important messages (displayed at the normal verbosity level)
  2. High level informative messages (like mode changes and important events)

  3. Medium level information (the lowest log level for SW development)
  4. Debugging level with low level model detail (Mainly used for model
     development)

  If the *`log-type`* is one of `warning`, `error` or `critical`, then *`level`*
  may only be 1.

* If *`subsequent-level`* is specified, then all logs after the first
  issued will be on the level *`subsequent-level`*. You are allowed
  to specify a *`subsequent-level`* of 5, meaning no logging after the
  initial log.

  If the *`log-type`* is one of `warning`, `error` or `critical`, then
  *`subsequent-level`* may only be either 1 or 5.

* The *`groups`* argument is an integer whose bit
  representation is used to select which log groups the message belongs
  to. If omitted, the default value is 0. The log groups are specific for
  the device, and must be declared using the `loggroup`
  device-level declaration. For example, a DML source file containing the
  declarations

  ```
  loggroup good;
  loggroup bad;
  loggroup ugly;
  ```

  could also contain a log statement such as

  ```
  log info, 2, (bad | ugly): "...";
  ```

  (note the `|` bitwise-or operator), which would be displayed if
  the user chooses to view messages from group `bad` or
  `ugly`, but not if only group `good` is shown.

  Groups allow the user to create arbitrary classifications of log
  messages, e.g., to indicate things that occur in different states, or in
  different parts of the device, etc. The two log groups
  `Register_Read` and `Register_Write` are predefined by
  DML, and are used by several of the built-in methods.

The *`format-string`* should be one or several string
literals concatenated by the '+' operator, all optionally surrounded
by round brackets.

See also *Simics Model Builder User's Guide*, section
"Logging", for further details.

### Assert Statements

<pre>
assert <em>expr</em>;
</pre>

Evaluates *`expr`*. If the result is `true`, the
statement has no effect; otherwise, a runtime-error is generated.
*`expr`* must have type `bool`.

### Error Statements

<pre>
error [<em>string</em>];
</pre>

Attempting to compile an `error` statement causes the compiler to
generate an error, using the specified string as error message. The
string may be omitted; in that case, a default error message is used.

The *`string`*, if present, should be one or several
string literals concatenated by the '+' operator, all optionally
surrounded by round brackets.

### Foreach Statements

<pre>
foreach <em>identifier</em> in (<em>expr</em>) <em>statement</em>
</pre>

The `foreach` statement repeats its body (the
*`statement`* part) once for each element given by *`expr`*.
The *`identifier`* is used to refer to the current element
within the body.

DML currently only supports `foreach` iteration on values of `sequence` types
&mdash; which are created through [Each-In expressions](#each-in-expressions).

The `continue` statement can be used within a `foreach` loop to continue to the
next element, and the `break` statement can be used to exit the loop.

<pre>
#foreach <em>identifier</em> in (<em>expr</em>) <em>statement</em>
</pre>

In this alternative form the *`expr`* is required
to be a DML compile-time constant,
and the loop is completely unrolled by the DML compiler.
This can be combined with tests on the value of
*`identifier`* within the body, which will be evaluated at
compile time.

DML currently only supports `#foreach` iteration on [compile-time list
constants](#list-expressions).

For example:

```
#foreach x in ([3,2,1]) {
    #if (x == 1) foo();
    #else #if (x == 2) bar();
    #else #if (x == 3) baz();
    #else error "out of range";
}
```

would be equivalent to

```
baz();
bar();
foo();
```

Only `#if` can be used to make such selections; `switch` or
`if` statements are *not* evaluated at compile time. (Also
note the use of `error` above to catch any compile-time
mistakes.)

The `break` statement can be used within a `#foreach` loop to exit it.

### Select Statements

<pre>
select <em>identifier</em> in (<em>expr</em>) where (<em>cond-expr</em>) <em>statement</em> else <em>default-statement</em>
</pre>

The `select` statement resembles a C `switch` statement and is very similar
to the `foreach` statement, but executes the *`statement`* exactly once for the
first matching element of those given by *`expr`*, i.e., for the first element
such that *`cond-expr`* is `true`; or if no element matches, it executes the
*`default-statement`*.

<pre>
#select <em>identifier</em> in (<em>expr</em>) where (<em>cond-expr</em>) <em>statement</em> #else <em>default-statement</em>
</pre>

In this alternative form the *`expr`* is required to be a DML
compile-time constant, and
*`cond-expr`* can only depend on compile-time constants, apart
from *`identifier`*. The selection will then be performed by
the DML compiler at compile-time, and code will only be generated for
the selected case.

DML currently only supports `#select` iteration on [compile-time list
constants](#list-expressions).

> [!NOTE]
> The `select` statement has been temporarily removed from DML 1.4 due
> to semantic issues, and only the `#select` form may currently be used.
> The `select` statement will be reintroduced in the near future.

### #if and #else Statements
<a id="if-else-statements"/>

<pre>
#if (<em>condition</em>) { <em>true_body</em> } #else { <em>false_body</em> }
</pre>

The `#if` statement resembles a C `if` statement. The difference
being that the `#if` statement must have a constant-valued
*condition* and the statement is evaluated at compile-time.
The *true\_body* of the `#if` is only processed
if the condition evaluates to `true`,
and will be dead-code eliminated otherwise.

Similarly, the `#else` statement can immediately follow the body of an
`#if` statement and the *false\_body* will only be processed
if the *condition* in the preceding `#if` evaluates to
`false`.



## Code Examples

The following examples demonstrate the concepts described in this section.


### Example: log_example.dml

Log statement examples

```dml
dml 1.4;

device log_example;
param documentation = "Logging example for Model Builder User's Guide";
param desc = "example of logging";

bank regs {
     register r size 4 @ 0x0000 is read {
        method read() -> (uint64) {
log info, 2: "This is a level 2 message.";
            return 42;
        }
    }
}
```

### Example: events.dml

After statement examples

```dml
dml 1.4;

device events;
param desc = "example of event";

event future is uint64_time_event {
    method event(uint64 data) {
        log info, 1 : "The future is here";
    }
}

method my_method() { }

method init() {
    local uint64 some_data = 0;
    local conf_object_t *clock = NULL;
// post an event 0.1 s in the future
future.post(0.1, 0);

future.remove(some_data);

local bool is_this_event_posted = future.posted(some_data);
local double when_is_this_event_posted = future.next(some_data);

// call my_method() after 10.5s
after 10.5 s: my_method();
}
```
