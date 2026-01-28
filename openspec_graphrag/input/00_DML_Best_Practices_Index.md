# DML Best Practices - Document Index

## Overview

This is the master index for the DML Best Practices documentation. The original comprehensive guide has been split into focused, single-subject documents for easier reference and learning.

## Document Structure

The documentation is organized into multiple focused areas:

### Best Practices Guides (01-07):

### 1. [Simics Modeling Philosophy](01_Simics_Modeling_Philosophy.md)
**Focus**: Core principles and philosophy behind Simics device modeling

**Topics Covered**:
- Transaction-Level Device Modeling (TLM)
- Simics High-Level Modeling Approach
- Why not to model unnecessary detail
- Core modeling principles summary

**When to Read**: Start here to understand the fundamental philosophy before writing any DML code.

---

### 2. [DML Anti-Patterns](02_DML_Anti_Patterns.md)
**Focus**: Critical mistakes to avoid when writing DML code

**Topics Covered**:
- Clock signal modeling (MOST COMMON MISTAKE)
- Calling timing APIs in init()/post_init()
- Incomplete timer/counter implementations
- Cycle-by-cycle updates
- Other common anti-patterns

**When to Read**: Review this before starting any new device, especially timer-related devices. Refer back when debugging performance issues.

---

### 3. [DML 1.4 Language Reference](003-DML-Language/)
**Focus**: Complete DML 1.4 language specification and reference documentation

**Topics Covered**:
- Lexical structure, module system, and file organization
- Object model, device hierarchy, and object types
- Register banks, registers, and fields modeling
- Templates, parameters, and code reuse patterns
- Data types, methods, and control flow
- Variables (session and saved), hooks, and declarations
- Conditional compilation and metaprogramming
- Expression syntax, operators, and statements
- Override resolution and comparison to C/C++

**Document Structure**: 22 focused reference documents (000-021):

- **[000_overview.md](003-DML-Language/000_overview.md)** - DML 1.4 introduction and navigation guide
- **[001_lexical-structure.md](003-DML-Language/001_lexical-structure.md)** - Character encoding, reserved words, identifiers, literals
- **[002_module-system.md](003-DML-Language/002_module-system.md)** - Import mechanism and module organization
- **[003_source-file-structure.md](003-DML-Language/003_source-file-structure.md)** - File structure and organization
- **[004_pragmas.md](003-DML-Language/004_pragmas.md)** - Compiler directives and annotations
- **[005_object-model.md](003-DML-Language/005_object-model.md)** - Device hierarchy and object types
- **[006_registers.md](003-DML-Language/006_registers.md)** - Register banks, registers, and fields
- **[007_templates.md](003-DML-Language/007_templates.md)** - Template system and code reuse
- **[008_parameters-detailed.md](003-DML-Language/008_parameters-detailed.md)** - Parameter system in depth
- **[009_data-types.md](003-DML-Language/009_data-types.md)** - Type system and data structures
- **[010_methods.md](003-DML-Language/010_methods.md)** - Method declarations and implementations
- **[011_session-variables.md](003-DML-Language/011_session-variables.md)** - Transient state variables
- **[012_saved-variables.md](003-DML-Language/012_saved-variables.md)** - Checkpointed state variables
- **[013_hook-declarations.md](003-DML-Language/013_hook-declarations.md)** - Hook extension points
- **[014_object-declarations.md](003-DML-Language/014_object-declarations.md)** - Object declaration syntax
- **[015_conditional-objects.md](003-DML-Language/015_conditional-objects.md)** - Conditional compilation
- **[016_in-each-declarations.md](003-DML-Language/016_in-each-declarations.md)** - Metaprogramming iteration
- **[017_global-declarations.md](003-DML-Language/017_global-declarations.md)** - Import and global scope
- **[018_resolution-of-overrides.md](003-DML-Language/018_resolution-of-overrides.md)** - Override resolution rules
- **[019_comparison-to-c-cpp.md](003-DML-Language/019_comparison-to-c-cpp.md)** - DML vs. C/C++ differences
- **[020_method-statements.md](003-DML-Language/020_method-statements.md)** - Control flow and statements
- **[021_expressions.md](003-DML-Language/021_expressions.md)** - Expression syntax and operators

**How to Use**:
1. **Start with overview**: Read `003-DML-Language/000_overview.md` for introduction and navigation
2. **Quick lookup**: Use specific documents for syntax questions (e.g., bit-slicing in `021_expressions.md`)
3. **Register implementation**: Reference `006_registers.md` for register modeling details
4. **Template usage**: Study `007_templates.md` and `008_parameters-detailed.md` for advanced patterns
5. **Type questions**: Check `009_data-types.md` for type system details
6. **Method implementation**: Reference `010_methods.md` and `020_method-statements.md` for control flow
7. **File organization**: Use `002_module-system.md` and `003_source-file-structure.md` for project structure

