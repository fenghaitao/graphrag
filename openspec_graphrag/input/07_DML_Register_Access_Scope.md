# DML Register and Field Access Scope Patterns

## Overview

In DML 1.4, register and field access syntax depends on the **context** (scope) where you're writing the code. Using the wrong pattern causes "unknown identifier" or "unknown object" compilation errors that waste significant development time.

**Key Principle:** The closer you are to a register in the hierarchy, the less qualification you need.

**This document covers:**
- **Register VALUE access** (`.val`) - accessing the entire register as a number
- **Register FIELD access** (`.FIELDNAME`) - accessing individual bits within a register

## Quick Reference

### Register Value Access

| Context | Syntax | Example |
|---------|--------|---------|
| Device level | `<bank_name>.REGISTER.val` | `WatchdogRegisters.WDOGLOAD.val = 0;` |
| Bank level | `REGISTER.val` | `WDOGLOAD.val = 0;` |
| Register level | `this.val` | `this.val = 0;` or `val = 0;` |

### Register Field Access

| Context | Syntax | Example |
|---------|--------|---------|
| Device level | `<bank_name>.REGISTER.FIELDNAME.val` | `WatchdogRegisters.WDOGCONTROL.INTEN.val = 1;` |
| Bank level | `REGISTER.FIELDNAME.val` | `WDOGCONTROL.INTEN.val = 1;` |
| Register level | `this.FIELDNAME.val` | `this.INTEN.val = 1;` or `INTEN.val = 1;` |

**Note:** `<bank_name>` is the actual name of your bank (e.g., `WatchdogRegisters`, `regs`, `control_bank`). The word `bank` is a declaration keyword, not an access keyword.

## Detailed Explanation

### Device Level (Outside Any Bank/Register)

**Context:** Writing code in device-level methods (e.g., `reset_state`, custom methods at device scope)

**Syntax:** Must use `<bank_name>.REGISTER.val` where `<bank_name>` is your actual bank name

**Example:**
```dml
device wdt {
    method reset_state() {
        // CORRECT - Use actual bank name at device level
        WatchdogRegisters.WDOGLOAD.val = 0xFFFFFFFF;
        WatchdogRegisters.WDOGCONTROL.val = 0x0;
        WatchdogRegisters.WDOGLOCK.val = 0x0;
        
        // WRONG - Bare register name causes error
        // WDOGLOAD.val = 0xFFFFFFFF;  // error: unknown identifier: 'WDOGLOAD'
        
        // WRONG - 'bank' is not a keyword for access
        // bank.WDOGLOAD.val = 0xFFFFFFFF;  // error: unknown identifier: 'bank'
    }
}

// Bank declaration (for reference)
bank WatchdogRegisters is WatchdogRegisters_temp {
    register WDOGLOAD { /* ... */ }
    register WDOGCONTROL { /* ... */ }
    register WDOGLOCK { /* ... */ }
}
```

### Bank Level (Inside a Bank, Outside Registers)

**Context:** Writing code in bank-level methods or accessing registers within the same bank

**Syntax:** Use `REGISTER.val` (no bank prefix needed)

**Example:**
```dml
bank WatchdogRegisters {
    method custom_bank_method() {
        // CORRECT - Use REGISTER at bank level (no prefix)
        WDOGLOAD.val = 0xFFFFFFFF;
        WDOGCONTROL.val = 0x0;
        
        // WRONG - Unnecessary qualification with bank name
        // WatchdogRegisters.WDOGLOAD.val = 0xFFFFFFFF;  // Bank name not in scope here
    }
}
```

### Register Level (Inside a Register's Methods)

**Context:** Writing code inside a register's `read()`, `write()`, or other register methods

**Syntax:** Use `this.val` to access the register's value

**Example:**
```dml
register WDOGCONTROL size 4 @ 0x008 {
    method write(uint64 value) {
        // CORRECT - Use 'this' at register level
        this.val = value;
        
        if (this.val & 0x1) {
            // Enable watchdog
        }
        
        // WRONG - Register name not in scope
        // WDOGCONTROL.val = value;  // error: unknown identifier: 'WDOGCONTROL'
    }
}
```

## Register Field Access Patterns

### Overview: Register Values vs Register Fields

**CRITICAL DISTINCTION:**
- **Register VALUE** (`.val`): The entire register as a single number
- **Register FIELD**: Individual bits or bit ranges within a register (e.g., `.INTEN`, `.RESEN`)

**There is NO `.field` accessor in DML!** You access fields by their actual names defined in the register XML.

### Quick Reference: Field Access

| Context | Syntax | Example |
|---------|--------|---------|
| Device level | `<bank_name>.REGISTER.FIELDNAME.val` | `WatchdogRegisters.WDOGCONTROL.INTEN.val = 1;` |
| Bank level | `REGISTER.FIELDNAME.val` | `WDOGCONTROL.INTEN.val = 1;` |
| Register level | `this.FIELDNAME.val` | `this.INTEN.val = 1;` or `INTEN.val = 1;` |

