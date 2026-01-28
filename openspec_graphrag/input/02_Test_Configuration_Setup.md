# Test Configuration Setup

## Overview

This document covers how to properly configure Simics device models for testing, including device instantiation, clock setup, memory mapping, and common configuration patterns.

## Table of Contents

1. [Basic Configuration Pattern](#basic-configuration-pattern)
2. [Clock Configuration](#clock-configuration)
3. [Memory Mapping](#memory-mapping)
4. [Pre-Conf vs Conf Objects](#pre-conf-vs-conf-objects)
5. [Simulation Control](#simulation-control)
6. [Common Configuration Errors](#common-configuration-errors)

---

## Basic Configuration Pattern

The goal is to create a **minimal configuration** containing only the device under test and necessary support objects (clock, memory).

### Minimal Configuration Template

```python
import simics
import conf
import dev_util

def create_config():
    # 1. Create pre-conf objects
    dev = simics.pre_conf_object('dev', 'my_device')
    clk = simics.pre_conf_object('clk', 'clock')
    mem = simics.pre_conf_object('mem', 'memory-space')
    
    # 2. Configure attributes BEFORE SIM_add_configuration
    clk.freq_mhz = 100  # ⚠️ CRITICAL: Set BEFORE instantiation
    dev.queue = clk     # REQUIRED for time-dependent devices
    
    # 3. Configure memory mapping
    mem.map = []
    # Map bank to memory space [base_addr, bank_obj, func, offset, size]
    mem.map += [0x1000, dev.bank.regs, 0, 0, 0x1000]
    
    # 4. Instantiate objects
    simics.SIM_add_configuration([dev, clk, mem], None)
    
    # 5. Return conf objects (NOT pre-conf objects!)
    return (conf.dev, conf.clk, conf.mem)
```

### Configuration Steps Explained

#### Step 1: Create Pre-Configuration Objects

```python
# Create pre-conf objects with names
dev = simics.pre_conf_object('device_name', 'device_class')
clk = simics.pre_conf_object('clock_name', 'clock')
```

**Key Points:**
- First argument: object name (used to retrieve conf object later)
- Second argument: object class/type
- Returns pre-conf object for configuration (not yet instantiated)

#### Step 2: Configure Required Attributes

```python
# Set all required attributes on pre-conf objects
clk.freq_mhz = 100              # Clock frequency
dev.queue = clk                 # Event queue for timing
dev.some_attr = value           # Device-specific attributes
```

**Critical Rule:** All required attributes MUST be set before `SIM_add_configuration()`

#### Step 3: Setup Memory Mapping (if needed)

```python
mem.map = []
# Format: [base_address, target_object, function, offset, length]
mem.map += [0x1000, dev.bank.regs, 0, 0, 0x1000]
```

#### Step 4: Instantiate Configuration

```python
simics.SIM_add_configuration([dev, clk, mem], None)
```

**What happens:**
- Pre-conf objects are instantiated as real Simics objects
- Objects become available via `conf.<object_name>`
- Pre-conf objects are no longer needed

#### Step 5: Return Configuration Objects

```python
return (conf.device_name, conf.clock_name)  # Use names from step 1
```

---

## Clock Configuration

### ⚠️ CRITICAL: Clock freq_mhz Must Be Set Before Instantiation

**WRONG - Setting freq_mhz AFTER object creation:**

```python
# ❌ WRONG
def create_config():
    clk = simics.pre_conf_object('clk', 'clock')
    simics.SIM_add_configuration([clk], None)  # ❌ freq_mhz not set yet!
    
    conf.clk.freq_mhz = 10  # ❌ TOO LATE! Object already instantiated
    return conf.clk
```

**CORRECT - Setting freq_mhz BEFORE object creation:**

```python
# ✅ CORRECT
def create_config():
    clk = simics.pre_conf_object('clk', 'clock')
    clk.freq_mhz = 10  # ✅ Set on pre-conf object BEFORE instantiation
    
    simics.SIM_add_configuration([clk], None)  # ✅ Now freq_mhz is configured
    return conf.clk
```

### Why This Matters

- `freq_mhz` is a **required attribute** for clock objects
- Must be set on the pre-conf object before `SIM_add_configuration`
- Setting it after instantiation causes errors or undefined behavior
- All time-dependent devices rely on correct clock frequency

### Clock Configuration Pattern

```python
# Create clock
clk = simics.pre_conf_object('clk', 'clock')

# ✅ Set frequency BEFORE instantiation
clk.freq_mhz = 100  # 100 MHz clock

# Optional: Alternative syntax (list of [attr, value] pairs)
clk = simics.pre_conf_object('clk', 'clock', [["freq_mhz", 100]])

# Instantiate
simics.SIM_add_configuration([clk], None)
```

### Assigning Clock to Device

```python
# Create device and clock
dev = simics.pre_conf_object('dev', 'my_device')
clk = simics.pre_conf_object('clk', 'clock')
clk.freq_mhz = 100

# ✅ Assign clock to device queue (REQUIRED for time-dependent devices)
dev.queue = clk

# Instantiate
simics.SIM_add_configuration([dev, clk], None)
```

**When to set queue:**
- **Always** for devices using events or timers
- **Always** for devices with time-dependent behavior
- If your DML has `event` objects or `after` statements, queue is required

---

## Memory Mapping

### Basic Memory Mapping

```python
# Create memory space
mem = simics.pre_conf_object('mem', 'memory-space')

# Create device with bank
dev = simics.pre_conf_object('dev', 'my_device')

# Map device bank to memory space
mem.map = []
mem.map += [
    0x1000,           # Base address in memory space
    dev.bank.regs,    # Bank object to map (use exact name from DML)
    0,                # Function number (usually 0)
    0,                # Offset within bank (usually 0)
    0x1000            # Size of mapping (in bytes)
]

simics.SIM_add_configuration([dev, mem], None)
```

### Memory Mapping Parameters

```python
mem.map += [base_address, target_object, function, offset, length]
```

| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `base_address` | Address in memory space | 0x1000, 0x40000000, etc. |
| `target_object` | Bank or memory object | `dev.bank.<bank_name>` |
| `function` | Function number | 0 (for single-function devices) |
| `offset` | Offset within target | 0 (map from start of bank) |
| `length` | Size of mapping in bytes | 0x1000, 0x100, etc. |

### Finding Bank Name from DML

**Always read the DML file to find the exact bank name:**

```dml
// In device.dml:
bank regs {          // ← Bank name is "regs"
    register CONTROL @ 0x00 size 4 { ... }
    register STATUS @ 0x04 size 4 { ... }
}
```

```python
# In test - use exact bank name from DML:
mem.map += [0x1000, dev.bank.regs, 0, 0, 0x1000]  # ✅ Matches DML "bank regs"
```

### Multiple Banks

```python
# Device with multiple banks in DML:
# bank ctrl_regs @ 0x0000 { ... }
# bank status_regs @ 0x1000 { ... }

mem.map = []
# Map first bank
mem.map += [0x40000000, dev.bank.ctrl_regs, 0, 0, 0x1000]
# Map second bank
mem.map += [0x40001000, dev.bank.status_regs, 0, 0, 0x1000]
```

---

## Pre-Conf vs Conf Objects

### ⚠️ CRITICAL: Return conf_object, NOT pre_conf_object

**WRONG - Returning pre_conf_object:**

```python
# ❌ WRONG
def create_config():
    dev = simics.pre_conf_object('dut1', 'dut_class')
    clk = simics.pre_conf_object('clk', 'clock')
    clk.freq_mhz = 100
    dev.queue = clk
    
    simics.SIM_add_configuration([dev, clk], None)
    
    return (dev, clk)  # ❌ WRONG! Returning pre_conf_object

# Later in test:
(dut, clk) = create_config()
regs = dev_util.bank_regs(dut.bank.regs)  # ❌ FAILS! dut is pre_conf_object
```

**CORRECT - Returning conf_object:**

```python
# ✅ CORRECT
def create_config():
    dev = simics.pre_conf_object('dut1', 'dut_class')
    clk = simics.pre_conf_object('clk', 'clock')
    clk.freq_mhz = 100
    dev.queue = clk
    
    simics.SIM_add_configuration([dev, clk], None)
    
    return (conf.dut1, conf.clk)  # ✅ CORRECT! Using conf.<object_name>

# Later in test:
(dut, clk) = create_config()
regs = dev_util.bank_regs(dut.bank.regs)  # ✅ WORKS! dut is conf_object
```

### Understanding the Difference

**Pre-Configuration Object:**
- Created by `simics.pre_conf_object(name, class)`
- Used ONLY for configuration setup
- Limited API - cannot access registers, run simulation, etc.
- Exists only until `SIM_add_configuration()` is called

**Configuration Object:**
- Created when `SIM_add_configuration()` is called
- Available via `conf.<object_name>` after instantiation
- Full Simics API - can access registers, control simulation, etc.
- Used for all test operations

### Correct Return Pattern

```python
def create_config():
    # Step 1: Create pre-conf objects with names
    dev = simics.pre_conf_object('device_name', 'device_class')
    clk = simics.pre_conf_object('clock_name', 'clock')
    
    # Step 2: Configure attributes
    clk.freq_mhz = 100
    dev.queue = clk
    
    # Step 3: Instantiate
    simics.SIM_add_configuration([dev, clk], None)
    
    # Step 4: Return conf_object using names from step 1
    return (conf.device_name, conf.clock_name)  # ✅ Use conf.<name>
```

---

## Simulation Control

### Running Simulation

Use `simics.SIM_continue()` to advance simulation. Must be called from **Global Context**.

```python
# Run for specific number of steps/cycles
simics.SIM_continue(1000)  # Run 1000 steps/cycles
```

**Note:** `SIM_continue(steps)` takes the number of **steps** to run. At least one processor will execute `steps` steps before stopping.

### Checking Elapsed Time

```python
import stest

# Check cycles elapsed
start_cycles = simics.SIM_cycle_count(conf.clk)
simics.SIM_continue(1000)
elapsed_cycles = simics.SIM_cycle_count(conf.clk) - start_cycles
stest.expect_equal(elapsed_cycles, 1000, "Time did not advance correctly")

# Check simulation time
start_time = simics.SIM_time(conf.dev)
simics.SIM_continue(1000)  # Run 1000 steps/cycles
elapsed_time = simics.SIM_time(conf.dev) - start_time
# elapsed_time depends on clock frequency
# At 100MHz: 1000 steps/cycles = 0.00001 seconds (10 microseconds)
```

### Time Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `SIM_cycle_count(obj)` | uint64 | Cycle count for object's queue |
| `SIM_time(obj)` | double | Simulation time in seconds |
| `SIM_continue(steps)` | uint64 | Run simulation for specified steps |

---

## Common Configuration Errors

### Error 1: Queue Not Set

```
Error: Object 'dev' has no queue attribute set
```

**Fix:**
```python
clk = simics.pre_conf_object('clk', 'clock')
clk.freq_mhz = 100
dev.queue = clk  # ✅ Set queue for time-dependent devices
```

### Error 2: Clock Frequency Not Set

```
Error: Attribute 'freq_mhz' is required for object 'clk'
```

**Fix:**
```python
clk = simics.pre_conf_object('clk', 'clock')
clk.freq_mhz = 100  # ✅ Set BEFORE SIM_add_configuration
simics.SIM_add_configuration([clk], None)
```

### Error 3: Using Pre-Conf Object in Test

```
AttributeError: 'pre_conf_object' has no attribute 'bank'
```

**Fix:**
```python
def create_config():
    dev = simics.pre_conf_object('dut', 'device_class')
    # ... configure ...
    simics.SIM_add_configuration([dev], None)
    return conf.dut  # ✅ Return conf object, not pre-conf
```

### Error 4: Wrong Bank Name

```
AttributeError: 'conf_object' has no attribute 'regif'
```

**Fix:** Read DML file to find exact bank name
```dml
// In DML:
bank regs { ... }  // Not "regif"
```

```python
# In test:
regs = dev_util.bank_regs(dev.bank.regs)  # ✅ Use exact name from DML
```

---

## Complete Configuration Example

```python
import simics
import conf
import dev_util
import stest

def create_test_config():
    """Create minimal test configuration for device under test"""
    
    # 1. Create pre-conf objects
    dut = simics.pre_conf_object('test_device', 'my_device_class')
    clk = simics.pre_conf_object('test_clock', 'clock')
    mem = simics.pre_conf_object('test_mem', 'memory-space')
    
    # 2. Configure clock (BEFORE instantiation)
    clk.freq_mhz = 100  # 100 MHz
    
    # 3. Configure device
    dut.queue = clk  # Required for time-dependent behavior
    
    # 4. Configure memory mapping
    mem.map = []
    # Map device bank 'regs' at address 0x1000 (read from DML)
    mem.map += [0x1000, dut.bank.regs, 0, 0, 0x1000]
    
    # 5. Instantiate all objects
    simics.SIM_add_configuration([dut, clk, mem], None)
    
    # 6. Return conf objects (NOT pre-conf objects!)
    return (conf.test_device, conf.test_clock, conf.test_mem)


# Use in test
(device, clock, memory) = create_test_config()

# Now can access device registers
regs = dev_util.bank_regs(device.bank.regs)
regs.CONTROL.write(0x1)
stest.expect_equal(regs.CONTROL.read(), 0x1, "Control register write failed")

# Can advance time
simics.SIM_continue(100)  # Run 100 steps/cycles
```

---

## Complete common.py Template

For organizing test suites with multiple test files, create a `common.py` file with shared configuration and helpers:

```python
"""
Shared configuration and helper functions for <device> test suite.
"""

import simics
import conf
import dev_util
import pyobj
import stest

# ============================================================================
# Fake Objects
# ============================================================================

class FakePic(pyobj.ConfObject):
    """Fake interrupt controller for testing interrupt generation"""
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    
    class signal(pyobj.Interface):
        def signal_raise(self):
            self._up.raised.val += 1
            
        def signal_lower(self):
            self._up.raised.val -= 1


class FakeResetCtrl(pyobj.ConfObject):
    """Fake reset controller for testing reset signal"""
    class reset_count(pyobj.SimpleAttribute(0, 'i')): pass
    
    class reset_signal(pyobj.Interface):
        def signal_raise(self):
            self._up.reset_count.val += 1

# ============================================================================
# Ignore 'spec-viol' or 'unimpl' logs, test modeled behavior firstly
# ============================================================================

stest.untrap_log('spec-viol')
stest.untrap_log('unimpl')

# ============================================================================
# Configuration Helper
# ============================================================================

def create_config():
    """
    Create minimal test configuration for device under test.
    
    Returns:
        tuple: (device, clock, fake_pic, fake_reset) configuration objects
    """
    # Create pre-conf objects
    dev = simics.pre_conf_object('test_device', 'device_class_name')
    clk = simics.pre_conf_object('test_clock', 'clock')
    mem = simics.pre_conf_object('test_mem', 'memory-space')
    pic = simics.pre_conf_object('test_pic', 'FakePic')
    reset = simics.pre_conf_object('test_reset', 'FakeResetCtrl')
    
    # Configure clock (BEFORE instantiation)
    clk.freq_mhz = 100  # 100 MHz
    
    # Configure device
    dev.queue = clk
    dev.pic = pic
    dev.reset_ctrl = reset
    
    # Configure memory mapping (read DML for exact bank name)
    mem.map = []
    mem.map += [0x1000, dev.bank.regs, 0, 0, 0x1000]  # Adjust bank name
    
    # Instantiate all objects
    simics.SIM_add_configuration([dev, clk, mem, pic, reset], None)
    
    # Return conf objects (NOT pre-conf objects!)
    return (conf.test_device, conf.test_clock, conf.test_pic, conf.test_reset)


# ============================================================================
# Test Utilities
# ============================================================================

def approx_equal(got, expected, tolerance, msg=""):
    """Check equality with tolerance (used for timing assertions)"""
    if abs(got - expected) > tolerance:
        raise stest.fail(f"{msg}: got {got}, expected {expected} +/- {tolerance}")
```

**Usage in test files:**
```python
# s-basic-ops.py
import simics
import dev_util
import stest
from common import create_config

(device, clock, pic, reset_ctrl) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Test code here
regs.CONTROL.write(0x5)
stest.expect_equal(regs.CONTROL.read(), 0x5, "Control mismatch")
```

---

## Best Practices

### ✅ DO:

1. **Set all required attributes BEFORE** `SIM_add_configuration()`
2. **Set clock freq_mhz** on pre-conf object
3. **Assign queue** to time-dependent devices
4. **Return conf objects** from `create_config()`, not pre-conf objects
5. **Read DML** to find exact bank names for memory mapping
6. **Create minimal config** - only necessary objects for testing
7. **Document configuration** with comments explaining mappings
8. **Use common.py** for shared configuration across multiple test files

### ❌ DON'T:

1. **Don't set attributes** after `SIM_add_configuration()`
2. **Don't forget clock frequency** for timer-based devices
3. **Don't return pre-conf objects** from configuration functions
4. **Don't guess bank names** - read DML for exact names
5. **Don't create unnecessary objects** - keep config minimal
6. **Don't forget queue assignment** for event-based devices

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 12, 2025  
**Next Reading**: [03_Test_Register_Access.md](03_Test_Register_Access.md)
