# Test Events and Timing

## Overview

This document covers testing time-dependent behavior in Simics device models, including timers, events, and timing verification.

## Table of Contents

1. [Time Advancement](#time-advancement)
2. [Testing Timers](#testing-timers)
3. [Event Verification](#event-verification)
4. [Timing Assertions](#timing-assertions)
5. [Common Timing Patterns](#common-timing-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Time Advancement

### Basic Time Control

```python
import simics

# Advance simulation by number of steps/cycles
simics.SIM_continue(1000)  # Run 1000 steps/cycles
```

### Checking Current Time

```python
# Get cycle count
cycles = simics.SIM_cycle_count(conf.clock)

# Get simulation time in seconds
sim_time = simics.SIM_time(conf.device)
```

### Measuring Elapsed Time

```python
import stest

# Measure cycles
start_cycles = simics.SIM_cycle_count(conf.clock)
simics.SIM_continue(1000)
elapsed_cycles = simics.SIM_cycle_count(conf.clock) - start_cycles
stest.expect_equal(elapsed_cycles, 1000, "Time did not advance correctly")

# Measure simulation time
start_time = simics.SIM_time(conf.device)
simics.SIM_continue(1000)  # Run 1000 steps/cycles
elapsed_time = simics.SIM_time(conf.device) - start_time
# elapsed_time depends on clock frequency (e.g., 1000 cycles at 100MHz = 0.00001 seconds)
```

---

## Testing Timers

### Basic Timer Test Pattern

```python
import simics
import dev_util
import stest

# Setup
(device, clock, fake_pic) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Configure timer for 1000 cycles timeout
regs.TIMER_VALUE.write(1000)
regs.TIMER_CONTROL.write(0x1)  # Start timer

# Verify timer is running
stest.expect_equal(regs.TIMER_CONTROL.read() & 0x1, 1, "Timer not started")

# Advance time (less than timeout)
simics.SIM_continue(500)

# Verify timer hasn't expired yet
stest.expect_equal(fake_pic.raised, 0, "Timer expired too early")

# Advance to timeout
simics.SIM_continue(500)

# Verify timer expired and interrupt raised
stest.expect_equal(fake_pic.raised, 1, "Timer interrupt not raised")
```

### Timer Countdown Test

```python
# Test countdown timer register value

# Start timer with 1000 cycles
regs.TIMER_LOAD.write(1000)
regs.TIMER_CONTROL.write(0x1)

# Check initial value
initial = regs.TIMER_VALUE.read()
stest.expect_equal(initial, 1000, "Initial timer value incorrect")

# Advance 250 steps/cycles
simics.SIM_continue(250)

# Check decremented value
current = regs.TIMER_VALUE.read()
stest.expect_equal(current, 750, "Timer value after 250 cycles")

# Advance another 250 steps/cycles
simics.SIM_continue(250)

current = regs.TIMER_VALUE.read()
stest.expect_equal(current, 500, "Timer value after 500 cycles")

# Advance to expiration
simics.SIM_continue(500)

final = regs.TIMER_VALUE.read()
stest.expect_equal(final, 0, "Timer should be 0 after expiration")
```

### Timer Auto-Reload Test

```python
# Test periodic/auto-reload timer

# Configure for auto-reload
regs.TIMER_RELOAD_VALUE.write(500)
regs.TIMER_CONTROL.write(0x3)  # Enable + Auto-reload

# First period
interrupt_count = fake_pic.raised
simics.SIM_continue(500)
stest.expect_equal(fake_pic.raised, interrupt_count + 1, 
                   "First interrupt not raised")

# Second period (should reload automatically)
simics.SIM_continue(500)
stest.expect_equal(fake_pic.raised, interrupt_count + 2, 
                   "Second interrupt not raised (auto-reload failed)")

# Third period
simics.SIM_continue(500)
stest.expect_equal(fake_pic.raised, interrupt_count + 3, 
                   "Third interrupt not raised")
```

---

## Event Verification

### Verifying Event Timing

```python
# Test that event fires at correct time

# Configure event for 1000 cycles
regs.EVENT_CYCLES.write(1000)
regs.EVENT_START.write(0x1)

# Record start time
start_cycles = simics.SIM_cycle_count(conf.clock)

# Run until event should fire
simics.SIM_continue(1000)

# Verify event fired
stest.expect_equal(fake_pic.raised, 1, "Event did not fire")

# Verify timing
elapsed = simics.SIM_cycle_count(conf.clock) - start_cycles
stest.expect_equal(elapsed, 1000, "Event fired at wrong time")
```

### Testing Event Cancellation

```python
# Test cancelling pending event

# Start event
regs.EVENT_CYCLES.write(1000)
regs.EVENT_START.write(0x1)

# Cancel before it fires
simics.SIM_continue(500)
regs.EVENT_CANCEL.write(0x1)

# Continue past original timeout
simics.SIM_continue(600)

# Verify event did NOT fire
stest.expect_equal(fake_pic.raised, 0, "Cancelled event still fired")
```

### Testing Event Re-scheduling

```python
# Test modifying event timeout while running

# Start with 1000 cycles
regs.EVENT_CYCLES.write(1000)
regs.EVENT_START.write(0x1)

# After 300 steps/cycles, change to 200 more steps/cycles
simics.SIM_continue(300)
regs.EVENT_CYCLES.write(200)
regs.EVENT_RESTART.write(0x1)

# Event should now fire 200 steps/cycles from restart (500 total from original start)
simics.SIM_continue(200)

elapsed = simics.SIM_cycle_count(conf.clock)
stest.expect_equal(fake_pic.raised, 1, "Re-scheduled event did not fire")
```

---

## Timing Assertions

### Tolerance-Based Assertions

```python
def approx_equal(got, expected, tolerance, msg=""):
    """Check equality with tolerance for timing variations"""
    if abs(got - expected) > tolerance:
        raise stest.fail(f"{msg}: got {got}, expected {expected} +/- {tolerance}")

# Use with cycle counts
start = simics.SIM_cycle_count(conf.clock)
simics.SIM_continue(1000)
elapsed = simics.SIM_cycle_count(conf.clock) - start
approx_equal(elapsed, 1000, 10, "Cycle count mismatch")

# Use with simulation time
start_time = simics.SIM_time(conf.device)
simics.SIM_continue(1000)  # Run 1000 steps/cycles
elapsed_time = simics.SIM_time(conf.device) - start_time
# Check elapsed_time based on clock frequency
# At 100MHz: 1000 steps/cycles = 0.00001 seconds
expected_time = 1000 / (100 * 1e6)  # steps/cycles / (freq_mhz * 1e6)
approx_equal(elapsed_time, expected_time, 0.000001, "Sim time mismatch")
```

### Range Assertions

```python
def expect_in_range(value, min_val, max_val, msg=""):
    """Check value is within range"""
    if not (min_val <= value <= max_val):
        raise stest.fail(
            f"{msg}: {value} not in range [{min_val}, {max_val}]"
        )

# Check timer value is decreasing correctly
regs.TIMER_VALUE.write(1000)
regs.TIMER_CONTROL.write(0x1)

simics.SIM_continue(500)
current = regs.TIMER_VALUE.read()
expect_in_range(current, 450, 550, "Timer value after 500 cycles")
```

---

## Common Timing Patterns

### Pattern 1: One-Shot Timer

```python
# Test one-shot timer (fires once then stops)

regs.TIMER_MODE.write(0x0)  # One-shot mode
regs.TIMER_VALUE.write(1000)
regs.TIMER_CONTROL.write(0x1)  # Start

# First expiration
simics.SIM_continue(1000)
stest.expect_equal(fake_pic.raised, 1, "Timer did not fire")

# Verify timer stopped
stest.expect_equal(regs.TIMER_CONTROL.read() & 0x1, 0, 
                   "Timer should be stopped after one-shot")

# Continue further - should not fire again
simics.SIM_continue(1000)
stest.expect_equal(fake_pic.raised, 1, 
                   "One-shot timer fired multiple times")
```

### Pattern 2: Watchdog Timer

```python
# Test watchdog timer with kick/refresh

# Start watchdog with 1000 cycle timeout
regs.WDT_TIMEOUT.write(1000)
regs.WDT_ENABLE.write(0x1)

# Kick watchdog before timeout (at 500 steps/cycles)
simics.SIM_continue(500)
regs.WDT_KICK.write(0x1)  # Restart timeout

# Continue another 500 steps/cycles (would have expired without kick)
simics.SIM_continue(500)
stest.expect_equal(fake_pic.raised, 0, "Watchdog should not expire after kick")

# Continue to new timeout (another 500 steps/cycles)
simics.SIM_continue(500)
stest.expect_equal(fake_pic.raised, 1, "Watchdog should expire now")
```

### Pattern 3: Timestamp Counter

```python
# Test free-running timestamp counter

# Read initial timestamp
ts1 = regs.TIMESTAMP.read()

# Advance time
simics.SIM_continue(1000)

# Read new timestamp
ts2 = regs.TIMESTAMP.read()

# Verify timestamp increased by expected amount
delta = ts2 - ts1
stest.expect_equal(delta, 1000, "Timestamp did not increment correctly")

# Verify continuous incrementing
ts3 = regs.TIMESTAMP.read()
simics.SIM_continue(500)
ts4 = regs.TIMESTAMP.read()
delta2 = ts4 - ts3
stest.expect_equal(delta2, 500, "Timestamp increment inconsistent")
```

### Pattern 4: Deadline Timer

```python
# Test absolute deadline timer (fires when counter reaches target)

# Read current timestamp
current = regs.TIMESTAMP.read()

# Set deadline for current + 1000
deadline = current + 1000
regs.TIMER_DEADLINE.write(deadline)
regs.TIMER_ENABLE.write(0x1)

# Advance time
simics.SIM_continue(1000)

# Verify timer fired
stest.expect_equal(fake_pic.raised, 1, "Deadline timer did not fire")

# Verify current time matches deadline
now = regs.TIMESTAMP.read()
approx_equal(now, deadline, 10, "Deadline timing incorrect")
```

### Pattern 5: Prescaler Test

```python
# Test timer with prescaler/divider

# Configure prescaler (divide by 4)
regs.TIMER_PRESCALER.write(4)
regs.TIMER_VALUE.write(250)  # 250 * 4 = 1000 actual cycles
regs.TIMER_CONTROL.write(0x1)

# Advance 1000 steps/cycles (should equal 250 prescaled steps/cycles)
simics.SIM_continue(1000)

# Verify timer expired
stest.expect_equal(fake_pic.raised, 1, "Prescaled timer did not fire")

# Verify value
stest.expect_equal(regs.TIMER_VALUE.read(), 0, "Timer value should be 0")
```

---

## Troubleshooting

### Problem: Events Don't Fire

**Symptom:** Timer never raises interrupt

**Fixes:**

```python
# Fix 1: Verify clock is configured
clk = simics.pre_conf_object('clk', 'clock')
clk.freq_mhz = 100  # ✅ Must set frequency
dev.queue = clk     # ✅ Must assign queue

# Fix 2: Wait long enough
simics.SIM_continue(timeout_cycles + 100)  # Add margin (in cycles)

# Fix 3: Check timer is enabled
stest.expect_equal(regs.TIMER_CONTROL.read() & 0x1, 1, 
                   "Timer not enabled")

# Fix 4: Verify fake PIC is connected
dev.pic = fake_pic  # ✅ Must connect interrupt sink
```

### Problem: Timing Inaccurate

**Symptom:** Timer fires at wrong time

**Fixes:**

```python
# Fix 1: Account for clock frequency
# If clock is 100 MHz, 1000 cycles = 10 microseconds
clk.freq_mhz = 100
cycles = 1000
time_seconds = cycles / (100 * 1e6)  # = 0.00001 seconds

# Fix 2: Use cycle-based timing (deterministic)
simics.SIM_continue(cycles)  # ✅ Always takes cycles as argument
# SIM_continue() ONLY accepts cycles, not time in seconds

# Fix 3: Check prescaler settings
prescaler = regs.TIMER_PRESCALER.read()
actual_cycles = timer_value * prescaler
```

### Problem: Timer Doesn't Stop

**Symptom:** One-shot timer keeps firing

**Fix:** Verify timer disables itself on expiration

```python
# In timer expiry handler, device should:
# 1. Clear enable bit (if one-shot)
# 2. Set status bit
# 3. Raise interrupt

# Test this:
simics.SIM_continue(timeout)
stest.expect_equal(regs.TIMER_CONTROL.read() & 0x1, 0, 
                   "One-shot timer should auto-disable")
```

---

## Complete Timing Test Example

```python
import simics
import conf
import dev_util
import pyobj
import stest

# Fake PIC
class FakePic(pyobj.ConfObject):
    class raised(pyobj.SimpleAttribute(0, 'i')): pass
    class signal(pyobj.Interface):
        def signal_raise(self): self._up.raised.val += 1
        def signal_lower(self): self._up.raised.val -= 1

# Configuration
def create_config():
    dev = simics.pre_conf_object('timer_dev', 'timer_device')
    clk = simics.pre_conf_object('clk', 'clock')
    pic = simics.pre_conf_object('pic', 'FakePic')
    
    clk.freq_mhz = 100  # 100 MHz
    dev.queue = clk
    dev.pic = pic
    
    simics.SIM_add_configuration([dev, clk, pic], None)
    return (conf.timer_dev, conf.clk, conf.pic)

# Test
(device, clock, pic) = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Test 1: Basic timer countdown
print("Test 1: Basic timer countdown")
regs.TIMER_VALUE.write(1000)
regs.TIMER_CONTROL.write(0x1)

initial = regs.TIMER_VALUE.read()
stest.expect_equal(initial, 1000, "Initial value")

simics.SIM_continue(500)
mid = regs.TIMER_VALUE.read()
stest.expect_equal(mid, 500, "Mid-countdown value")

simics.SIM_continue(500)
final = regs.TIMER_VALUE.read()
stest.expect_equal(final, 0, "Final value")
stest.expect_equal(pic.raised, 1, "Interrupt raised")

# Test 2: Timer cancellation
print("Test 2: Timer cancellation")
regs.TIMER_VALUE.write(1000)
regs.TIMER_CONTROL.write(0x1)

simics.SIM_continue(300)
regs.TIMER_CONTROL.write(0x0)  # Stop timer

simics.SIM_continue(800)
stest.expect_equal(pic.raised, 1, "Should not raise second interrupt")

# Test 3: Auto-reload timer
print("Test 3: Auto-reload timer")
regs.TIMER_RELOAD.write(250)
regs.TIMER_CONTROL.write(0x3)  # Enable + Auto-reload

initial_count = pic.raised
simics.SIM_continue(250)
stest.expect_equal(pic.raised, initial_count + 1, "First period")

simics.SIM_continue(250)
stest.expect_equal(pic.raised, initial_count + 2, "Second period")

simics.SIM_continue(250)
stest.expect_equal(pic.raised, initial_count + 3, "Third period")

print("All timing tests passed!")
```

---

## Best Practices

### ✅ DO:

1. **Configure clock properly** - set freq_mhz and assign queue
2. **Wait sufficient time** for events to fire
3. **Use cycle-based timing** for deterministic tests
4. **Test edge cases** - zero timeout, max timeout
5. **Verify timer auto-disable** for one-shot mode
6. **Test cancellation** - stop timers before expiry
7. **Use tolerance** for time-based comparisons

### ❌ DON'T:

1. **Don't forget clock configuration** - causes events not to fire
2. **Don't use insufficient wait time** - events won't complete
3. **Don't mix time and cycle units** without conversion
4. **Don't assume immediate completion** - always wait
5. **Don't forget to test reload** for periodic timers
6. **Don't test only happy path** - test cancellation too

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Next Reading**: [07_Test_Suite_Organization.md](07_Test_Suite_Organization.md)