**When to Read**:
- **During compilation errors**: Check syntax in relevant language reference document
- **Learning new features**: Read focused documents on specific topics (templates, registers, etc.)
- **Understanding overrides**: Study `018_resolution-of-overrides.md` for template and parameter resolution
- **Module organization**: Reference `002_module-system.md` for multi-file projects
- **Type conversions**: Check `009_data-types.md` for casting and type compatibility
- **Starting new device**: Read `003_source-file-structure.md` and `005_object-model.md`

**Integration with Best Practices**:
- **Philosophy (01)**: Language reference provides syntax for implementing modeling principles
- **Anti-Patterns (02)**: Language docs clarify correct usage vs. common mistakes
- **Timing (04)**: References language features for timing (`after` statements, events in `020_method-statements.md`)
- **Patterns (06)**: Uses language constructs in practical examples
- **Scope (07)**: Explains register access scope rules using language syntax
- **Code Examples (001-code-examples/)**: Shows language features in production code

---

### 4. [DML Timing and Timer Modeling](04_DML_Timing_Timer_Modeling.md)
**Focus**: Comprehensive guide to timing features and timer device implementation

**Topics Covered**:
- Core timing mechanisms (`after` statement, event objects)
- Timer counter modeling patterns (lazy evaluation, HPET, countdown, watchdog, TSC, periodic, comparator)
- Complete timer device examples (relative and absolute timers)
- Timing constants and conversions
- Best practices and quick reference

**When to Read**: Essential for any device with timing behavior (timers, counters, watchdogs, periodic events).

---

### 5. [DML Troubleshooting](05_DML_Troubleshooting.md)
**Focus**: Solutions to common compilation errors, runtime issues, and development problems

**Topics Covered**:
- Compilation issues (syntax errors, missing imports, UTF-8 mode)
- Runtime issues (AttributeError, module_load.py problems)
- Testing and build issues (forgotten rebuilds)
- Common mistakes and debugging tips

**When to Read**: When you encounter errors or unexpected behavior. Use as a diagnostic checklist.

---

### 6. [DML Common Patterns and Examples](06_DML_Common_Patterns.md)
**Focus**: Practical, reusable patterns and complete examples for common device types

**Topics Covered**:
- Basic memory-mapped device
- Device with interrupts
- Complete UART example
- Simple PCI device
- When to use each pattern

**When to Read**: When starting a new device implementation. Copy and adapt these patterns to your needs.

---

### 7. [DML Register Access Scope Patterns](07_DML_Register_Access_Scope.md) **CRITICAL**
**Focus**: Register access syntax based on code context (device/bank/register level)

**Topics Covered**:
- Device-level register access (`bank.REGISTER.val`)
- Bank-level register access (`REGISTER.val`)
- Register-level access (`this.val`)
- Common "unknown identifier" errors and fixes
- Pre-build checklist for scope errors
- Real-world examples from WDT implementation

**When to Read**: **MANDATORY before ANY DML implementation**. This prevents 100% of register scope compilation errors. Review before first build.

---

### 8. [DML 1.4 Code Examples](008-code-examples/) **PRODUCTION CODE REFERENCE**
**Focus**: Real-world DML 1.4 device implementations from production Simics models

**Topics Covered**:
- **9 Device Categories**: DMA, Interrupt Controllers, MMU/IOMMU, PCIe, TRNG, I2C, I3C, Timer, UART
- **Implementation Patterns**: Device declarations, register banks, interfaces, timing, error handling
- **Production Features**: Real implementations of FIFOs, DMA, interrupts, protocol handling, state machines
- **Complete Context**: Full device structure with imports, attributes, connects, methods, events, ports

**Document Structure**:
- `000_overview.md` - Introduction, common patterns, navigation guide
- `001_dma.md` - DMA controllers (Synopsys AHB DMAC, etc.)
- `002_interrupt_controller.md` - Interrupt controllers (RISC-V CLINT, etc.)
- `003_mmu.md` - MMU/IOMMU devices (SMMU-v3, ARM MMU-600, etc.)
- `004_pcie.md` - PCIe devices (endpoints, switches, capabilities)
- `005_trng.md` - True Random Number Generators (Synopsys TRNG)
- `006_i2c.md` - I2C controllers and targets (Synopsys APB I2C)
- `007_i3c.md` - I3C controllers (Synopsys MIPI I3C)
- `008_timer.md` - Timer and watchdog devices (Synopsys APB Timers/WDT)
- `009_uart.md` - UART devices (Synopsys APB UART, PL011)

