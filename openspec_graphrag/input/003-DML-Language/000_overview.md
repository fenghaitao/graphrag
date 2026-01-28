<!--
  © 2021 Intel Corporation
  SPDX-License-Identifier: MPL-2.0
-->

# Device Modeling Language, version 1.4

This chapter describes the Device Modeling Language (DML), version 1.4. It will
help to have read and understood the object model in the previous
chapter before reading this chapter.

## Overview

DML is not a general-purpose programming language, but a modeling
language, targeted at writing Simics device models. The algorithmic part
of the language is similar to ISO C; however, the main power
of DML is derived from its simple object-oriented constructs for
defining and accessing the static data structures that a device model
requires, and the automatic creation of bindings to Simics.

Furthermore, DML provides syntax for *bit-slicing*, which much simplifies the
manipulation of bit fields in integers; [`new`](#new-expressions) and
[`delete`](#delete-statements) operators for allocating and deallocating
memory; a basic [`try`](#try-statements)/[`throw`](#throw-statements) mechanism
for error handling; built-in [`log`](#log-statements) and
[`assert`](#assert-statements) statements; and a powerful metaprogramming
facility using [*templates*](#templates) and [*in each
statements*](#in-each-declarations).

Most of the built-in Simics-specific logic is implemented directly in
DML, in standard library modules that are automatically imported; the
`dmlc` compiler itself contains as little knowledge as possible
about the specifics of Simics.

---

## DML 1.4 Language Reference - Document Navigation

This documentation is organized into focused topics covering all aspects of the DML 1.4 language. Below is a comprehensive guide to help you navigate the documentation effectively.

### Document Structure

The DML 1.4 reference is split into 22 focused documents (000-021), each covering a specific aspect of the language:

---

### 1. [Lexical Structure](001_lexical-structure.md)
**Focus**: Character encoding, reserved words, identifiers, literals, and basic syntax elements

**Topics Covered**:
- UTF-8 character encoding requirements
- Reserved words (C, C99, C++, and DML-specific keywords)
- Identifier naming rules and conventions
- Numeric, string, and character literals
- Comments and documentation syntax

**When to Read**: Reference when working with character encoding, string literals, or encountering syntax errors with identifiers.

---

### 2. [Module System](002_module-system.md)
**Focus**: DML's import mechanism and module organization

**Topics Covered**:
- Module definition and structure
- Import directives and idempotency
- Import hierarchy semantics
- Module override rules
- Standard library imports

**When to Read**: When organizing code across multiple files or creating reusable DML modules.

---

### 3. [Source File Structure](003_source-file-structure.md)
**Focus**: Overall structure of DML source files

**Topics Covered**:
- Language version declarations (`dml 1.4;`)
- Device declarations
- File organization (parameters, methods, data fields, objects)
- Import file structure vs. device file structure
- File ordering requirements

**When to Read**: When starting a new DML file or setting up project structure.

---

### 4. [Pragmas](004_pragmas.md)
**Focus**: Compiler directives and annotations

**Topics Covered**:
- Pragma syntax (`/*% TAG ... %*/`)
- COVERITY pragma for static analysis
- Pragma placement rules
- Compiler-specific directives

**When to Read**: When integrating with static analysis tools or using compiler-specific features.

---

### 5. [Object Model](005_object-model.md)
**Focus**: DML's object hierarchy and device structure

**Topics Covered**:
- Object model fundamentals (device, banks, ports, subdevices)
- Parameters and their role in configuration
- Methods and functionality implementation
- Device structure and nesting rules
- Object type restrictions and placement
- Attributes, connects, implements, events, groups, ports, subdevices

**When to Read**: Essential for understanding how DML organizes device models. Read before implementing complex device hierarchies.

---

### 6. [Register Banks and Registers](006_registers.md)
**Focus**: Memory-mapped register modeling

**Topics Covered**:
- Register bank declarations and bank arrays
- Register size, offset, and byte order
- Mapped vs. unmapped registers
- Register attributes and checkpointing
- Register fields and bit ranges
- Read/write behavior and templates
- Field declaration syntax and write order

**When to Read**: Critical for any device with memory-mapped registers. Read before implementing register banks.

---

### 7. [Templates](007_templates.md)
**Focus**: Code reuse through template instantiation

**Topics Covered**:
- Template definition syntax
- Template instantiation with `is` statements
- Template parameters and arguments
- Template overrides and specialization
- Built-in templates from standard library
- Template composition and inheritance

**When to Read**: When implementing reusable patterns or using standard DML templates for registers and fields.

---

### 8. [Parameters Detailed](008_parameters-detailed.md)
**Focus**: In-depth coverage of parameter system

**Topics Covered**:
- Parameter declaration and definition
- Default vs. overriding parameters
- Parameter scope and inheritance
- Parameter expressions and evaluation
- Auto parameters and computed values
- Parameter types and constraints

**When to Read**: When working with complex parameter configurations or template parameterization.

---

### 9. [Data Types](009_data-types.md)
**Focus**: DML type system and data structures

**Topics Covered**:
- Primitive types (integers, floats, booleans)
- Pointer types and references
- Array types and indexing
- Struct and typedef declarations
- Type conversions and casting
- Endianness and byte order
- Bitfields and bit-slicing syntax

**When to Read**: When declaring variables, structures, or performing type conversions.

---

### 10. [Methods](010_methods.md)
**Focus**: Method declarations and implementations

**Topics Covered**:
- Method declaration syntax
- Input parameters and return values
- Multiple return values
- Method overriding and default implementations
- Inline methods vs. exported methods
- Method scope and visibility
- Calling conventions

**When to Read**: When implementing device functionality or overriding standard methods.

---

### 11. [Session Variables](011_session-variables.md)
**Focus**: Runtime state not saved in checkpoints

**Topics Covered**:
- Session variable declaration
- Lifetime and initialization
- Use cases for transient state
- Differences from saved variables
- Memory management

**When to Read**: When implementing transient device state that shouldn't be checkpointed.

---

### 12. [Saved Variables](012_saved-variables.md)
**Focus**: Device state saved in checkpoints

**Topics Covered**:
- Saved variable declaration
- Automatic checkpointing
- Initialization and default values
- When to use saved variables vs. registers
- Best practices for state management

**When to Read**: When implementing device state that must persist across checkpoints.

---

### 13. [Hook Declarations](013_hook-declarations.md)
**Focus**: Extension points for overrideable behavior

**Topics Covered**:
- Hook declaration syntax
- Hook invocation and chaining
- Default hook implementations
- Hook overriding rules
- Use cases for extensibility

**When to Read**: When creating extension points or implementing callback mechanisms.

---

### 14. [Object Declarations](014_object-declarations.md)
**Focus**: Declaring device objects (banks, registers, fields, etc.)

**Topics Covered**:
- Object declaration syntax
- Object arrays and indexing
- Object parameters and configuration
- Nested object hierarchies
- Object naming and access

**When to Read**: When declaring any DML object (bank, register, field, port, etc.).

---

### 15. [Conditional Objects](015_conditional-objects.md)
**Focus**: Conditionally including objects based on parameters

**Topics Covered**:
- `#if` directives for objects
- Conditional compilation based on parameters
- Feature flags and configuration variants
- Conditional object arrays

**When to Read**: When creating configurable devices with optional features.

---

### 16. [In Each Declarations](016_in-each-declarations.md)
**Focus**: Metaprogramming with compile-time iteration

**Topics Covered**:
- `in each` syntax and semantics
- Iterating over object arrays
- Generating repetitive code
- Use cases for code generation

**When to Read**: When generating similar code for multiple objects or array elements.

---

### 17. [Global Declarations](017_global-declarations.md)
**Focus**: Import statements and global scope declarations

**Topics Covered**:
- Import declarations
- Global constants and types
- Extern declarations
- Standard library imports
- Import paths and resolution

**When to Read**: When importing modules or declaring global types and constants.

---

### 18. [Resolution of Overrides](018_resolution-of-overrides.md)
**Focus**: How DML resolves parameter and method overrides

**Topics Covered**:
- Override resolution rules
- Template override precedence
- Parameter inheritance chains
- Method override semantics
- Conflict resolution

**When to Read**: When debugging override issues or understanding template composition.

---

### 19. [Comparison to C/C++](019_comparison-to-c-cpp.md)
**Focus**: Key differences between DML and C/C++

**Topics Covered**:
- Syntax similarities and differences
- Type system differences
- Control flow differences
- Memory management differences
- Object model vs. C structs

**When to Read**: When coming from C/C++ background or interfacing with C code.

---

### 20. [Method Statements](020_method-statements.md)
**Focus**: Control flow and statements within methods

**Topics Covered**:
- Assignment statements
- Conditional statements (`if`, `else`, `switch`)
- Loop statements (`for`, `while`, `do-while`)
- Exception handling (`try`, `throw`, `catch`)
- Logging statements (`log`)
- Assertion statements (`assert`)
- Return statements
- Timing statements (`after`)

**When to Read**: When implementing method bodies and control flow logic.

---

### 21. [Expressions](021_expressions.md)
**Focus**: Expression syntax and operators

**Topics Covered**:
- Arithmetic operators
- Logical and bitwise operators
- Bit-slicing syntax (`[msb:lsb]`)
- Comparison operators
- Conditional expressions (ternary operator)
- Function calls and method invocations
- Cast expressions
- `new` and `delete` expressions
- Undefined constant handling

**When to Read**: Reference for expression syntax, operator precedence, and bit manipulation.

---

## Quick Navigation Guide

### I want to...

**...start writing a new DML device**  
→ Read [003_source-file-structure.md](003_source-file-structure.md) first, then [005_object-model.md](005_object-model.md)

**...implement memory-mapped registers**  
→ Study [006_registers.md](006_registers.md) for complete register and field documentation

**...understand DML syntax and reserved words**  
→ Check [001_lexical-structure.md](001_lexical-structure.md)

**...organize code across multiple files**  
→ Read [002_module-system.md](002_module-system.md)

**...use templates for code reuse**  
→ Study [007_templates.md](007_templates.md) and [008_parameters-detailed.md](008_parameters-detailed.md)

**...implement device methods and logic**  
→ Read [010_methods.md](010_methods.md), [020_method-statements.md](020_method-statements.md), and [021_expressions.md](021_expressions.md)

**...manage device state**  
→ Compare [011_session-variables.md](011_session-variables.md) vs. [012_saved-variables.md](012_saved-variables.md)

**...work with data types and structures**  
→ Reference [009_data-types.md](009_data-types.md)

**...create configurable devices**  
→ Use [015_conditional-objects.md](015_conditional-objects.md) and [008_parameters-detailed.md](008_parameters-detailed.md)

**...understand how overrides work**  
→ Read [018_resolution-of-overrides.md](018_resolution-of-overrides.md)

**...compare DML to C/C++**  
→ Check [019_comparison-to-c-cpp.md](019_comparison-to-c-cpp.md)

**...generate repetitive code**  
→ Use [016_in-each-declarations.md](016_in-each-declarations.md)

---

## Recommended Reading Order

### For Beginners:
1. **000_overview.md** (this document) - Understand DML purpose and structure
2. **003_source-file-structure.md** - Learn file organization
3. **001_lexical-structure.md** - Learn basic syntax
4. **005_object-model.md** - Understand device hierarchy
5. **006_registers.md** - Learn register modeling (most common task)
6. **010_methods.md** - Implement device behavior
7. **020_method-statements.md** - Write method logic
8. **021_expressions.md** - Work with expressions and operators

### For Register-Heavy Devices:
1. **005_object-model.md** - Understand object hierarchy
2. **006_registers.md** - Master register banks and fields
3. **007_templates.md** - Use register templates
4. **009_data-types.md** - Work with data types
5. **020_method-statements.md** - Implement register behavior

### For Complex Device Hierarchies:
1. **005_object-model.md** - Object model fundamentals
2. **014_object-declarations.md** - Object declaration syntax
3. **008_parameters-detailed.md** - Parameter system
4. **007_templates.md** - Template composition
5. **018_resolution-of-overrides.md** - Override resolution

### For Template-Heavy Development:
1. **007_templates.md** - Template basics
2. **008_parameters-detailed.md** - Template parameters
3. **018_resolution-of-overrides.md** - Override semantics
4. **016_in-each-declarations.md** - Metaprogramming

### For Multi-File Projects:
1. **002_module-system.md** - Import system
2. **003_source-file-structure.md** - File organization
3. **017_global-declarations.md** - Global imports and declarations

---

## Summary

The DML 1.4 language provides a powerful, specialized environment for modeling hardware devices in Simics. The documentation is organized to support both linear reading (for learning) and quick reference (for implementation).

**Key Language Features**:
- **Object-oriented hierarchy**: Device → Bank → Register → Field
- **Template system**: Reusable code patterns with parameters
- **Register modeling**: Built-in support for memory-mapped I/O
- **Simics integration**: Automatic interface generation and checkpointing
- **Type safety**: Strong typing with C-like syntax
- **Metaprogramming**: Compile-time code generation and conditionals

**Next Steps**:
- For implementation guidance, see the [DML Best Practices Index](../00_DML_Best_Practices_Index.md)
- For production code examples, see [DML 1.4 Code Examples](../001-code-examples/)
- For language details, navigate to specific topics above

---

**Document Status**: Complete  
**DML Version**: 1.4  
**Last Updated**: December 18, 2025  
**Total Documents**: 22 focused references (000-021)
