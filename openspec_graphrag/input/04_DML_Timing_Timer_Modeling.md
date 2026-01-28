# DML Timing and Timer Device Modeling

## Overview

This document provides comprehensive guidance on modeling timing-related features and timer devices in Simics DML, including core timing mechanisms, common patterns, and complete examples.

## Table of Contents

1. [Core Timing Mechanisms](#core-timing-mechanisms)
2. [Timer Counter Modeling Patterns](#timer-counter-modeling-patterns)
3. [Complete Timer Device Examples](#complete-timer-device-examples)
4. [Common Timing Constants](#common-timing-constants)
5. [Best Practices Summary](#best-practices-summary)
6. [Quick Reference Card](#quick-reference-card)

---

## Core Timing Mechanisms

### The `after` Statement

The `after` statement is the primary mechanism for scheduling delayed callbacks in DML.

**Syntax:**
```dml
// Time-based delay (seconds)
after delay s: callback_method();

// Cycle-based delay
after cycles_count cycles: callback_method();

// Immediate (next simulation step)
after: callback_method();
```

**Example from sample-timer-device:**
```dml
method update_event() {
    cancel_after();  // Cancel any pending callback

    if (step.val == 0)
        return;

    local cycles_t now = SIM_cycle_count(dev.obj);
    local cycles_t cycles_left =
        (reference.val - counter_start_value) * step.val
        - (now - counter_start_time);

    // Schedule callback after cycles_left cycles
    after cycles_left cycles: on_match();
}
```

**After statement usage:**
```dml
method schedule_my_method() {
    // call my_method() after 10.5s
    after 10.5 s: my_method();
}

method hard_reset() {
    // cancel the scheduled call to my_method()
    cancel_after();
}
```

### Event Objects

For more complex timing scenarios, use `event` objects with one of six templates:

| Template | Time Unit | Data |
|----------|-----------|------|
| `simple_time_event` | Seconds (double) | None |
| `simple_cycle_event` | Cycles (uint64) | None |
| `uint64_time_event` | Seconds (double) | uint64 |
| `uint64_cycle_event` | Cycles (uint64) | uint64 |
| `custom_time_event` | Seconds (double) | Custom (serializable) |
| `custom_cycle_event` | Cycles (uint64) | Custom (serializable) |

**Example from HPET:**
```dml
event tim_event is simple_time_event {
    method event() {
        regs.on_event();
    }
}

// Posting the event
method update_event() {
    if (tim_event.posted()) {
        tim_event.remove();
    }

    local double delay = offs * COUNTER_CLK_PERIOD;
    tim_event.post(delay);
}
```

---

## Timer Counter Modeling Patterns

### Lazy Counter Evaluation (Recommended)

Instead of updating a counter every cycle, calculate the current value on-demand based on elapsed time.

**Pattern from sample-timer-device:**
```dml
bank regs {
    // Records the time when the counter was started
    saved cycles_t counter_start_time;
    // Records the start value of the counter
    saved cycles_t counter_start_value;

    register counter is (get, read, write) {
        param configuration = "none";  // Don not checkpoint raw value

        method get() -> (uint64) {
            if (step.val == 0) {
                return counter_start_value;  // Counter stopped
            }

            local cycles_t now = SIM_cycle_count(dev.obj);
            return (now - counter_start_time) / step.val
                + counter_start_value;
        }

        method write(uint64 value) {
            counter_start_value = value;
            restart();
        }

        method restart() {
            counter_start_time = SIM_cycle_count(dev.obj);
            update_event();
        }
    }
}
```

**Benefits:**
- No per-cycle overhead
- Accurate timing
- Efficient for high-frequency counters

### HPET Main Counter Pattern

For high-precision timers like HPET:

```dml
param COUNTER_CLK_PERIOD = 6.984127871e-8;  // ~14.318 MHz

attribute start_time is double_attr {
    param documentation = "Latest start time of the main counter";
}

register main_cnt {
    // Get running counter value
    method get_main_cnt() -> (uint64) {
        local uint64 value = this.val;
        if (gen_conf.enable_cnf.val != 0) {
            local double delta = SIM_time(dev.obj) - start_time.val + 1.0e-8;
            local uint64 cnt = cast(delta / COUNTER_CLK_PERIOD, uint64);
            value += cnt;
        }
        return value;
    }

    // Renormalize to maintain precision
    method renormalize_main_cnt() {
        this.val = get_main_cnt();
        start_time.val = SIM_time(dev.obj);
    }
}
```

### Countdown Timer Pattern

Basic countdown timer implementation:

```dml
attribute enabled is (bool_attr);

register countdown {
    saved cycles_t start_time;
    saved uint64 start_value;

    method get() -> (uint64) {
        if (!enabled.val)
            return start_value;

        local cycles_t elapsed = SIM_cycle_count(dev.obj) - start_time;
        local uint64 decremented = elapsed / prescaler.val;

        if (decremented >= start_value)
            return 0;  // Expired
        return start_value - decremented;
    }

    method write(uint64 value) {
        start_value = value;
        start_time = SIM_cycle_count(dev.obj);
        schedule_expiry();
    }

    method schedule_expiry() {
        cancel_after();
        if (enabled.val && start_value > 0) {
            local cycles_t cycles_to_zero = start_value * prescaler.val;
            after cycles_to_zero cycles: on_expired();
        }
    }

    method on_expired() {
        log info: "Countdown timer expired!";
        // Trigger interrupt, reset, etc.
        if (auto_reload.val) {
            start_value = reload_value.val;
            start_time = SIM_cycle_count(dev.obj);
            schedule_expiry();
        }
    }
}
```

### Watchdog Timer Pattern

```dml
constant clock_freq = 12.0e+6; // 12 Mhz

event watchdog_event is simple_time_event {
    method event() {
        log error: "Watchdog timeout! System reset triggered.";
        // Trigger system reset
        reset_signal.signal.signal_raise();
    }
}

register watchdog_ctrl {
    field enable @ [0];
    field kick @ [1] is (write_1_clears);
    filed timeout_cycles @ [31:2];

    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        default(value, enabled_bytes, aux);

        if (kick.val) {
            // Kick the watchdog - restart timeout
            kick.val = 0;
            restart_watchdog();
        }
    }
}

method restart_watchdog() {
    if (watchdog_event.posted())
        watchdog_event.remove();

    if (watchdog_ctrl.enable.val) {
        local double timeout = cast(timeout_cycles.val, double) / clock_freq;
        watchdog_event.post(timeout);
        log info, 4: "Watchdog restarted, timeout in %f seconds", timeout;
    }
}
```

### Timestamp Counter (TSC) Pattern

For modeling CPU timestamp counters that return different values at different simulation times:

```dml
// TSC-like counter that increments with CPU cycles
register tsc {
    param configuration = "none";  // Calculated, not checkpointed directly

    saved cycles_t tsc_base;      // Base value at last reset/write
    saved cycles_t tsc_base_time; // Cycle count when base was set

    method get() -> (uint64) {
        local cycles_t now = SIM_cycle_count(dev.obj);
        return tsc_base + (now - tsc_base_time);
    }

    method read() -> (uint64) {
        local uint64 value = get();
        log info, 4: "TSC read: 0x%x at cycle %d",
            value, SIM_cycle_count(dev.obj);
        return value;
    }

    method write(uint64 value) {
        tsc_base = value;
        tsc_base_time = SIM_cycle_count(dev.obj);
    }
}
```

**TSC with Frequency Scaling:**
```dml
param TSC_FREQ_MHZ = 2000.0;  // 2 GHz

register tsc {
    saved cycles_t tsc_base;
    saved double tsc_base_time;

    method get() -> (uint64) {
        local double now = SIM_time(dev.obj);
        local double elapsed = now - tsc_base_time;
        local uint64 ticks = cast(elapsed * TSC_FREQ_MHZ * 1e6, uint64);
        return cast(tsc_base, uint64) + ticks;
    }
}
```

### Periodic Timer Pattern

For timers that fire at regular intervals:

```dml
constant clock_freq = 12.0e+6; // 12 Mhz

event periodic_timer is simple_time_event {
    method event() {
        // Handle timer tick
        on_timer_tick();

        // Reschedule for next period
        if (timer_enabled.val) {
            local double period = cast(period_reg.val, double) / clock_freq;
            this.post(period);
        }
    }
}

method start_periodic_timer() {
    stop_periodic_timer();

    local double period = cast(period_reg.val, double) / clock_freq;
    periodic_timer.post(period);
}

method stop_periodic_timer() {
    if (periodic_timer.posted())
        periodic_timer.remove();
}
```

---

## Complete Timer Device Examples

### Timer Implementation Concepts

A hardware timer in Simics typically involves:
- A **timer register** with control fields (enable, start, value)
- A **time event** that fires when the timer expires
- **Frequency conversion** between simulation time and timer cycles
- **Start time tracking** for calculating elapsed time

**Simulation Time vs Timer Cycles:**
- **Simulation Time**: Absolute time in seconds returned by `SIM_time()`
- **Timer Cycles**: Hardware-specific count based on timer frequency
- **Conversion Formula**:
  ```
  cycles = simulation_time * frequency_hz
  simulation_time = cycles / frequency_hz
  ```

**Timer Event Flow:**
```
Software Write → Start Timer → Post Event → Event Fires → Handle Timeout
     ↓              ↓              ↓             ↓              ↓
  Enable=1    Log start time  Calc timeout   Clear enable   Set status
```

### Complete Timer Device Example

```dml
dml 1.4;

device timer_device;

import "simics/device-api.dml";

param classname = "timer_device";
param desc = "Hardware timer device with relative and absolute timer modes";

// Define log group for timer messages
loggroup timer_log;

// Timer frequency: 100 MHz
constant TIMER_FREQ_HZ = 100 * 1000 * 1000;

// ============================================================================
// Timer Event Definition
// ============================================================================

event timer_event is (simple_time_event) {
    // This method is called when the timer expires
    method event() {
        // Clear the running/busy bit
        timer_bank.TIMER_CONTROL.Enable.set(0);
        
        // Set the interrupt/timeout flag
        timer_bank.TIMER_STATUS.Timeout.set(1);
        
        // Log the expiration
        log info, 1, timer_log: "Timer expired at sim time %f", 
            SIM_time(dev.obj);
        
        // Optionally trigger an interrupt here
        // interrupt_pin.signal.signal_raise();
    }
    
    // Arm the timer with a timeout in simulation seconds
    method arm(double timeout_seconds) {
        local bool is_posted = posted();
        
        // If already posted, remove the old event
        if (is_posted) {
            remove();
            log info, 2, timer_log: "Removed previously posted timer";
        }
        
        // Post the new event
        post(timeout_seconds);
        log info, 2, timer_log: "Timer armed for %f seconds", timeout_seconds;
    }
    
    // Cancel the timer
    method cancel() {
        if (posted()) {
            remove();
            log info, 2, timer_log: "Timer cancelled";
        }
    }
}

// ============================================================================
// Helper Template for Time Conversion
// ============================================================================

template timer_helper {
    param frequency_hz default TIMER_FREQ_HZ;
    
    // Convert cycles to simulation time (seconds)
    method cycles_to_simtime(uint64 cycles) -> (double) {
        return cast(cycles, double) / frequency_hz;
    }
    
    // Convert simulation time to cycles
    method simtime_to_cycles(double simtime) -> (uint64) {
        return cast(simtime * frequency_hz, uint64);
    }
    
    // Get current time in cycles
    method get_current_cycles() -> (uint64) {
        local double sim_time = SIM_time(dev.obj);
        return simtime_to_cycles(sim_time);
    }
}

// ============================================================================
// Saved Variables for Timer State
// ============================================================================

// Store the simulation time when timer was started
saved double timer_start_simtime = 0.0;

// ============================================================================
// Timer Register Bank (Relative/Countdown Timer)
// ============================================================================

bank timer_bank is (timer_helper) {
    
    // -------------------------------------------------------------------------
    // TIMER_CONTROL Register
    // -------------------------------------------------------------------------
    register TIMER_CONTROL size 4 @ 0x00 {
        field Enable @ [0] "Timer enable/start bit";
        field AutoReload @ [1] "Auto-reload mode";
        field Reserved @ [31:2];
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            // Write the value to register fields first
            default(value, enabled_bytes, aux);
            
            // Check if timer is being enabled/started
            if (Enable.val == 1) {
                // Get the configured timeout value
                local uint64 timeout_cycles = TIMER_VALUE.Value.val;
                
                if (timeout_cycles == 0) {
                    log error: "Cannot start timer with zero timeout";
                    Enable.set(0);
                    return;
                }
                
                // Record the start time (critical for elapsed time calculation)
                timer_start_simtime = SIM_time(dev.obj);
                
                // Convert timeout cycles to simulation seconds
                local double timeout_seconds = cycles_to_simtime(timeout_cycles);
                
                // Arm/post the timer event
                timer_event.arm(timeout_seconds);
                
                log info, 1, timer_log: 
                    "Timer started: %lld cycles (%f sec) at simtime %f",
                    timeout_cycles, timeout_seconds, timer_start_simtime;
            } 
            else {
                // Timer is being disabled - cancel the event
                timer_event.cancel();
                log info, 1, timer_log: "Timer stopped by software";
            }
        }
    }
    
    // -------------------------------------------------------------------------
    // TIMER_VALUE Register
    // -------------------------------------------------------------------------
    register TIMER_VALUE size 4 @ 0x04 {
        field Value @ [31:0] "Timer timeout value in cycles";
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            // Just store the value - it will be used when timer is started
            default(value, enabled_bytes, aux);
            log info, 2, timer_log: "Timer value configured: %lld cycles", 
                Value.val;
        }
        
        method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
            // If timer is not running, return the configured value
            if (TIMER_CONTROL.Enable.val == 0) {
                return default(enabled_bytes, aux);
            }
            
            // Timer is running - calculate and return remaining cycles
            local double current_simtime = SIM_time(dev.obj);
            local double elapsed_simtime = current_simtime - timer_start_simtime;
            local uint64 elapsed_cycles = simtime_to_cycles(elapsed_simtime);
            
            local uint64 initial_cycles = Value.val;
            local uint64 remaining_cycles;
            
            if (elapsed_cycles >= initial_cycles) {
                // Timer should have expired (or is about to)
                remaining_cycles = 0;
            } else {
                remaining_cycles = initial_cycles - elapsed_cycles;
            }
            
            log info, 3, timer_log: 
                "Timer read: elapsed=%lld, remaining=%lld cycles",
                elapsed_cycles, remaining_cycles;
            
            return remaining_cycles;
        }
    }
    
    // -------------------------------------------------------------------------
    // TIMER_STATUS Register
    // -------------------------------------------------------------------------
    register TIMER_STATUS size 4 @ 0x08 {
        field Timeout @ [0] "Timer timeout occurred (write 1 to clear)";
        field Running @ [1] "Timer is currently running (read-only)";
        field Reserved @ [31:2];
        
        method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
            // Update running status dynamically
            Running.set(TIMER_CONTROL.Enable.val);
            return default(enabled_bytes, aux);
        }
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            // Allow clearing timeout flag by writing 1
            if ((value & 0x1) == 1) {
                Timeout.set(0);
                log info, 2, timer_log: "Timeout flag cleared";
            }
            // Running bit is read-only, ignore writes to it
        }
    }
    
    // -------------------------------------------------------------------------
    // TIMER_CURRENT Register (Read-only elapsed cycles)
    // -------------------------------------------------------------------------
    register TIMER_CURRENT size 4 @ 0x0C {
        field Value @ [31:0] "Current elapsed cycles (read-only)";
        
        method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
            if (TIMER_CONTROL.Enable.val == 0) {
                // Timer not running, return 0
                return 0;
            }
            
            // Calculate elapsed cycles since timer start
            local double current_simtime = SIM_time(dev.obj);
            local double elapsed_simtime = current_simtime - timer_start_simtime;
            local uint64 elapsed_cycles = simtime_to_cycles(elapsed_simtime);
            
            log info, 3, timer_log: 
                "Elapsed time: %f sec = %lld cycles",
                elapsed_simtime, elapsed_cycles;
            
            return elapsed_cycles;
        }
    }
}

// ============================================================================
// Absolute Target Timer Example
// ============================================================================

// This example shows a timer that uses an absolute target time
// (useful for timestamp-based timers like TSC-based timers)

event absolute_timer_event is (simple_time_event) {
    method event() {
        abs_timer_bank.ABS_TIMER_CONTROL.Run_Busy.set(0);
        abs_timer_bank.ABS_TIMER_STATUS.Expired.set(1);
        log info, 1, timer_log: "Absolute timer expired";
    }
    
    method arm(double timeout) {
        if (posted())
            remove();
        post(timeout);
    }

    method cancel() {
        if (posted())
            remove();
    }
}

bank abs_timer_bank is (timer_helper) {
    
    // Free-running counter register (like a TSC counter)
    register FREE_RUNNING_COUNTER size 8 @ 0x20 is (timer_helper) {
        method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
            // Return current simulation time converted to cycles
            return get_current_cycles();
        }
    }
    
    // Absolute target timer control
    register ABS_TIMER_CONTROL size 4 @ 0x28 {
        field Run_Busy @ [0] "Timer is running";
        field Reserved @ [31:1];
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            default(value, enabled_bytes, aux);
            
            // If enabling, arm the timer with current target
            if (Run_Busy.val == 1) {
                local uint64 target_cycles = ABS_TIMER_TARGET.Target_Cycles.val;
                local uint64 current_cycles = FREE_RUNNING_COUNTER.get_current_cycles();
                
                // Calculate delta cycles
                local uint64 delta_cycles;
                if (target_cycles > current_cycles) {
                    delta_cycles = target_cycles - current_cycles;
                } else {
                    // Target is in the past, fire immediately
                    delta_cycles = 0;
                }
                
                // Convert to simulation time
                local double timeout_seconds = cycles_to_simtime(delta_cycles);
                
                log info, 1, timer_log: 
                    "Absolute timer started: target=%lld, current=%lld, delta=%lld cycles (%f sec)",
                    target_cycles, current_cycles, delta_cycles, timeout_seconds;
                
                // Arm the event
                absolute_timer_event.arm(timeout_seconds);
            } else {
                // Disabling - cancel the event
                absolute_timer_event.cancel();
            }
        }
    }
    
    register ABS_TIMER_TARGET size 8 @ 0x2C {
        field Target_Cycles @ [63:0] "Absolute cycle count to trigger at";
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            default(value, enabled_bytes, aux);
            
            // If timer is already running, re-arm with new target
            if (ABS_TIMER_CONTROL.Run_Busy.val == 1) {
                local uint64 target_cycles = Target_Cycles.val;
                local uint64 current_cycles = FREE_RUNNING_COUNTER.get_current_cycles();
                
                // Calculate delta cycles
                local uint64 delta_cycles;
                if (target_cycles > current_cycles) {
                    delta_cycles = target_cycles - current_cycles;
                } else {
                    delta_cycles = 0;
                }
                
                // Convert to simulation time
                local double timeout_seconds = cycles_to_simtime(delta_cycles);
                
                log info, 1, timer_log: 
                    "Absolute timer target updated: target=%lld, current=%lld, delta=%lld cycles (%f sec)",
                    target_cycles, current_cycles, delta_cycles, timeout_seconds;
                
                // Re-arm the event
                absolute_timer_event.arm(timeout_seconds);
            }
        }
    }
    
    register ABS_TIMER_STATUS size 4 @ 0x34 {
        field Expired @ [0] "Timer has expired (write 1 to clear)";
        
        method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
            if ((value & 0x1) == 1) {
                Expired.set(0);
                log info, 2, timer_log: "Absolute timer expired flag cleared";
            }
        }
    }
}
```

### Key Timer Implementation Points

**1. Event Management:**
- Always check `posted()` before posting a new event to avoid multiple pending events
- Use `remove()` to cancel a posted **event object** before posting a new one
- Use `cancel_after()` to cancel an event created by the **`after` statement**
- `post(seconds)` schedules the event relative to current simulation time

**2. Tracking Start Time:**
```dml
// Critical for elapsed time calculation
saved double timer_start_simtime = 0.0;

// When timer starts:
timer_start_simtime = SIM_time(dev.obj);

// When reading elapsed time:
local double elapsed = SIM_time(dev.obj) - timer_start_simtime;
local uint64 elapsed_cycles = simtime_to_cycles(elapsed);
```

**3. Frequency Conversion Helper Methods:**
```dml
method cycles_to_simtime(uint64 cycles) -> (double) {
    return cast(cycles, double) / frequency_hz;
}

method simtime_to_cycles(double simtime) -> (uint64) {
    return cast(simtime * frequency_hz, uint64);
}
```

**4. Relative vs Absolute Timers:**

- **Relative Timer (countdown)**:
  - Software writes timeout duration
  - Timer counts down from initial value
  - Expires after duration elapses
  - Example: `TIMER_VALUE` in the code above

- **Absolute Timer (target-based)**:
  - Uses a free-running counter
  - Software writes absolute target cycle count
  - Timer expires when counter reaches target
  - Example: `ABS_TIMER_TARGET` in the code above

**5. Testing Your Timer:**

```python
# Create device and configure
$dev = (create-timer_device)

# Configure timer for 10ms (1M cycles at 100MHz)
$dev.bank.timer_bank.TIMER_VALUE = 1000000

# Start timer
$dev.bank.timer_bank.TIMER_CONTROL = 1

# Check immediate status
print $dev.bank.timer_bank.TIMER_VALUE
print $dev.bank.timer_bank.TIMER_CURRENT

# Advance time
run-cycles 500000

# Check mid-flight
print $dev.bank.timer_bank.TIMER_VALUE      # Should be ~500000
print $dev.bank.timer_bank.TIMER_CURRENT    # Should be ~500000

# Wait for expiration
run-cycles 500000

# Check completion
print $dev.bank.timer_bank.TIMER_STATUS     # Timeout bit should be set
print $dev.bank.timer_bank.TIMER_CONTROL    # Enable should be clear
```

---

## Common Timing Constants

```dml
// Common clock periods
param NS_PER_SECOND = 1e9;
param US_PER_SECOND = 1e6;
param MS_PER_SECOND = 1e3;

// HPET standard frequency (~14.318 MHz)
param HPET_FREQ_MHZ = 14.318179941;
param HPET_PERIOD = 1.0 / (HPET_FREQ_MHZ * 1e6);

// PIT frequency (1.193182 MHz)
param PIT_FREQ_MHZ = 1.193182;
param PIT_PERIOD = 1.0 / (PIT_FREQ_MHZ * 1e6);

// Convert cycles to time
method cycles_to_seconds(cycles_t cycles) -> (double) {
    return cast(cycles, double) / (clock_freq_mhz * 1e6);
}

// Convert time to cycles
method seconds_to_cycles(double seconds) -> (cycles_t) {
    return cast(seconds * clock_freq_mhz * 1e6, cycles_t);
}
```

---

## Best Practices Summary

### DO:

1. **Use lazy evaluation** for counters - calculate on read, not every cycle
2. **Use `saved` variables** for timing state that needs checkpointing
3. **Cancel pending events** before posting new ones
4. **Use appropriate time units** - cycles for CPU-bound, seconds for real-time
5. **Renormalize counters** periodically to maintain precision
6. **Handle counter overflow** correctly with proper masking
7. **Log timing events** at appropriate verbosity levels
8. **Validate input values** (e.g., reject zero timeout)
9. **Handle edge cases** (zero timeout, timer already running, target in the past)
10. **Calculate elapsed/remaining time dynamically** on read

### DON'T:

1. **Don't update counters every cycle** - use lazy evaluation
2. **Don't use `after` with stack-allocated data** - causes security issues
3. **Don't forget to cancel events** when disabling timers
4. **Don't mix time units** without explicit conversion
5. **Don't checkpoint calculated values** - checkpoint the base values instead
6. **Don't post events without checking** if one is already pending

### Checkpointing Timing State

```dml
// GOOD: Checkpoint base values
saved cycles_t counter_start_time;
saved uint64 counter_start_value;

// BAD: Don't checkpoint calculated values
// register counter { param configuration = "optional"; }  // Wrong!

// GOOD: Use configuration = "none" for calculated registers
register counter {
    param configuration = "none";
    method get() -> (uint64) {
        // Calculate from saved base values
    }
}
```

---

## Quick Reference Card

| Task | Method |
|------|--------|
| Schedule callback in N cycles | `after N cycles: method()` |
| Schedule callback in N seconds | `after N s: method()` |
| Schedule immediate callback | `after: method()` |
| Cancel pending `after` | `cancel_after()` |
| Get current simulation time | `SIM_time(dev.obj)` |
| Get current cycle count | `SIM_cycle_count(dev.obj)` |
| Post event (time) | `event.post(delay_seconds)` |
| Post event (cycles) | `event.post(delay_cycles)` |
| Remove posted event | `event.remove()` |
| Check if event posted | `event.posted()` |
| Get time to next event | `event.next()` |

---

**Document Status**: ✅ Complete  
**Extracted From**: DML_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Tested With**: Simics 7.57.0, DML 1.4, API version 7
