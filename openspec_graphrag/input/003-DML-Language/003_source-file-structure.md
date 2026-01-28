<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

## Source File Structure

A DML source file describes both the structure of the modeled device and
the actions to be taken when the device is accessed.

A DML source file defining a device starts with a *language version declaration*
and a *device declaration*. After that, any number of *parameter declarations*,
*methods*, *data fields*, *object declarations*, or *global declarations* can be
written. A DML file intended to be *imported* (by an [`import`
statement](#import-declarations) in another DML file) has the same layout except
for the device declaration.

### Language Version Declaration

Every DML source file should contain a version declaration, on the form
`dml 1.4;`. The version
declaration allows the `dmlc` compiler to select the proper
versions of the DML parser and standard libraries to be used for the
file. A file can not
import a file with a different language version than its own.

The version declaration must be the first declaration in the file,
possibly preceded by comments. For example:

```
// My Device
dml 1.4;
...
```

### Device Declaration

Every DML source file that contains a device declaration is a *DML model*, and
defines a Simics device class with the specified name. Such a file may *import*
other files, but only the initial file may contain a device declaration.

The device declaration must be the first proper declaration in the file,
only preceded by comments and the language version declaration. For
example:

```
/*
 *  My New Device
 */
dml 1.4;
device my_device;
...
```


## Code Examples

The following examples demonstrate the concepts described in this section.


### Example: simple_device.dml

A complete simple device example

```dml
dml 1.4;

device simple_device;
param desc = "sample DML device";
param documentation = "This is a very simple device.";

bank regs {
    register counter size 4 @ 0x0000 is (read) {
        method read() -> (uint64) {
            log info: "read from counter";
            return 42;
        }
    }
}
```
