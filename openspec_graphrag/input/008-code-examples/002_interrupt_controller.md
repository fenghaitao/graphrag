# Interrupt Controller Devices

This document describes DML 1.4 device models in the **Interrupt Controller** category.

## Device List

- riscv-clint (RISC-V Core-Level Interrupt Controller)

## Key Features and DML Implementation

### riscv-clint

RISC-V Core-Level Interrupt Controller with timer and software interrupts.

#### Device Declaration

```dml
device riscv_clint;
param classname = "riscv-clint";
```

#### Device Parameters

```dml
param desc = "model of RISC-V CLINT block";
param documentation = "RISC-V Core-Level Interrupt Block";
param limitations = "Timer interrupts are not correctly modeled if mtime"
    + " overflows, for a 1GHz timer this happens approximately after 585 years"
    + " of virtual time. It is assumed that the timer will be have been reset"
    + " before that";
```

**Description:**
- Core-Level Interrupt Controller for RISC-V processors
- Provides software and timer interrupts
- Time overflow limitation documented
- Supports up to 64 HARTs (hardware threads)

## Interrupt Interface Connection

### Signal Connect Declaration

Signal connections allow the interrupt controller to raise/lower interrupts to CPUs.

#### Software Interrupt Signal (MSIP)

```dml
connect msip[i < MAX_HARTS] is (sig) "The MSIP signal targets" {
    method raise() {
        default();
        regs.msip[i].val[0] = 1;
    }
    method lower() {
        default();
        regs.msip[i].val[0] = 0;
    }
}
```

**Description:**
- **Array of Connections**: One MSIP signal per HART
- **sig Template**: Provides standard signal interface
- **raise() Method**: 
  - Calls default() to signal the connected CPU
  - Updates internal register to track state
- **lower() Method**: 
  - Calls default() to clear the signal
  - Clears internal register bit
- **State Tracking**: Register bit mirrors signal state

#### Timer Interrupt Signal (MTIP)

```dml
connect mtip[i < MAX_HARTS] is (sig) "The MTIP signal targets" {
    method raise() {
        default();
        regs.mtip[i].val[0] = 1;
    }
    method lower() {
        default();
        regs.mtip[i].val[0] = 0;
    }
}
```

**Description:**
- **Array of Connections**: One MTIP signal per HART
- **sig Template**: Standard signal interface
- **Dual State**: Both signal and register updated together
- **Consistency**: Ensures signal and register stay synchronized

### Signal Port Declaration

Ports allow external devices to signal the interrupt controller.

#### Clock Disable Port

```dml
port CLOCK_DISABLE is signal_port {
    param documentation = "When the CLOCK_DISABLE signal is raised mtime will"
        + " not advance and no new timer interrupts will be triggered";

    method remove_all_timers() {
        for (local int i = 0; i < timeout.len; i++)
            timeout[i].remove();
    }

    implement signal {
        method signal_raise() {
            local uint64 now = regs.mtime._read();
            log info, 3: "signal raised";
            default();
            regs.mtime.val = now;
            remove_all_timers();
        }
        method signal_lower() {
            log info, 3: "signal lowered";
            local uint64 now = regs.mtime.val;
            default();
            last_update.val = SIM_time(obj);
            for (local int i = 0; i < MAX_HARTS; i++)
                if (dev.mtip[i].obj)
                    timeout[i].check(now);
        }
    }
}
```

**Description:**
- **signal_port Template**: Provides signal interface on a port
- **signal_raise()**:
  - Reads current time value
  - Freezes time counter
  - Removes all pending timer events
  - Prevents timer progression during clock disable
- **signal_lower()**:
  - Resumes time counter
  - Restarts timer tracking
  - Checks all timer compare values
  - Re-posts timer events as needed
- **Logging**: Debug logging for signal transitions

## Interrupt Toggling Implementation

### Software Interrupt Toggling

Software interrupts are controlled by writing to the MSIP register.

#### MSIP Register Write Method

```dml
register msip[i < MAX_HARTS] size 4 is (write) {
    method write(uint64 val) {
        if (this.val != val) {
            if (val[0])
                dev.msip[i].raise();
            else
                dev.msip[i].lower();
        }
    }

    method hard_reset() {
        dev.msip[i].lower();
    }
}
```

**Description:**
- **Change Detection**: Only updates if value changes
- **Bit 0 Check**: Tests LSB to determine raise/lower
- **Raise**: When bit 0 is set (val[0] == 1)
- **Lower**: When bit 0 is clear (val[0] == 0)
- **Reset Behavior**: Always lowers signal on hard reset
- **Direct Connection**: Register write directly controls signal

### Timer Interrupt Toggling

Timer interrupts are triggered when mtime >= mtimecmp.

#### Timer Compare Register Write

```dml
register mtimecmp[i < MAX_HARTS] is (write, no_reset) {
    method write(uint64 val) {
        default(val);
        timeout[i].check(mtime._read());
    }
}
```

**Description:**
- **Write Handler**: Updates compare value
- **Immediate Check**: Checks if interrupt should trigger
- **No Reset**: Compare value preserved across resets
- **Event Scheduling**: May schedule/remove timer events

#### Timer Event Check Logic

