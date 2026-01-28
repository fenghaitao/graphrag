# Register Access and Testing in Simics Tests

## Overview

This document covers how to access and test device registers in Simics test files, including:
- Finding and accessing banks and registers from DML definitions
- Writing Python statements to read/write registers and fields
- Common register access patterns and testing strategies
- Troubleshooting register access errors

## Table of Contents

1. [Finding Bank Names](#finding-bank-names)
2. [Using bank_regs (Recommended)](#using-bank_regs-recommended)
3. [Register Read/Write Operations](#register-readwrite-operations)
4. [Field Access](#field-access)
5. [Using Register_LE/BE](#using-register_lebe)
6. [Common Register Testing Errors](#common-register-testing-errors)

---

## Finding Bank Names

### ⚠️ CRITICAL: Always Read DML First

**Bank names in DML map directly to Python attributes. You MUST read the DML file to find the exact bank name.**

```dml
// In device.dml:
bank regs {          // ← Bank name is "regs" (could be any name)
    register CONTROL @ 0x00 size 4 { ... }
    register STATUS @ 0x04 size 4 { ... }
}
```

```python
# In test.py - use the EXACT bank name from DML:
regs = dev_util.bank_regs(conf.dev.bank.regs)  # ✅ Correct: matches DML "bank regs"
```

### Bank Name Examples

```dml
// Example 1: bank named "regs"
bank regs { ... }
```
```python
regs = dev_util.bank_regs(device.bank.regs)  # ✅ Use "regs"
```

```dml
// Example 2: bank named "reg_if"
bank reg_if { ... }
```
```python
regs = dev_util.bank_regs(device.bank.reg_if)  # ✅ Use "reg_if"
```

```dml
// Example 3: bank named "control_registers"
bank control_registers { ... }
```
```python
regs = dev_util.bank_regs(device.bank.control_registers)  # ✅ Use "control_registers"
```

### ⚠️ CRITICAL: Include .bank. Namespace

**ALWAYS use `device.bank.<bank_name>`, NOT `device.<bank_name>` directly!**

```python
# ❌ WRONG - Missing .bank. namespace:
regs = dev_util.bank_regs(dut.regs)  # ❌ WRONG! Missing .bank.

# ✅ CORRECT - Include .bank. namespace:
regs = dev_util.bank_regs(dut.bank.regs)  # ✅ Correct! device.bank.<bank_name>
```

**Pattern:** `device.bank.<bank_name>` is ALWAYS required
- DML: `bank regs { ... }` → Python: `device.bank.regs`
- DML: `bank reg_if { ... }` → Python: `device.bank.reg_if`
- DML: `bank ctrl { ... }` → Python: `device.bank.ctrl`

### ❌ Anti-Pattern: Never Scan/Discover Banks

```python
# ❌ WRONG - Never write defensive discovery code:
for name in ['reg_if', 'regif', 'regs', 'bank']:  # ❌ Unnecessary complexity
    try:
        obj = getattr(dev, name)
        regs = dev_util.bank_regs(obj)
        break
    except:
        pass

# ✅ CORRECT - Read DML, use exact bank name:
regs = dev_util.bank_regs(conf.dev.bank.regs)  # Replace 'regs' with actual name from DML
```

**Workflow:**
1. Read `<device>.dml`, find `bank <bank_name> { ... }`
2. Use `dev_util.bank_regs(conf.device.bank.<bank_name>)` with exact bank name from step 1
3. Never guess or scan - the bank name is always explicit in DML

---

## Using bank_regs (Recommended)

### ⚠️ CRITICAL: Always Wrap Banks with dev_util.bank_regs()

**NEVER access registers directly via `device.bank.<bank_name>`!**
**ALWAYS use `dev_util.bank_regs(device.bank.<bank_name>)`!**

```python
# ❌ WRONG - Direct access to registers (missing dev_util.bank_regs wrapper):
def run():
    (dut, pic) = create_config()
    
    # ❌ WRONG! Direct access without dev_util.bank_regs()
    wdt = dut.bank.wdt_regs
    wdt.WDOGLOAD.write(0x10)  # ❌ FAILS! No write() method on bank object

# ✅ CORRECT - Use dev_util.bank_regs() wrapper:
def run():
    (dut, pic) = create_config()
    
    # ✅ CORRECT! Wrap with dev_util.bank_regs()
    wdt = dev_util.bank_regs(dut.bank.wdt_regs)
    wdt.WDOGLOAD.write(0x10)  # ✅ WORKS! bank_regs() provides read/write API
```

### Why This Matters

- `device.bank.<bank_name>` is a **raw Simics bank object** without convenient read/write methods
- `dev_util.bank_regs()` creates a **proxy wrapper** with easy `.read()` and `.write()` methods
- Direct bank access requires low-level Simics APIs and is error-prone
- **ALWAYS wrap with `dev_util.bank_regs()` for register testing**

### Correct Pattern

```python
# Step 1: Get device from create_config()
(dut, clk) = create_config()

# Step 2: ALWAYS wrap bank with dev_util.bank_regs()
regs = dev_util.bank_regs(dut.bank.<bank_name>)  # ✅ Required wrapper

# Step 3: Now use convenient register API
regs.CONTROL.write(0x1)
value = regs.STATUS.read()
```

---

## Register Read/Write Operations

### Basic Register Access

```python
import dev_util
import stest

# Setup
(device, clock) = create_config()
regs = dev_util.bank_regs(device.bank.regs)  # Use exact bank name from DML

# Write full register value
regs.CONTROL.write(0xDEADBEEF)

# Read full register value
value = regs.CONTROL.read()
stest.expect_equal(value, 0xDEADBEEF, "CONTROL register mismatch")
```

### Register Names from DML

```dml
// In DML:
bank regs {
    register CONTROL @ 0x00 size 4 { ... }
    register STATUS @ 0x04 size 4 { ... }
    register DATA @ 0x08 size 4 { ... }
}
```

```python
# In test - register names match DML exactly:
regs.CONTROL.write(0x1)   # ✅ Matches DML register CONTROL
regs.STATUS.read()        # ✅ Matches DML register STATUS
regs.DATA.write(0x42)     # ✅ Matches DML register DATA
```

### Testing Read-Only Registers

```python
# Read-only register should ignore writes
initial = regs.STATUS.read()
regs.STATUS.write(0xFFFFFFFF)  # Try to write
final = regs.STATUS.read()
stest.expect_equal(final, initial, "Read-only register was modified")
```

### Testing Write-Only Registers

```python
# Write-only register - write doesn't affect read value
regs.COMMAND.write(0x1)  # Trigger command
# Reading write-only register typically returns 0 or undefined
value = regs.COMMAND.read()
# Don't assert on read value for write-only registers
```

### Testing Default Values

```python
# Test register defaults after reset
(device, clock) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Read initial values (should match DML defaults)
stest.expect_equal(regs.CONTROL.read(), 0x0, "CONTROL default mismatch")
stest.expect_equal(regs.STATUS.read(), 0x1, "STATUS default should be 0x1")
```

---

## Field Access

### Field Read/Write

```python
# Write specific fields (Read-Modify-Write)
regs.STATUS.write(dev_util.READ, enable=1, mode=3)

# Read specific field
enable_value = regs.STATUS.field.enable.read()
stest.expect_equal(enable_value, 1, "Enable field mismatch")

mode_value = regs.STATUS.field.mode.read()
stest.expect_equal(mode_value, 3, "Mode field mismatch")
```

### Field Definition from DML

```dml
// In DML:
register STATUS @ 0x04 size 4 {
    field enable @ [0];      // Bit 0
    field mode @ [2:1];      // Bits 2-1
    field reserved @ [31:3]; // Bits 31-3
}
```

```python
# In test - field names match DML:
regs.STATUS.field.enable.read()   # ✅ Matches DML field enable
regs.STATUS.field.mode.read()     # ✅ Matches DML field mode
```

### Read-Modify-Write Pattern

```python
# dev_util.READ tells write() to read current value first
regs.CONTROL.write(dev_util.READ, enable=1)  # Only modify enable bit

# Equivalent to:
# 1. Read current CONTROL value
# 2. Set enable bit to 1
# 3. Write modified value back
```

### Testing Individual Fields

```python
# Test field write and read
regs.CONTROL.write(0x0)  # Clear register
regs.CONTROL.write(dev_util.READ, enable=1, mode=2)

stest.expect_equal(regs.CONTROL.field.enable.read(), 1, "Enable bit not set")
stest.expect_equal(regs.CONTROL.field.mode.read(), 2, "Mode bits incorrect")

# Verify full register value
expected = (1 << 0) | (2 << 1)  # enable=1 at bit 0, mode=2 at bits 2:1
stest.expect_equal(regs.CONTROL.read(), expected, "Register value mismatch")
```

### Multi-Bit Fields

```dml
// DML: 4-bit field
register CONFIG {
    field priority @ [7:4];  // 4 bits
}
```

```python
# Test full range of multi-bit field
regs.CONFIG.write(dev_util.READ, priority=0xF)
stest.expect_equal(regs.CONFIG.field.priority.read(), 0xF, "Priority max value")

regs.CONFIG.write(dev_util.READ, priority=0x0)
stest.expect_equal(regs.CONFIG.field.priority.read(), 0x0, "Priority min value")

regs.CONFIG.write(dev_util.READ, priority=0x5)
stest.expect_equal(regs.CONFIG.field.priority.read(), 0x5, "Priority mid value")
```

---

## Using Register_LE/BE

### When to Use Register_LE/BE

Use `Register_LE` (Little Endian) or `Register_BE` (Big Endian) when you need to:
- Test specific byte offsets explicitly
- Test endianness behavior
- Create register proxies with custom bitfield layouts

### Basic Register_LE Usage

```python
import dev_util

# Create Little Endian register proxy
control = dev_util.Register_LE(
    device.bank.regs,  # Bank object (exact name from DML)
    0x00,              # Register offset within bank
    size=4,            # Register size in bytes
    bitfield=dev_util.Bitfield_LE({
        'enable': 0,        # Single bit at position 0
        'mode': (2, 1)      # Multi-bit field: bits 2:1
    })
)

# Write register
control.write(0x80000007)

# Read fields
stest.expect_equal(control.enable, 1, "Enable bit mismatch")
stest.expect_equal(control.mode, 3, "Mode field mismatch")
```

### Register_BE (Big Endian)

```python
# Create Big Endian register proxy
status = dev_util.Register_BE(
    device.bank.regs,
    0x04,              # Offset
    size=4,
    bitfield=dev_util.Bitfield_BE({
        'ready': 31,       # Bit 31 (MSB in BE)
        'error': (30, 28)  # Bits 30:28
    })
)

status.write(0x80000000)
stest.expect_equal(status.ready, 1, "Ready bit mismatch")
```

### Bitfield Syntax

```python
# Single bit field
bitfield = dev_util.Bitfield_LE({
    'enable': 0,     # Bit 0
    'ready': 31      # Bit 31
})

# Multi-bit field
bitfield = dev_util.Bitfield_LE({
    'mode': (2, 1),      # Bits 2:1 (2 bits wide)
    'priority': (7, 4)   # Bits 7:4 (4 bits wide)
})

# Mixed
bitfield = dev_util.Bitfield_LE({
    'enable': 0,         # Single bit
    'mode': (2, 1),      # Multi-bit
    'status': (7, 3)     # Multi-bit
})
```

### Complete Register_LE Example

```python
import dev_util
import stest

(device, clock) = create_config()

# Define register with bitfields
timer_ctrl = dev_util.Register_LE(
    device.bank.regs,
    0x00,  # TIMER_CONTROL at offset 0x00
    size=4,
    bitfield=dev_util.Bitfield_LE({
        'enable': 0,           # Bit 0: Timer enable
        'mode': (2, 1),        # Bits 2:1: Timer mode (00=one-shot, 01=periodic)
        'prescaler': (7, 3)    # Bits 7:3: Prescaler value
    })
)

# Test field write
timer_ctrl.write(0x0)
timer_ctrl.enable = 1
timer_ctrl.mode = 1
timer_ctrl.prescaler = 0xF

# Verify fields
stest.expect_equal(timer_ctrl.enable, 1, "Enable not set")
stest.expect_equal(timer_ctrl.mode, 1, "Mode incorrect")
stest.expect_equal(timer_ctrl.prescaler, 0xF, "Prescaler incorrect")

# Verify full register
expected = (1 << 0) | (1 << 1) | (0xF << 3)
stest.expect_equal(timer_ctrl.read(), expected, "Register value mismatch")
```

---

## Common Register Testing Errors

### Error 1: Missing .bank. Namespace

```
AttributeError: 'conf_object' object has no attribute 'regs'
```

**Fix:**
```python
# ❌ WRONG
regs = dev_util.bank_regs(device.regs)

# ✅ CORRECT
regs = dev_util.bank_regs(device.bank.regs)  # Include .bank.
```

### Error 2: Not Using dev_util.bank_regs()

```
AttributeError: 'bank_object' has no attribute 'write'
```

**Fix:**
```python
# ❌ WRONG
regs = device.bank.regs
regs.CONTROL.write(0x1)  # Fails - no write() method

# ✅ CORRECT
regs = dev_util.bank_regs(device.bank.regs)
regs.CONTROL.write(0x1)  # Works - bank_regs() provides write()
```

### Error 3: Wrong Bank Name

```
AttributeError: 'conf_object' has no attribute 'regif'
```

**Fix:** Read DML to find correct bank name
```dml
// In DML:
bank regs { ... }  // Not "regif"
```
```python
# ✅ CORRECT
regs = dev_util.bank_regs(device.bank.regs)  # Use exact name from DML
```

### Error 4: Wrong Register Name

```
AttributeError: 'bank_regs' object has no attribute 'CTRL'
```

**Fix:** Read DML to find correct register name
```dml
// In DML:
register CONTROL { ... }  // Not "CTRL"
```
```python
# ✅ CORRECT
regs.CONTROL.write(0x1)  # Use exact name from DML
```

### Error 5: Wrong Field Name

```
AttributeError: 'field_proxy' object has no attribute 'en'
```

**Fix:** Read DML to find correct field name
```dml
// In DML:
field enable @ [0];  // Not "en"
```
```python
# ✅ CORRECT
regs.CONTROL.field.enable.read()  # Use exact name from DML
```

---

## Complete Register Testing Example

```python
import simics
import conf
import dev_util
import stest

# Create configuration
def create_config():
    dev = simics.pre_conf_object('dut', 'my_device')
    clk = simics.pre_conf_object('clk', 'clock')
    clk.freq_mhz = 100
    dev.queue = clk
    
    simics.SIM_add_configuration([dev, clk], None)
    return (conf.dut, conf.clk)

# Run tests
(device, clock) = create_config()

# Get bank proxy (read DML to find bank name "regs")
regs = dev_util.bank_regs(device.bank.regs)

# Test 1: Register write/read
regs.CONTROL.write(0x5)
stest.expect_equal(regs.CONTROL.read(), 0x5, "CONTROL write/read failed")

# Test 2: Field access
regs.STATUS.write(dev_util.READ, enable=1, mode=2)
stest.expect_equal(regs.STATUS.field.enable.read(), 1, "Enable field incorrect")
stest.expect_equal(regs.STATUS.field.mode.read(), 2, "Mode field incorrect")

# Test 3: Default values
regs.CONFIG.write(0x0)  # Reset register
stest.expect_equal(regs.CONFIG.read(), 0x0, "CONFIG should reset to 0")

# Test 4: Read-only register
initial = regs.VERSION.read()
regs.VERSION.write(0xFFFFFFFF)
final = regs.VERSION.read()
stest.expect_equal(final, initial, "Read-only VERSION was modified")

print("All register tests passed!")
```

---

## Best Practices

### ✅ DO:

1. **Always read DML first** to find exact bank and register names
2. **Always use .bank. namespace**: `device.bank.<bank_name>`
3. **Always wrap with dev_util.bank_regs()** for register access
4. **Use field access** for read-modify-write operations
5. **Test default values** after configuration
6. **Test read-only** and **write-only** behaviors
7. **Use descriptive assertion messages** for debugging

### ❌ DON'T:

1. **Don't guess bank names** - read DML for exact names
2. **Don't access banks directly** - always use `dev_util.bank_regs()`
3. **Don't scan/discover** bank names dynamically
4. **Don't assume register names** - match DML exactly
5. **Don't forget .bank. namespace** - it's always required
6. **Don't test without assertions** - use `stest.expect_equal()`

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Next Reading**: [04_Test_Fake_Objects_Mocking.md](04_Test_Fake_Objects_Mocking.md)