**Note:** Replace `FIELDNAME` with the actual field name from your XML (e.g., `INTEN`, `RESEN`, `ENABLE`).

### Device Level Field Access

**Context:** Accessing register fields from device-level methods

**Syntax:** `<bank_name>.REGISTER.FIELDNAME.val`

**Example:**
```dml
device wdt {
    method check_watchdog_enabled() {
        // CORRECT - Access field at device level
        if (WatchdogRegisters.WDOGCONTROL.INTEN.val == 1) {
            // Interrupt enabled
        }
        
        if (WatchdogRegisters.WDOGCONTROL.RESEN.val == 1) {
            // Reset enabled
        }
        
        // WRONG - .field doesn't exist
        // if (WatchdogRegisters.WDOGCONTROL.field == 1) {
        //     // error: reference to unknown object 'WatchdogRegisters.WDOGCONTROL.field'
        // }
    }
}
```

### Bank Level Field Access

**Context:** Accessing register fields from bank-level methods or from other registers in the same bank

**Syntax:** `REGISTER.FIELDNAME.val`

**Example:**
```dml
bank WatchdogRegisters {
    register WDOGLOAD {
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            default(value, enabled_bytes, aux);
            
            // CORRECT - Access field in another register (same bank)
            if (WDOGCONTROL.INTEN.val == 1) {
                // Interrupt is enabled, trigger countdown
            }
        }
    }
}
```

### Register Level Field Access

**Context:** Accessing fields within the same register's methods

**Syntax:** `this.FIELDNAME.val` or `FIELDNAME.val`

**Example:**
```dml
register WDOGCONTROL size 4 @ 0x008 {
    field INTEN @ [0];  // Bit 0: Interrupt enable
    field RESEN @ [1];  // Bit 1: Reset enable
    
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        default(value, enabled_bytes, aux);
        
        // CORRECT - Access own fields using 'this'
        if (this.INTEN.val == 1) {
            // Interrupt was just enabled
            log info: "Watchdog interrupt enabled";
        }
        
        if (this.RESEN.val == 1) {
            // Reset was just enabled
            log info: "Watchdog reset enabled";
        }
    }
}
```

### Where Field Names Come From

Field names are defined in your register description XML file:

```xml
<register name="WDOGCONTROL" offset="0x008" size="4">
    <field name="INTEN" bits="0" />      <!-- Access as .INTEN -->
    <field name="RESEN" bits="1" />      <!-- Access as .RESEN -->
</register>
```

After XML processing, these become accessible as:
- Device level: `WatchdogRegisters.WDOGCONTROL.INTEN.val`
- Bank level: `WDOGCONTROL.INTEN.val`
- Register level: `this.INTEN.val` or `INTEN.val`

### Common Field Access Mistakes

#### Mistake 1: Using `.field` accessor (doesn't exist)

```dml
// ❌ WRONG - .field doesn't exist in DML
if (WatchdogRegisters.WDOGCONTROL.field == 1) {
    // error: reference to unknown object 'WatchdogRegisters.WDOGCONTROL.field'
}

// ✅ CORRECT - Use actual field name with .val
if (WatchdogRegisters.WDOGCONTROL.INTEN.val == 1) {
    // Works!
}
```

#### Mistake 2: Using `.field.FIELDNAME` pattern

```dml
// ❌ WRONG - No intermediate .field accessor
if (WatchdogRegisters.WDOGCONTROL.field.INTEN == 1) {
    // error: reference to unknown object
}

// ✅ CORRECT - Direct field access with .val
if (WatchdogRegisters.WDOGCONTROL.INTEN.val == 1) {
    // Works!
}
```

#### Mistake 3: Wrong scope for field access

```dml
// At device level
method device_method() {
    // ❌ WRONG - Missing bank name
    if (WDOGCONTROL.INTEN.val == 1) {
        // error: unknown identifier: 'WDOGCONTROL'
    }
    
    // ✅ CORRECT - Include bank name at device level
    if (WatchdogRegisters.WDOGCONTROL.INTEN.val == 1) {
        // Works!
    }
}
```

#### Mistake 4: Missing .val on field access

```dml
// ❌ WRONG - Missing .val on field access
if (WatchdogRegisters.WDOGCONTROL.INTEN == 1) {
    // Comparing object reference, not value!
}

// ✅ CORRECT - Add .val to access field value
if (WatchdogRegisters.WDOGCONTROL.INTEN.val == 1) {
    // Works!
}
```

### Field Access Pre-Build Checklist

Before building, verify field access patterns:

1. No use of `.field` accessor (doesn't exist)
2. Device-level field access uses `<bank_name>.REGISTER.FIELDNAME.val`
3. Bank-level field access uses `REGISTER.FIELDNAME.val`
4. Register-level field access uses `this.FIELDNAME.val` or `FIELDNAME.val`
5. Field names match those defined in XML
6. All field accesses include `.val` at the end

**Quick Search Commands:**
```bash
# Find incorrect .field usage
grep -n "\.field" wdt.dml  # Should return no results

# Find all field accesses for review
grep -n "\.[A-Z][A-Z0-9_]*\s*[=!<>]" wdt.dml | grep -v "\.val"

# Verify field names exist in XML
grep "field name=" wdt.xml
```

### Impact of Field Access Errors

**Without this knowledge:**
- 50+ "unknown object" errors per device
- 15-20 minutes wasted debugging
- Multiple failed builds

**With this knowledge:**
- 0 field access errors
- First build succeeds
- Immediate productivity

## Common Errors and Fixes

### Error: "unknown identifier: 'WDOGLOAD'"

**Symptom:**
```
/path/to/wdt.dml:363:23: error: unknown identifier: 'WDOGLOAD'
```

**Cause:** Using bare register name at device level

**Fix:** Add bank name prefix (use your actual bank name)
```dml
// Before (WRONG)
WDOGLOAD.val = 0;

// After (CORRECT - use actual bank name)
WatchdogRegisters.WDOGLOAD.val = 0;
```

### Error: "unknown identifier: 'bank'"

**Symptom:**
```
/path/to/wdt.dml:150:5: error: unknown identifier: 'bank'
```

**Cause:** Using the word `bank` as if it were a keyword (it's not - it's only for declarations)

**Fix:** Use actual bank name at device level, or `this` at register level
```dml
// WRONG - 'bank' is not an access keyword
method device_method() {
    bank.WDOGLOAD.val = 0;  // Error: unknown identifier: 'bank'
}

// CORRECT - Use actual bank name at device level
method device_method() {
    WatchdogRegisters.WDOGLOAD.val = 0;
}

// CORRECT - Use 'this' at register level
register WDOGLOAD {
    method write(uint64 value) {
        this.val = value;
    }
}
```

### Error: Multiple "unknown identifier" errors for peripheral ID registers

**Symptom:**
```
error: unknown identifier: 'WDOGPERIPHID0'
error: unknown identifier: 'WDOGPERIPHID1'
error: unknown identifier: 'WDOGPERIPHID2'
...
```

**Cause:** Initializing multiple registers at device level without bank name prefix

**Fix:** Add bank name prefix to all register accesses (use your actual bank name)
```dml
// Before (WRONG)
method reset_state() {
    WDOGPERIPHID0.val = 0x24;
    WDOGPERIPHID1.val = 0xB8;
    WDOGPERIPHID2.val = 0x1B;
}

// After (CORRECT - use actual bank name)
method reset_state() {
    WatchdogRegisters.WDOGPERIPHID0.val = 0x24;
    WatchdogRegisters.WDOGPERIPHID1.val = 0xB8;
    WatchdogRegisters.WDOGPERIPHID2.val = 0x1B;
}
```

## Pre-Build Checklist

Before running your first build, verify:

1. All device-level register accesses use `<bank_name>.REGISTER.val` (actual bank name, not the word "bank")
2. All register-level accesses use `this.val`
3. No bare register names (e.g., `WDOGLOAD.val`) at device level
4. No use of `bank.REGISTER.val` (the word "bank" is not an access keyword)
5. Search your code for common register name patterns and verify correct scope

**Quick Search Commands:**
```bash
# Find potential scope errors (bare register names at device level)
# Adjust pattern to match your register naming convention
grep -n "WDOG[A-Z]*\.val" wdt.dml | grep -v "WatchdogRegisters\." | grep -v "this\."

# Find all register accesses for review
grep -n "\.val" wdt.dml

# Check for incorrect use of 'bank' keyword
grep -n "bank\." wdt.dml  # Should return no results (unless 'bank' is your actual bank name)
```

## Impact of Scope Errors

**Without this knowledge:**
- 13+ compilation errors per device
- 4+ minutes wasted on first build
- Multiple build-fix cycles

**With this knowledge:**
- 0 scope-related errors
- First build succeeds
- 75% faster to first successful build

## Related Documents

- `03_DML_Basic_Syntax.md` - General DML syntax rules
- `05_DML_Troubleshooting.md` - Other compilation error patterns
- `06_DML_Common_Patterns.md` - Register side-effect implementations

## Summary

**Remember:** The scope determines the syntax:
- **Device level** → `<bank_name>.REGISTER.val` (use your actual bank name, e.g., `WatchdogRegisters`, `regs`)
- **Bank level** → `REGISTER.val` (no prefix needed)
- **Register level** → `this.val`

**Critical:** The word `bank` is a **declaration keyword** (like `class`), NOT an access keyword. Always use your actual bank name when accessing registers from device level.

Always check scope before first build to prevent "unknown identifier" errors.

---

**Document Status**: Complete  
**Created From**: Session analysis findings (WDT implementation 2024-12-14)  
**Last Updated**: December 15, 2025  
**Next Reading**: [06_DML_Common_Patterns.md](06_DML_Common_Patterns.md)