```dml
event timeout[i < MAX_HARTS] is (simple_time_event) {
    method event() {
        check(regs.mtime._read());
    }

    method check(uint64 count) {
        remove();
        if (count >= regs.mtimecmp[i].val) {
            log info, 3: "mtimecmp%d pending now (0x%x >= 0x%x)",
                i, count, regs.mtimecmp[i].val;
            dev.mtip[i].raise();
        } else {
            dev.mtip[i].lower();
            local uint64 ticks = regs.mtimecmp[i].val - count;
            local double seconds = ticks / frequency;
            // Make sure the event isn't posted too far ahead
            if (seconds > SECONDS_IN_A_WEEK)
                seconds = SECONDS_IN_A_WEEK;
            log info, 3: "mtimecmp%d pending in 0x%x ticks, %fs",
                i, ticks, seconds;
            post(seconds);
            log info, 3: "event posted in %fs", seconds;
        }
    }
}
```

**Description:**
- **Event-Based**: Uses simple_time_event for scheduling
- **Compare Logic**: Checks if mtime >= mtimecmp
- **Raise Condition**: When timer expires (count >= threshold)
- **Lower Condition**: When timer not yet expired
- **Event Scheduling**:
  - Calculates ticks until expiration
  - Converts to seconds using frequency
  - Posts event for that time
- **Safety Limit**: Caps event posting to one week
- **Logging**: Detailed debug information

#### Time Register Write Method

```dml
register mtime is write {
    method write(uint64 val) {
        this.val = val;
        last_update.val = SIM_time(obj);
        local uint64 count = regs.mtime._read();
        for (local int i = 0; i < MAX_HARTS; i++)
            if (dev.mtip[i].obj)
                timeout[i].check(count);
    }

    method hard_reset() {
        write(0);
    }
}
```

**Description:**
- **Write Handler**: Updates time value
- **Timestamp**: Records update time
- **Re-check All**: Checks all timer comparisons
- **Connection Check**: Only checks connected HARTs
- **Reset**: Clears time to zero
- **Interrupt Updates**: May raise/lower timer interrupts

### Register-Driven Interrupt Updates

Interrupts can be explicitly controlled from register writes.

#### Register Value to Signal

```dml
register msip[i < MAX_HARTS] size 4 is (write) {
    method write(uint64 val) {
        if (this.val != val) {
            if (val[0])
                dev.msip[i].raise();
            else
                dev.msip[i].lower();
        }
    }
}
```

**Flow:**
1. Software writes to MSIP register
2. Write method compares new vs old value
3. If changed, extracts bit 0
4. Calls raise() or lower() on connect
5. Connect's raise/lower updates signal and register state
6. CPU receives interrupt signal

#### Timer Compare to Signal

```dml
register mtimecmp[i < MAX_HARTS] is (write, no_reset) {
    method write(uint64 val) {
        default(val);
        timeout[i].check(mtime._read());
    }
}
```

**Flow:**
1. Software writes new compare value
2. Write method stores value
3. Calls timeout event check()
4. check() compares mtime vs mtimecmp
5. If expired: raises MTIP signal
6. If not expired: lowers MTIP, schedules event
7. Event fires when timer expires
8. Event calls check() which raises MTIP

## Interrupt State Management

### Internal State Tracking

```dml
register mtip[i < MAX_HARTS] is (unmapped, no_reset);
```

**Description:**
- **Unmapped**: Not accessible from external bus
- **No Reset**: State preserved across soft resets
- **Internal Only**: Used for state tracking
- **Mirrors Signal**: Tracks MTIP signal state

### Connect Raise/Lower Methods

```dml
connect msip[i < MAX_HARTS] is (sig) "The MSIP signal targets" {
    method raise() {
        default();
        regs.msip[i].val[0] = 1;
    }
    method lower() {
        default();
        regs.msip[i].val[0] = 0;
    }
}
```

**Description:**
- **default() Call**: Performs actual signal operation
- **State Update**: Updates register to match signal
- **Atomic**: Both operations happen together
- **Consistency**: Register always reflects signal state

## Complete Example: Timer Interrupt Flow

**Setup Phase:**
1. Software writes mtimecmp[0] = 1000
2. Current mtime = 0
3. check() is called
4. mtime (0) < mtimecmp (1000)
5. MTIP signal is lowered
6. Event scheduled for when mtime reaches 1000

**Interrupt Trigger:**
7. Time advances, event fires
8. event() calls check(mtime)
9. mtime (1000) >= mtimecmp (1000)
10. dev.mtip[0].raise() is called
11. raise() calls default() → signal to CPU
12. raise() sets regs.mtip[0].val[0] = 1
13. CPU receives timer interrupt

**Interrupt Clear:**
14. Software writes new mtimecmp[0] = 2000
15. check() is called
16. mtime (1000) < mtimecmp (2000)
17. dev.mtip[0].lower() is called
18. lower() calls default() → clear signal to CPU
19. lower() sets regs.mtip[0].val[0] = 0
20. CPU interrupt cleared, new event scheduled

## Summary

RISC-V CLINT interrupt controller demonstrates:

1. **Signal Connections**: Array of signal connections to CPUs
2. **Signal Ports**: Input signals for external control
3. **Raise/Lower Methods**: Explicit interrupt control
4. **Register-Driven**: Register writes trigger signal changes
5. **Event-Based**: Timer events for delayed interrupts
6. **State Tracking**: Internal registers mirror signal state
7. **Dual Interrupt Types**: Software (MSIP) and timer (MTIP)
8. **Reset Handling**: Proper signal state on reset
9. **Logging**: Debug visibility of signal transitions
10. **Consistency**: Register and signal state always synchronized

The implementation patterns show:
- Clean separation of register and signal logic
- Event-driven timer interrupt generation
- Explicit state management
- Proper reset behavior
- Direct register-to-interrupt mapping for software interrupts
- Scheduled events for timer interrupts
