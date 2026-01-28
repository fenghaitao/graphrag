# Testing Device Output Signals with Fake Objects

## Overview

This document covers how to test device **output signals** (interrupts, resets, GPIO, etc.) using fake objects. Fake objects act as signal receivers that capture and track the device's outgoing signals, allowing you to verify that the device correctly signals external components.

**Key concepts:**
- Create fake objects to receive device output signals
- Connect fake objects to device `connect` blocks in DML
- Verify device behavior by checking fake object state after triggering actions
- Common patterns for testing interrupts, resets, DMA requests, and other output signals

## Table of Contents

1. [Why Use Fake Objects](#why-use-fake-objects)
2. [Creating Fake Objects](#creating-fake-objects)
3. [Fake Signal Interfaces](#fake-signal-interfaces)
4. [Testing Interface Interactions](#testing-interface-interactions)
5. [Common Fake Object Patterns](#common-fake-object-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Why Use Fake Objects

### Benefits of Isolation

**Use Fake Objects instead of real dependencies to:**
- **Improve test speed** - no need to simulate full system
- **Improve stability** - isolate test from external behavior
- **Simplify debugging** - failures clearly indicate device issues
- **Control inputs** - precisely test specific scenarios
- **Observe outputs** - verify device interactions

### Example: Testing Interrupt Generation

```python
# ❌ Without Fake: Need full interrupt controller
pic = simics.pre_conf_object('pic', 'real_interrupt_controller')
# ... complex PIC configuration ...
# Hard to verify interrupt was raised

# ✅ With Fake: Simple mock that tracks state
class FakePic(pyobj.ConfObject):
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    class signal(pyobj.Interface):
        def signal_raise(self): self._up.raised.val += 1

fake_pic = simics.pre_conf_object('fake_pic', 'FakePic')
# Easy to verify: stest.expect_equal(fake_pic.raised, 1)
```

---

## Creating Fake Objects

### Basic Fake Object Template

```python
import pyobj

class FakePic(pyobj.ConfObject):
    """Fake interrupt controller for testing"""
    
    # Attribute to track state
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    
    # Interface that device will call
    class signal(pyobj.Interface):
        def signal_raise(self):
            self._up.raised.val += 1
            
        def signal_lower(self):
            self._up.raised.val -= 1
```

### Components of a Fake Object

#### 1. Class Declaration

```python
class FakePic(pyobj.ConfObject):
    """Docstring describing the fake object"""
    pass
```

**Key points:**
- Inherit from `pyobj.ConfObject`
- Name should indicate it's a fake (e.g., `FakePic`, `MockTimer`)
- Add docstring explaining purpose

#### 2. Attributes (State Tracking)

```python
class raised(pyobj.SimpleAttribute(0, 'i')): pass
```

**Attribute syntax:**
```python
class <attribute_name>(pyobj.SimpleAttribute(<default_value>, '<type>')): pass
```

**Common types:**
| Type | Description | Example |
|------|-------------|---------|
| `'i'` | Integer | `0, 1, 42` |
| `'b'` | Boolean | `True, False` |
| `'s'` | String | `"hello"` |
| `'d'` | Double | `1.5, 3.14` |

**Example attributes:**
```python
class count(pyobj.SimpleAttribute(0, 'i')): pass       # Integer counter
class enabled(pyobj.SimpleAttribute(False, 'b')): pass # Boolean flag
class data(pyobj.SimpleAttribute("", 's')): pass       # String data
```

#### 3. Interfaces (Device Interaction Points)

```python
class signal(pyobj.Interface):
    """Interface that device calls"""
    
    def signal_raise(self):
        self._up.raised.val += 1
        
    def signal_lower(self):
        self._up.raised.val -= 1
```

**Interface structure:**
- Class inherits from `pyobj.Interface`
- Methods define interface functions
- `self._up` accesses parent object's attributes
- Method names match DML interface expectations

---

## Fake Signal Interfaces

### Signal Interface Pattern

The `signal` interface is the most common interface for testing interrupts and notifications.

```python
class FakePic(pyobj.ConfObject):
    """Fake interrupt controller"""
    
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    
    class signal(pyobj.Interface):
        def signal_raise(self):
            """Called when device raises interrupt"""
            self._up.raised.val += 1
            
        def signal_lower(self):
            """Called when device lowers interrupt"""
            self._up.raised.val -= 1
```

### Connecting Fake to Device

```python
def create_config():
    # Create device
    dev = simics.pre_conf_object('dev', 'my_device')
    
    # Create fake PIC
    fake_pic = simics.pre_conf_object('fake_pic', 'FakePic')
    
    # Connect device to fake PIC
    dev.pic = fake_pic  # DML: connect pic { ... }
    
    # Instantiate
    simics.SIM_add_configuration([dev, fake_pic], None)
    
    return (conf.dev, conf.fake_pic)
```

### DML Connection from Device

```dml
// In device DML:
connect pic {
    interface signal;
}

// When device raises interrupt:
method raise_interrupt() {
    pic.signal.signal_raise();  // Calls FakePic.signal.signal_raise()
}
```

### Testing Signal Interaction

```python
import stest

(device, fake_pic) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Initial state
stest.expect_equal(fake_pic.raised, 0, "No interrupt initially")

# Trigger interrupt
regs.trigger_irq.write(1)

# Verify interrupt raised
stest.expect_equal(fake_pic.raised, 1, "Interrupt should be raised")

# Clear interrupt
regs.clear_irq.write(1)

# Verify interrupt lowered
stest.expect_equal(fake_pic.raised, 0, "Interrupt should be cleared")
```

---

## Testing Interface Interactions

### Pattern: Trigger and Verify

```python
# 1. Record initial state
initial_state = fake_pic.raised

# 2. Trigger device action
regs.control.write(1)  # Action that should raise interrupt

# 3. Verify side effect
stest.expect_equal(fake_pic.raised, initial_state + 1, 
                   "Interrupt not raised after control write")
```

### Pattern: Multiple Interactions

```python
# Test multiple raises
stest.expect_equal(fake_pic.raised, 0, "Initial state")

regs.trigger1.write(1)
stest.expect_equal(fake_pic.raised, 1, "First interrupt")

regs.trigger2.write(1)
stest.expect_equal(fake_pic.raised, 2, "Second interrupt")

regs.trigger3.write(1)
stest.expect_equal(fake_pic.raised, 3, "Third interrupt")
```

### Pattern: Interrupt Masking

```python
# Test interrupt masking
regs.interrupt_mask.write(0x0)  # Disable interrupts

regs.trigger.write(1)
stest.expect_equal(fake_pic.raised, 0, "Masked interrupt should not fire")

regs.interrupt_mask.write(0x1)  # Enable interrupts

regs.trigger.write(1)
stest.expect_equal(fake_pic.raised, 1, "Unmasked interrupt should fire")
```

---

## Common Fake Object Patterns

### Pattern 1: Fake Interrupt Controller (PIC)

```python
class FakePic(pyobj.ConfObject):
    """Tracks interrupt raise/lower events"""
    
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    
    class signal(pyobj.Interface):
        def signal_raise(self):
            self._up.raised.val += 1
            
        def signal_lower(self):
            self._up.raised.val -= 1
```

**Use case:** Testing interrupt generation from device

### Pattern 2: Fake DMA Controller

```python
class FakeDma(pyobj.ConfObject):
    """Tracks DMA transfer requests"""
    
    class transfer_count(pyobj.SimpleAttribute(0, 'i')): pass
    class last_src(pyobj.SimpleAttribute(0, 'i')): pass
    class last_dst(pyobj.SimpleAttribute(0, 'i')): pass
    class last_size(pyobj.SimpleAttribute(0, 'i')): pass
    
    class dma_request(pyobj.Interface):
        def start_transfer(self, src, dst, size):
            self._up.transfer_count.val += 1
            self._up.last_src.val = src
            self._up.last_dst.val = dst
            self._up.last_size.val = size
```

**Use case:** Testing DMA request generation without real DMA engine

### Pattern 3: Fake Reset Controller

```python
class FakeResetCtrl(pyobj.ConfObject):
    """Tracks system reset requests"""
    
    class reset_requested(pyobj.SimpleAttribute(False, 'b')): pass
    class reset_count(pyobj.SimpleAttribute(0, 'i')): pass
    
    class reset_signal(pyobj.Interface):
        def assert_reset(self):
            self._up.reset_requested.val = True
            self._up.reset_count.val += 1
            
        def deassert_reset(self):
            self._up.reset_requested.val = False
```

**Use case:** Testing watchdog timeout reset behavior

### Pattern 4: Fake GPIO

```python
class FakeGpio(pyobj.ConfObject):
    """Tracks GPIO pin state changes"""
    
    class pin_state(pyobj.SimpleAttribute(0, 'i')): pass
    class toggle_count(pyobj.SimpleAttribute(0, 'i')): pass
    
    class gpio_signal(pyobj.Interface):
        def set_high(self):
            if self._up.pin_state.val == 0:
                self._up.toggle_count.val += 1
            self._up.pin_state.val = 1
            
        def set_low(self):
            if self._up.pin_state.val == 1:
                self._up.toggle_count.val += 1
            self._up.pin_state.val = 0
```

**Use case:** Testing GPIO output control

### Pattern 5: Fake Timer Event Sink

```python
class FakeTimerSink(pyobj.ConfObject):
    """Receives timer events"""
    
    class event_count(pyobj.SimpleAttribute(0, 'i')): pass
    class last_timestamp(pyobj.SimpleAttribute(0.0, 'd')): pass
    
    class timer_event(pyobj.Interface):
        def on_timer_event(self, timestamp):
            self._up.event_count.val += 1
            self._up.last_timestamp.val = timestamp
```

**Use case:** Testing timer event generation without external dependencies

---

## Troubleshooting

### Problem: Segfault on Test Run

```
Segmentation fault (core dumped)
```

**Common cause:** Device tries to call interface that doesn't exist

**Fix:** Create fake object for all `connect` blocks in DML

```dml
// In DML:
connect pic { interface signal; }
connect reset { interface reset_signal; }
```

```python
# In test: Must create fakes for BOTH
fake_pic = simics.pre_conf_object('fake_pic', 'FakePic')
fake_reset = simics.pre_conf_object('fake_reset', 'FakeResetCtrl')

dev.pic = fake_pic
dev.reset = fake_reset
```

### Problem: Attribute Not Found

```
AttributeError: 'FakePic' object has no attribute 'raised'
```

**Fix:** Access via conf object after instantiation

```python
# ❌ WRONG - Using pre-conf object
fake_pic = simics.pre_conf_object('fake_pic', 'FakePic')
print(fake_pic.raised)  # ❌ Fails - attribute not available yet

simics.SIM_add_configuration([fake_pic], None)

# ✅ CORRECT - Using conf object
print(conf.fake_pic.raised)  # ✅ Works after instantiation
```

### Problem: Interface Method Not Called

**Symptom:** `fake_pic.raised` stays at 0 even after interrupt trigger

**Debugging:**
1. Check DML connect block exists and matches fake interface name
2. Verify device actually calls the interface method
3. Add logging to fake interface method

```python
class signal(pyobj.Interface):
    def signal_raise(self):
        print("signal_raise called!")  # Debug logging
        self._up.raised.val += 1
```

### Problem: Wrong Interface Method Name

```
AttributeError: 'signal' interface has no method 'raise_signal'
```

**Fix:** Match DML interface call exactly

```dml
// In DML:
pic.signal.signal_raise();  // Method name is signal_raise
```

```python
# In fake:
class signal(pyobj.Interface):
    def signal_raise(self):  # ✅ Must match DML call
        self._up.raised.val += 1
```

---

## Complete Fake Object Example

```python
import simics
import conf
import dev_util
import pyobj
import stest

# Define fake objects
class FakePic(pyobj.ConfObject):
    """Fake interrupt controller for testing"""
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    
    class signal(pyobj.Interface):
        def signal_raise(self):
            self._up.raised.val += 1
        def signal_lower(self):
            self._up.raised.val -= 1

class FakeReset(pyobj.ConfObject):
    """Fake reset controller for testing"""
    class reset_count(pyobj.SimpleAttribute(0, 'i')): pass
    
    class reset_signal(pyobj.Interface):
        def assert_reset(self):
            self._up.reset_count.val += 1

# Configuration
def create_config():
    dev = simics.pre_conf_object('dut', 'my_device')
    clk = simics.pre_conf_object('clk', 'clock')
    fake_pic = simics.pre_conf_object('fake_pic', 'FakePic')
    fake_reset = simics.pre_conf_object('fake_reset', 'FakeReset')
    
    clk.freq_mhz = 100
    dev.queue = clk
    dev.pic = fake_pic
    dev.reset = fake_reset
    
    simics.SIM_add_configuration([dev, clk, fake_pic, fake_reset], None)
    
    return (conf.dut, conf.fake_pic, conf.fake_reset)

# Test
(device, pic, reset_ctrl) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Test interrupt
stest.expect_equal(pic.raised, 0, "No interrupt initially")
regs.trigger_irq.write(1)
stest.expect_equal(pic.raised, 1, "Interrupt raised")

# Test reset
stest.expect_equal(reset_ctrl.reset_count, 0, "No reset initially")
regs.watchdog_timeout.write(0x1)
stest.expect_equal(reset_ctrl.reset_count, 1, "Reset triggered")

print("All fake object tests passed!")
```

---

## Best Practices

### ✅ DO:

1. **Create fakes for all connect blocks** in DML
2. **Use descriptive names** (FakePic, MockTimer)
3. **Track relevant state** with attributes
4. **Match interface method names** exactly with DML
5. **Add docstrings** explaining fake object purpose
6. **Test fake isolation** - verify device behavior only
7. **Use simple implementations** - fakes should be trivial

### ❌ DON'T:

1. **Don't use real complex objects** when fake will do
2. **Don't add complex logic** to fakes - keep them simple
3. **Don't forget to connect** fakes to device
4. **Don't access before instantiation** - use conf objects
5. **Don't ignore segfaults** - usually missing fake object
6. **Don't reuse fakes across tests** without resetting state

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Next Reading**: [05_Test_DMA_Memory.md](05_Test_DMA_Memory.md)
