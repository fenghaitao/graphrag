<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Hook Declarations
<pre>
hook(<em>msgtype1</em>, ... <em>msgtypeN</em>) <em>name</em>;
</pre>
A *hook* declaration defines a named object member to which *suspended
computations* may be attached for execution at a later point. By sending a
*message* through the hook, every computation suspended on the hook will become
detached from the hook, and then executed &mdash; receiving the message as data.
Computations suspended on a hook are executed in order of least recently
attached; in other words, FIFO semantics.

Currently, the only computations that can be suspended and attached to hooks are
single method calls, which is done through the use of the [`after`
statement](#after-statements). This will later be expanded upon: hooks will play
a central role in the future introduction of *coroutines*, as hooks will serve
as the primitive mechanism through which coroutines suspend themselves and
become resumed.

Every hook has an associated list of *message component types*, specified during
declaration through the <tt>(<em>msgtype1</em>, ... <em>msgtypeN</em>)</tt>
syntax. This specifies what form of data is sent and received via the hook. Any
number of message component types can be given, including zero, in which case a
message sent via the hook has no associated data.

Example declarations:
```
// Hook with no associated message component types
hook() h1;
// Hook with a single message component type
hook(int) h2;
// Hook with two message component types
hook(int *, bool) h3;
```

Beyond suspending computations on it, a hook <tt><em>h</em></tt> has two
associated operations:

* <pre><em>h</em>.send(<em>msg1</em>, ... <em>msgN</em>)</pre>
  Sends a message through the hook, with message components
  <tt><em>msg1</em></tt> through <tt><em>msgN</em></tt>. The number of message
  components must match the number of message component types of the hook,
  and each message component must be compatible with the corresponding message
  component type of the hook.

  `send` is *asynchronous*: the message will only be sent &mdash; and suspended
  computations executed &mdash; once all current device entries on the call
  stack have been completed. It is exactly equivalent to
  <tt>after: <em>h</em>.send_now(<em>msg1</em>, ... <em>msgN</em>)</tt>, except
  it's not possible to prevent the message from being sent via `cancel_after()`.
  For more information, see [Immediate After
  Statements](#immediate-after-statements).

  Like immediate after statements, pointers to stack-allocated data **must not**
  be passed as message components to a `send`. If you must use pointers to
  stack-allocated data, then `send_now` should be used instead of `send`. If you
  want the message to be delayed to avoid ordering bugs, create a method which
  wraps the `send_now` call together with the declarations of the local
  variable(s) which are pointed to, and then use an immediate after statement
  (`after: m(...)`) to delay the call to that method.

* <pre><em>h</em>.send_now(<em>msg1</em>, ... <em>msgN</em>)</pre>
  Sends a message through the hook, with message components
  <tt><em>msg1</em></tt> through <tt><em>msgN</em></tt>. The number of message
  components must match the number of message component types of the hook,
  and each message component must be compatible with the corresponding message
  component type of the hook.

  `send_now` is *synchronous*: every computation suspended on the hook will
  execute before `send_now` completes.

  `send_now` returns the number of suspended computations that were successfully
  resumed from the message being sent. Currently, every suspended computation is
  guaranteed to successfully be resumed unless cancelled by a preceding
  computation resumed by the `send_now`. This will not remain true in the
  future: coroutines are planned to be able to reject a message and reattach
  themselves to the hook.

* <pre><em>h</em>.suspended</pre>
  Evaluates to the number of computations currently suspended on the hook.

References to hooks are valid run-time values: a reference to a hook with
message component types <tt><em>msgtype1</em></tt> through
<tt><em>msgtypeN</em></tt> will have the hook reference type
<tt>hook(<em>msgtype1</em>, ... <em>msgtypeN</em>)</tt>. This means hook
references can be stored in variables, and can be passed around as method
arguments or return values. In fact, hook references are even
[serializable](#serializable-types).

Two hook references of the same hook reference type can be compared for
equality, and are considered equal when they both reference the same hook.

> [!NOTE]
> Hooks have a notable shortcoming in their lack of configurability;
> for example, there is no way to configure a hook to log an error when a message
> is sent through the hook and there is no computation suspended on the hook to
> act upon the message. Proper hook configurability is planned to be added by the
> time or together with coroutines being introduced to DML. Until then, the
> suggested approach is to create wrappers around usages of <tt>send_now()</tt>.
> Hook reference types can be leveraged to cut down on the needed number of such
> wrappers, for example:
> <pre>
> method send_now_checked_no_data(hook() h) {
>     local uint64 resumed = h.send_now();
>     if (resumed == 0) {
>         log error: "Unhandled message to hook";
>     }
> }
>
> method send_now_checked_int(hook(int) h, int x) {
>     local uint64 resumed = h.send_now(x);
>     if (resumed == 0) {
>         log error: "Unhandled message to hook";
>     }
> }
> </pre>