**When to Read**: 
- **During Implementation**: Reference when implementing specific device features or protocols
- **Pattern Discovery**: Find proven patterns for features you need (FIFOs, DMA, interrupts, etc.)
- **Code Validation**: Compare your implementation against production examples
- **Learning Idioms**: Understand how experienced developers structure DML code
- **Feature Research**: See how specific hardware features are modeled in DML

**Critical Use Cases**:
1. **Implementing device-specific features**: Search category docs for similar devices
2. **Understanding register bank structure**: See real register layouts and field definitions
3. **Interface implementation**: Study how devices connect to buses, signals, and other devices
4. **Error handling patterns**: Learn from production error checking and status reporting
5. **Protocol implementation**: See complete protocol state machines (I2C, I3C, PCIe, UART)
6. **Timing and events**: Study real timer implementations with lazy evaluation
7. **DMA patterns**: Understand DMA channel management, descriptors, and transfers
8. **Interrupt patterns**: See how devices generate, mask, and manage interrupts

**Relationship to Best Practices**:
- **Principles (01)**: Code examples demonstrate the philosophy in action
- **Anti-Patterns (02)**: Examples show correct implementations avoiding common mistakes
- **Language Reference (03)**: Real code showing proper DML syntax usage
- **Timing (04)**: Production timer implementations using correct patterns
- **Patterns (06)**: Extended library of production patterns beyond basic examples
- **Scope (07)**: Examples demonstrate correct register access scope in context

**How to Use**:
1. **Start with `000_overview.md`** to understand organization and common patterns
2. **Navigate to relevant category** based on your device type
3. **Study similar devices** in that category for applicable patterns
4. **Extract and adapt** code patterns to your implementation
5. **Cross-reference** with best practices documents for principles
6. **Validate** your approach against multiple production examples

**When NOT to Use**:
- As a substitute for DML language documentation (use 003-DML-Language/)
- As a substitute for principles (read 01_Simics_Modeling_Philosophy.md first)
- Without understanding anti-patterns (review 02_DML_Anti_Patterns.md)
- For debugging errors (use 05_DML_Troubleshooting.md)

---

## Quick Navigation Guide

### I want to...

**...start ANY DML implementation** **CRITICAL**  
→ **FIRST** read [07_DML_Register_Access_Scope.md](07_DML_Register_Access_Scope.md) to prevent scope errors

**...understand Simics modeling philosophy**  
→ Start with [01_Simics_Modeling_Philosophy.md](01_Simics_Modeling_Philosophy.md)

**...avoid common mistakes**  
→ Read [02_DML_Anti_Patterns.md](02_DML_Anti_Patterns.md) first

**...learn DML syntax**  
→ Study [003-DML-Language/](003-DML-Language/) language reference

**...implement a timer device**  
→ Follow [04_DML_Timing_Timer_Modeling.md](04_DML_Timing_Timer_Modeling.md)

**...fix compilation/runtime errors**  
→ Check [05_DML_Troubleshooting.md](05_DML_Troubleshooting.md)

**...fix "unknown identifier" errors**  
→ Check [07_DML_Register_Access_Scope.md](07_DML_Register_Access_Scope.md)

**...build a specific device type**  
→ Use templates from [06_DML_Common_Patterns.md](06_DML_Common_Patterns.md)

**...see real production implementations**  
→ Browse [008-code-examples/](008-code-examples/) for your device category

**...implement a specific feature (FIFO, DMA, protocol)**  
→ Search [008-code-examples/](008-code-examples/) for devices with that feature

**...understand how a device type works**  
→ Study complete examples in [008-code-examples/](008-code-examples/)

**...validate my implementation approach**  
→ Compare against production code in [008-code-examples/](008-code-examples/)

---

## Recommended Reading Order

### For ALL Implementations (MANDATORY):
1. **07_DML_Register_Access_Scope.md** - **READ FIRST** to prevent scope errors

