# DML Compilation and Runtime Issues - Troubleshooting Guide

## Overview

This document provides solutions to common compilation errors, runtime issues, and development problems encountered when working with DML device models in Simics.

## Table of Contents

1. [Compilation Issues](#compilation-issues)
2. [Runtime Issues](#runtime-issues)
3. [Testing and Build Issues](#testing-and-build-issues)
4. [Common Mistakes](#common-mistakes)

---

## Compilation Issues

### Issue 1: "syntax error at 'device'"

**Cause**: Using old DML syntax with braces after device declaration.

**Wrong Code:**
```dml
device my_device {
    param classname = "my_device";
    // ...
}
```

**Solution**: Remove braces from device declaration:
```dml
// ✅ Correct
device my_device;

param classname = "my_device";
```

---

### Issue 2: "cannot find file to import: dml-builtins.dml"

**Cause**: Missing include path for DML builtins.

**Wrong Command:**
```bash
dmlc --simics-api=7 file.dml output
```

**Solution**: Add both include paths:
```bash
dmlc --simics-api=7 -I ../linux64/bin/dml/api/7/1.4 -I ../linux64/bin/dml/1.4 file.dml output
```

**Critical Points:**
- `-I ../linux64/bin/dml/api/7/1.4`: Include path for Simics API
- `-I ../linux64/bin/dml/1.4`: Include path for DML builtins

---

### Issue 3: "assert sys.flags.utf8_mode"

**Cause**: Python not running in UTF-8 mode.

**Solution**: Set environment variable or modify dmlc script:

```bash
# Method 1: Environment variable
export PYTHONUTF8=1

# Method 2: Modified dmlc script (recommended)
# Edit the dmlc script to include:
exec env PYTHONUTF8=1 "$_MINI_PYTHON" "$DMLC_DIR/dml/python" "$@"
```

---

### Issue 4: "unknown template: 'device'"

**Cause**: DML builtins not found in include path.

**Solution**: Ensure `-I ../linux64/bin/dml/1.4` is included in the compilation command.

---

### Issue 5: "syntax error at 'except'" - Python Syntax in DML

**Cause**: DML is C-like, NOT Python.

**Wrong Code:**
```dml
try {
    some_method();
} except {  // ❌ Python syntax!
    log error: "Error occurred";
}
```

**Correct Code:**
```dml
try {
    some_method();
} catch {  // ✅ C/C++ syntax
    log error: "Error occurred";
}
```

**Key Differences (DML/C vs Python)**:
- Exception handling: `catch` not `except`
- Blocks: `{ }` not indentation
- Statements: end with `;`
- Comments: `//` or `/* */` not `#`
- Boolean: `true`/`false` not `True`/`False`

---

## Runtime Issues

### Issue 7: AttributeError in module_load.py - "object has no attribute 'X'"

**Cause**: `module_load.py` references non-existent device attributes. Auto-generated attributes follow `<bank_name>_<register_name>` pattern.

**Wrong Code** (in `module_load.py`):
```python
def get_status(obj):
    return [("Registers",
             [("Counter", obj.wrong_attr_name)])]  # ❌ Attribute doesn't exist!
```

**How to Fix**:

1. **Check DML for actual bank/register names**:
   ```bash
   grep "^bank " simics-project/modules/<device>/<device>.dml
   grep "register " simics-project/modules/<device>/<device>.dml
   ```

2. **Use correct attribute pattern**: `obj.<BankName>_<RegisterName>`
   ```python
   # If DML has: bank MyBankName { register MY_REG { ... } }
   # Then use:
   def get_status(obj):
       return [("Registers",
                [("Register Value", obj.MyBankName_MY_REG)])]  # ✅ Correct!
   ```

**Attribute Naming Rules**:
- Pattern: `device_obj.<BankName>_<RegisterName>`
- Bank `<bank1>` + register `<REG1>` → `obj.<bank1>_<REG1>`
- Bank `<bank2>` + register `<REG2>` → `obj.<bank2>_<REG2>`
- Use exact names from DML (case-sensitive)

**If No Suitable Attribute Exists**:
Just remove or comment out the status display code:
```python
def get_status(obj):
    return []  # No status to report
```

**Key Point**: `module_load.py` is auto-generated from DML structure. If you modify it manually, ensure attributes match DML bank/register declarations.

---

## Testing and Build Issues

### Issue 6: Tests Unchanged After DML Edits

**Cause**: Forgot to rebuild. Tests run against old `.so` binary, not new `.dml` source.

**The Problem**: 
- You edit the `.dml` file
- You run tests immediately
- Tests still fail with old behavior
- **Why?** DML compiles to `.so` shared libraries. Simics loads `.so`, not `.dml`. No rebuild = old code runs.

**Mandatory Cycle: Edit → Build → Test**

```bash
# 1. Edit
vim simics-project/modules/<device>/<device>.dml

# 2. BUILD (CRITICAL - don't skip!)
cd simics-project && make <device>

# 3. Test
bin/test-runner --suite modules/<device>/test/

# 4. Verify build happened
ls -lh linux64/lib/<device>.so  # Check timestamp is recent
```

**Quick Verification**:
```bash
# Check if .so is newer than .dml
stat -c '%Y %n' simics-project/modules/<device>/<device>.dml
stat -c '%Y %n' simics-project/linux64/lib/<device>.so

# The .so timestamp should be AFTER .dml timestamp
```

**Pro Tip**: Set up auto-rebuild in your workflow:
```bash
# Create a test script that always rebuilds first
#!/bin/bash
cd simics-project
make <device> && bin/test-runner --suite modules/<device>/test/
```

---

## Common Mistakes

### Mistake 1: Forgetting to Import Required DML Files

**Problem**:
```dml
dml 1.4;
device my_device;

bank regs {
    register r0 size 4 @ 0x00;
}
// ❌ Compilation error: unknown templates, missing methods
```

**Solution**:
```dml
dml 1.4;
device my_device;

import "simics/device-api.dml";  // ✅ Always import this

bank regs {
    register r0 size 4 @ 0x00;
}
```

---

### Mistake 2: Using Wrong Method Signatures

**Problem**:
```dml
register CONTROL {
    // ❌ Wrong signature for read_register
    method read_register() -> (uint64) {
        return this.val;
    }
}
```

**Solution**:
```dml
register CONTROL {
    // ✅ Correct signature with required parameters
    method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
        return this.val;
    }
}
```

---

### Mistake 3: Incorrect Register Offset Syntax

**Problem**:
```dml
bank regs {
    register r0 @ 0x00 size 4;  // ❌ Wrong order
}
```

**Solution**:
```dml
bank regs {
    register r0 size 4 @ 0x00;  // ✅ Correct: size before offset
}
```

---

### Mistake 4: Missing Default Call in Override Methods

**Problem**:
```dml
register CONTROL {
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        if (value & 0x1) {
            enable_device();
        }
        // ❌ Forgot to actually write the value to the register!
    }
}
```

**Solution**:
```dml
register CONTROL {
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        // ✅ Call default first to write the value
        default(value, enabled_bytes, aux);
        
        // Then perform custom logic
        if (value & 0x1) {
            enable_device();
        }
    }
}
```

---

### Mistake 5: Accessing Uninitialized Fields

**Problem**:
```dml
register CONTROL {
    field enable @ [0];
    
    method init() {
        // ❌ Field might not be initialized yet
        if (enable.val == 1) {
            start_device();
        }
    }
}
```

**Solution**:
```dml
register CONTROL {
    field enable @ [0];
    param init_val = 0;  // ✅ Set initial value
    
    method post_init() {
        // ✅ Use post_init instead of init for field access
        if (enable.val == 1) {
            start_device();
        }
    }
}
```

---

### Mistake 6: Incorrect Log Syntax

**Problem**:
```dml
method my_method() {
    log "Device started";  // ❌ Missing log level and colon
}
```

**Solution**:
```dml
method my_method() {
    log info: "Device started";  // ✅ Correct syntax
    log error: "Error occurred";
    log info, 2: "Detailed info at level 2";
}
```

---

### Mistake 7: Using Undefined Constants

**Problem**:
```dml
bank regs {
    register STATUS @ 0x04 {
        param init_val = STATUS_READY;  // ❌ Undefined constant
    }
}
```

**Solution**:
```dml
// ✅ Define constant first
constant STATUS_READY = 0x1;

bank regs {
    register STATUS @ 0x04 {
        param init_val = STATUS_READY;  // ✅ Now it's defined
    }
}
```

---

### Mistake 8: Mixing Register Access Methods

**Problem**:
```dml
register CONTROL is (read, write) {
    method read() -> (uint64) {
        return this.val;
    }
    
    // ❌ Mixing read/write template with read_register/write_register
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        this.val = value;
    }
}
```

**Solution**: Choose one approach:

**Option 1: Use templates**
```dml
register CONTROL is (read, write) {
    method read() -> (uint64) {
        return this.val;
    }
    
    method write(uint64 value) {
        this.val = value;
    }
}
```

**Option 2: Use full methods**
```dml
register CONTROL {
    method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
        return this.val;
    }
    
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        this.val = value;
    }
}
```

---

## Debugging Tips

### Enable Verbose Logging

```dml
loggroup device_log;

method my_method() {
    log info, 1, device_log: "Level 1 message - always shown";
    log info, 2, device_log: "Level 2 message - more detailed";
    log info, 3, device_log: "Level 3 message - very detailed";
}
```

Run Simics with increased log level:
```bash
simics> log-level device_log 3
```

### Check Device Registration

```python
# In Simics console
simics> list-classes
simics> print-device-info <device_class>
```

### Verify Register Mappings

```python
# Check bank mapping
simics> <device>.bank.<bank_name>.base
simics> <device>.bank.<bank_name>.size

# Read/write registers
simics> <device>.bank.<bank_name>.<register_name>
simics> <device>.bank.<bank_name>.<register_name> = 0x123
```

### Use GDB for C-level Debugging

```bash
# Build with debug symbols
make DEBUG=1 <device>

# Run Simics under GDB
gdb --args simics/bin/simics <script>
```

---

## Summary: Common Issue Checklist

Before asking for help, check:

- [ ] DML version declared: `dml 1.4;`
- [ ] Device declared correctly: `device name;` (no braces)
- [ ] Required imports included: `import "simics/device-api.dml";`
- [ ] Compilation flags correct: both `-I` paths included
- [ ] UTF-8 mode enabled: `PYTHONUTF8=1`
- [ ] Project rebuilt after editing: `make <device>`
- [ ] `.so` timestamp newer than `.dml` timestamp
- [ ] Method signatures match expected format
- [ ] `default()` called in override methods when needed
- [ ] Log statements have correct syntax: `log level: "message"`
- [ ] Constants defined before use
- [ ] Consistent register access method (templates OR full methods)

---

**Document Status**: ✅ Complete  
**Extracted From**: DML_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Tested With**: Simics 7.57.0, DML 1.4, API version 7
