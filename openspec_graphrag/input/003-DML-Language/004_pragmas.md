<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Pragmas

DML has a syntax for pragmas: directives to the DML compiler that are orthogonal
to DML as a language, both in the sense of that they are not considered part of
DML proper, and that their use do not affect the semantics of DML (unless by
accident.) The syntax for pragmas are as follows:
<pre>
/*% <em>tag</em> ... %*/
</pre>
Where _`tag`_ specifies the pragma used, and which determines the syntax of
everything following it before the pragma is closed. Tags are case insensitive,
but are fully capitilized by convention. DMLC will print a warning if a pragma
is given with a tag that the compiler does not recognize.

A pragma may be given anywhere an inline comment may; however, the meaning of
a pragma is dependent on its placement, and a specified pragma can be completely
meaningless if not properly placed.

DMLC supports the following pragmas:

### COVERITY pragma
The `COVERITY` pragma provides a means to manually suppress defects reported by
Synopsys® Coverity® stemming from a particular DML line. A `COVERITY` pragma
has no effect unless `--coverity` is passed to DMLC, in which case it will cause
an analysis annotation to be specified for every generated C line corresponding
to the DML line that the pragma applies to.

The syntax for the `COVERITY` pragma is as follows:
<pre>
/*% COVERITY <em>event</em> <em>classification</em> %*/
</pre>
where _`classification`_ is optional. This corresponds to the following
analysis annotation in generated C:
<pre>
/* coverity[<em>event</em> : <em>classification</em>] */
</pre>
or, if _`classification`_ is omitted:
<pre>
/* coverity[<em>event</em>] */
</pre>

A DML line will be affected by every `COVERITY` pragma specified in preceding
lines, up until the first line not containing any `COVERITY` pragma. For
example:
```
/*% COVERITY unreachable %*/

/*% COVERITY var_deref_model %*/
/*% COVERITY check_return %*/ /*% COVERITY copy_paste_error FALSE %*/
some_function(...);
```
Any C line corresponding to the call to `some_function(...)` will receive
analysis annotations for `var_deref_model`, `check_return`, and
`copy_paste_error` (with `copy_paste_error` specifically being classified as a
false positive), but not any analysis annotation for `unreachable`, as the empty
line breaks the consecutive specifications of COVERITY pragmas.