### For Beginners:
1. **07_DML_Register_Access_Scope.md** - **MANDATORY** - Prevent scope errors
2. **01_Simics_Modeling_Philosophy.md** - Understand the "why"
3. **02_DML_Anti_Patterns.md** - Learn what NOT to do
4. **003-DML-Language/000_overview.md** - Learn the language
5. **06_DML_Common_Patterns.md** - Practice with examples
6. **008-code-examples/** - Study production code for your device type
7. **05_DML_Troubleshooting.md** - Keep handy for issues

### For Implementing Specific Device Types:
1. **07_DML_Register_Access_Scope.md** - **MANDATORY** - Prevent scope errors
2. **008-code-examples/000_overview.md** - Understand example organization
3. **008-code-examples/[your-category].md** - Study similar production devices
4. **02_DML_Anti_Patterns.md** - Avoid mistakes for your device type
5. **06_DML_Common_Patterns.md** - Start with basic template
6. **008-code-examples/** - Reference production patterns as you build

### For Timer/Counter Devices:
1. **07_DML_Register_Access_Scope.md** - **MANDATORY** - Prevent scope errors
2. **01_Simics_Modeling_Philosophy.md** - Understand lazy evaluation principle
3. **02_DML_Anti_Patterns.md** - **CRITICAL**: Read anti-patterns 1, 2, and 3
4. **04_DML_Timing_Timer_Modeling.md** - Complete guide and examples
5. **008-code-examples/008_timer.md** - Study production timer implementations
6. **05_DML_Troubleshooting.md** - For debugging

### For Serial Communication Devices (UART, I2C, I3C):
1. **07_DML_Register_Access_Scope.md** - **MANDATORY** - Prevent scope errors
2. **008-code-examples/009_uart.md** - UART production examples
3. **008-code-examples/006_i2c.md** - I2C production examples
4. **008-code-examples/007_i3c.md** - I3C production examples
5. **06_DML_Common_Patterns.md** - UART basic pattern
6. **003-DML-Language/** - Interface and protocol syntax

### For Quick Reference:
- **07_DML_Register_Access_Scope.md** - Register scope quick reference (check before every build)
- **003-DML-Language/** - Language syntax quick reference
- **04_DML_Timing_Timer_Modeling.md** - Timing quick reference card
- **06_DML_Common_Patterns.md** - Copy-paste templates
- **008-code-examples/000_overview.md** - Common DML patterns and navigation

### For Feature-Specific Implementation:
- **FIFOs and Buffers**: 008-code-examples/009_uart.md, 008-code-examples/001_dma.md
- **Interrupts**: 008-code-examples/002_interrupt_controller.md, 008-code-examples/009_uart.md
- **DMA**: 008-code-examples/001_dma.md
- **PCIe Capabilities**: 008-code-examples/004_pcie.md
- **Protocol State Machines**: 008-code-examples/006_i2c.md, 008-code-examples/007_i3c.md
- **Memory Translation**: 008-code-examples/003_mmu.md
- **Random Number Generation**: 008-code-examples/005_trng.md
- **Timing and Events**: 008-code-examples/008_timer.md, 04_DML_Timing_Timer_Modeling.md

---

## Document Maintenance

### Original Source
All documents extracted from: `DML_Best_Practices.md`

### Extraction Date
December 11, 2025

### Tested With
- Simics: 7.57.0
- DML: 1.4
- API: version 7

### Content Principles
All content is extracted **exactly** from the original best practices document. No external knowledge or common assumptions have been added. Each document contains only verified, tested information.

### Updates
When updating any document:
1. Maintain single-subject focus
2. Do not mix contexts between documents
3. Extract only from verified sources
4. Test all code examples
5. Update "Last Updated" timestamp
6. Cross-reference related documents when needed

---

## Additional Resources

### Documentation Library
- **Best Practices** (01-02, 04-07): Philosophy, anti-patterns, timing, troubleshooting, patterns, scope
- **Language Reference** (003-DML-Language/): Complete DML 1.4 specification (22 documents, 000-021)
- **Code Examples** (008-code-examples/): 353 production devices across 9 categories
- **Simics Documentation**: Model Builder User's Guide, DML 1.4 Reference Manual, API documentation

### See Also
- Simics Model Builder User's Guide - Official DML language reference
- DML 1.4 Reference Manual - Complete language specification
- Simics API documentation - C API for device models
- 008-code-examples/ - Production device implementations

### Getting Help
1. **Check troubleshooting guide first**: [05_DML_Troubleshooting.md](05_DML_Troubleshooting.md)
2. **Review anti-patterns document**: [02_DML_Anti_Patterns.md](02_DML_Anti_Patterns.md)
3. **Verify your code against examples**: [06_DML_Common_Patterns.md](06_DML_Common_Patterns.md) and [008-code-examples/](008-code-examples/)
4. **Check production implementations**: Search [008-code-examples/](008-code-examples/) for similar devices
5. **Use the quick reference sections**: Each document has quick-reference cards

---

**Document Status**: Complete  
**Last Updated**: December 18, 2025  
**Total Documents**: 7 best practices guides + 1 complete language reference (22 docs) + 1 code examples library (9 categories) + this index

**Recent Additions**:
- December 18, 2025: Replaced `03_DML_Basic_Syntax.md` with complete `003-DML-Language/` reference (22 documents)
- December 17, 2025: Added `008-code-examples/` documentation with 9 device categories and 353 production devices
- December 15, 2025: Added `07_DML_Register_Access_Scope.md` based on session analysis findings
