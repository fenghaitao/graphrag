<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Module System

DML employs a very simple module system, where a *module* is any source file
that can be imported using the [`import` directive](#import-declarations).
Such files may not contain a [`device` declaration], but otherwise look like
normal DML source files. The imported files are merged into the main model
as if all the code was contained in a single file (with some exceptions). This
is similar to C preprocessor `#include` directives, but in DML each imported
file must be possible to parse in isolation, and may contain declarations (such
as [`bitorder`](#bitorder-declarations)) that are only effective for that file.
Also, DML imports are automatically idempotent, in the sense that importing the
same file twice does not yield any duplicate definitions.

The import hierarchy has semantic significance in DML: If a module
defines some method or parameter declarations that can be overridden,
then *only* files that explicitly import the module are allowed
to override these declarations. It is however sufficient to import the
module indirectly via some other module. For instance, if A.dml
contains a default declaration of a method, and B.dml wants to
override it, then B.dml must either import A.dml, or some file C.dml
that in turn imports A.dml. Without that import, it is an error to
import both A.dml and B.dml in the same device.
