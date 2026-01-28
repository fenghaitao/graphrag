# Timer Devices

This document describes DML 1.4 device models in the **timer** category.

## Device List

- synopsys-apb-timers
- synopsys-apb-wdt
- synopsys-apb-wdt
- nios-v-timer
- sample-timer-device
- goldfish-rtc
- arm-generic-timer
- arm-generic-timer
- arm-sbsa-watchdog

## Key Features and DML Implementation

### synopsys-apb-timers

#### Device Declaration
```dml
device synopsys_apb_timers;
```

#### Device Parameters
```dml
param classname = "synopsys-apb-timers";
param desc = "DW Synopsys APB Timers";
param documentation = "model of Synopsys APB Timers, REV 2.13a"
                    + "<br></br>"
                    + "<br></br>"
                    + "Supported features:"
                    + "<ul>"
                    + "<li>Up to eight individual timers.</li>"
                    + "<li>Supports combined and individual timer interrupts.</li>"
                    + "<li>Each timer can also be used a free running clock source.</li>"
                    + "<li>PWM with toggle output.</li>"
                    + "<li>Frequency interface with update notification,"
                    + " used for instance for PWM devices.</li>"
                    + "</ul>"
                    + "Limitations:"
                    + "<ul>"
                    + "<li>The bit width of the timers are not individually configurable.</li>"
                    + "<li>Does not support PWM at 0%/100% duty cycle (constant level).</li>"
                    + "</ul>";
```

#### Imports
```dml
import "utility.dml";
import "bank-reset-storage.dml";
import "simics/devs/signal.dml";
import "simics/devs/frequency.dml";
import "simics/simulator-api.dml";
import "bank-accessor-interface.dml";
import "synopsys-templates.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank regs {
    is bank_with_optional_registers;
    is bank_accessor_interface;
    is bank_rdl_reset;

    param register_size = 4;

    register glb_irq_status      @ 0xa0 "Interrupt status of all timers";
    register glb_end_of_irq      @ 0xa4 "Clears all active interrupts";
    register glb_raw_irq_status  @ 0xa8 "Raw interrupt status of all timers";
    register comp_version        @ 0xac "Component version";

    saved uint32 glb_irq_mask;

    group timers[i < MAX_NUM_TIMERS] is (synopsys_timer) {
        param index = i;
        param irq = irq_dev[index];
    }

    register glb_irq
    }
```

#### Registers

**Example 2:**
```dml
register load_count       @ 0x0  + base1 "Count down value to start from";
```

---

### synopsys-apb-wdt

#### Device Declaration
```dml
device synopsys_apb_wdt;
```

#### Device Parameters
```dml
param classname = "synopsys-apb-wdt";
param desc = "DW Synopsys APB Watchdog";
param documentation = "model of DW Synopsys APB Watchdog Timeri, REV 1.12a"
                    + "<br></br>"
                    + "<br></br>"
                    + "Implements DW Watchdog with these supported features:"
                    + "<ul>"
                    + "<li>All modes of operation regarding interrupt and system"
                    + " reset generation is supported.</li>"
                    + "<li>All IP configuration parameters that affect simulation"
                    + " are modeled as Simics attributes.</li>"
                    + "<li>Hard coded timeout periods is supported.</li>"
                    + "<li>User defined timeout periods is supported.</li>"
                    + "<li>Initial timeout period is supported.</li>"
                    + "<li>Watchdog always enabled is supported.</li>"
                    + "</ul>"
                    + "Limitations:"
                    + "<ul>"
                    + "<li>Pause Mode is not supported.</li>"
                    + "</ul>";
```

#### Imports
```dml
import "utility.dml";
import "bank-reset-storage.dml";
import "simics/devs/signal.dml";
import "simics/simulator-api.dml";
import "wdt-attributes.dml";
import "bank-accessor-interface.dml";
import "synopsys-templates.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank regs {
    is bank_accessor_interface;
    is bank_rdl_reset;

    param register_size = 4;

    register WDT_CR             @ 0x0 "Control Register";
    register WDT_TORR           @ 0x4 "Timeout Range Register";
    register WDT_CCVR           @ 0x8 "Current Counter Value Register";
    register WDT_CRR            @ 0xc "Counter Restart Register";
    register WDT_STAT           @ 0x10 "Interrupt Status Register";
    register WDT_EOI            @ 0x14 "Interrupt Clear Register";
    register WDT_PROT_LEVEL     @ 0x1c "WDT Protection level";
    register WDT_COMP_PARAM_5   @ 0xe4 "Comp
    }
```

#### Registers

**Example 2:**
```dml
register WDT_CR             @ 0x0 "Control Register";
```

---

### synopsys-apb-wdt

#### Device Parameters
```dml
param documentation = "Watchdog Timer is always enabled from reset,"
                        + " WDT_EN field has not effect";
param documentation = "Default output response:"
                        + " 0 -> System reset only,"
                        + " 1 -> Interrupt and then a system reset";
param documentation = "If set, generate an interrupt when first timeout"
                        + " occurs, upon second timeout generate a system reset";
```

#### Imports
```dml
import "synopsys-attributes.dml";
import "utility.dml";
```

#### Attributes

**Example 2:**
```dml
attribute FREQ_HZ "Serial clock frequency in Hz";
attribute WDT_CNT_WIDTH "The Watchdog Timer counter width.";
attribute WDT_ALWAYS_EN {
    param documentation = "Watchdog Timer is always enabled from reset,"
                        + " WDT_EN field has not effect";
}
```

---

### nios-v-timer

#### Device Declaration
```dml
device nios_v_timer;
```

#### Device Parameters
```dml
param classname = "nios_v_timer";
param desc = "model of Nios V timer block";
param documentation = "Nios V timer block";
```

#### Imports
```dml
import "internal.dml";
import "simics/devs/signal.dml";
import "utility.dml";
import "simics/arch/risc-v.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank regs {
    register mtime    @ 0x0         "Time Value";
    register mtimecmp @ 0x8         "Time Compare Value";
    register msip     @ 0x10        "Software Interrupt";

    register mtip is (unmapped, no_reset);

    register msip size 4 is (write) {
        method write(uint64 val) {
            if (this.val != val) {
                log info, 4: "msip changed, %d -> %d", this.val, val & 1;

                if ((val & 1) == 1)
                    dev.msip.raise();
                else
                    dev.msip.lower();
            }
        }

        method hard_reset() {
            }
}
}
```

#### Registers

**Example 2:**
```dml
register mtime    @ 0x0         "Time Value";
```

---

### sample-timer-device

#### Device Declaration
```dml
device sample_timer_device;
```

#### Device Parameters
```dml
param desc = "sample timer device";
param documentation = "This is the <class>sample_timer_device</class> "
                          + "class, an example of how timer devices "
                          + "can be written in Simics.";
param documentation = "Device an interrupt should be forwarded to "
                              + "(interrupt controller)";
```

#### Imports
```dml
import "simics/devs/signal.dml";
import "utility.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank regs {
    param register_size = 2;
    param byte_order = "big-endian";
    param use_io_memory = false;

    // Records the time when the counter register was started.
    saved cycles_t counter_start_time;
    // Records the start value of the counter register.
    saved cycles_t counter_start_value;

    register counter   @ 0x0 "Counter register";
    register reference @ 0x2 "Reference counter register";
    register step      @ 0x4
        "Counter is incremented every STEP clock cycles. 0 means stopped.";
    register config    @ 0x6 "Configuration register" {
        field clear_
        }
}
```

**Example 2:**
```dml
bank regs {
    register counter is (get, read, write) {
        param configuration = "none";

        method write(uint64 value) {
            counter_start_value = value;
            restart();
        }

        method get() -> (uint64) {
            if (step.val == 0) {
                return counter_start_value;
            }

            local cycles_t now = SIM_cycle_count(dev.obj);
            return (now - counter_start_time) / step.val
                + counter_start_value;
        }

        method read() -> (uint64) {
            return get();
        }

        method restart() {
            }
}
}
```

---

### goldfish-rtc

#### Device Declaration
```dml
device goldfish_rtc;
```

#### Device Parameters
```dml
param classname = "goldfish-rtc";
param desc = "goldfish virtual hardware real-time clock";
param documentation = "RTC alarm interrupt request";
```

#### Imports
```dml
import "utility.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank regs is hard_reset {
    param use_io_memory = false;
    param register_size = 4;

    saved uint64 current_time; // all 64 bits of current time
    saved bool irq_pending;

    method hard_reset() {
        default();
        current_time = 0;
        irq_pending = false;
    }

    register time size 8        @  0x0 {
        field low @ [31:0]
            "Lower 32 bits of current time in ns. Reading updates register time_high";
        field high @ [63:32]
            "Higher 32 bits of current time in ns. Reading returns time at last read of register time_low";
    }
    register al
    }
```

**Example 2:**
```dml
bank regs {
    register time is hard_reset {
        method hard_reset() {
            default();
            this.val = initial_time.val * 1000_000_000;
        }

        method calc_current_time() -> (uint64) {
                local double now = SIM_time(dev.obj);
                local uint64 result = this.val + sim_time_to_ns(now);

                log info, 4: "start time: %lu ns, current sim time: %lu ns, result: %lu ns",
                    this.val, sim_time_to_ns(now), result;
                return result;
        }

        field low is (get, read) {
            method get() -> (ui
            }
}
}
```

---

### arm-generic-timer

#### Device Declaration
```dml
device armv8_generic_timer;
```

#### Device Parameters
```dml
param desc = "model of ARMv8 generic timer";
param documentation = "This implements the Generic Timer described in the"
    + " ARMv8 architecture profile";
param desc = parent.desc + " Control";
```

#### Imports
```dml
import "simics/model-iface/concurrency.dml";
import "armv8-aarch32-interface.dml";
import "utility.dml";
import "simics/devs/signal.dml";
import "simics/devs/frequency.dml";
import "simics/simulator-api.dml";
import "simics/arch/arm.dml";
import "simics/model-iface/int-register.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank aarch64 "aarch64 timer registers" {
    /* Traps, aliasing of _el02 and _el12 registers and VHE redirecting of
       registers from el2 is handled in the CPU code */
    param register_size = 8;
    in each register { is sysreg; }

    register cntfrq               "Frequency";
    register cnthctl  is (ctl)    "Hypervisor Control";
    register cntkctl  is (ctl)    "Kernel Control";
    register cntpct               "Physical Count";
    register cntvct               "Virtual Count";
    register cntvoff              "Virtual Offset";
    register cntpoff  is (unimpl) "Physical Offset";
    }
```

#### Registers

**Example 2:**
```dml
register cntfrq               "Frequency";
```

---

### arm-generic-timer

#### Device Parameters
```dml
param desc = "Aarch32 aliased " + tgt.desc;
```

#### Memory Banks

**Example 1:**
```dml
bank aarch32 "aarch32 timer registers" {
    /* These registers are architecturally mapped to Aarch64 counterparts */
    in each register { is aarch32_sysreg; }

    register cntfrq   size 4 { param tgt = aarch64.cntfrq; }
    register cntkctl  size 4 { param tgt = aarch64.cntkctl; }
    register cnthctl  size 4 { param tgt = aarch64.cnthctl; }
    register cntvoff  size 8 { param tgt = aarch64.cntvoff; }
    register cntpct   size 8 { param tgt = aarch64.cntpct; }
    register cntvct   size 8 { param tgt = aarch64.cntvct; }
    register cntpctss size 8 { param tgt = aarch64.cntpctss; }
    r
    }
```

#### Registers

**Example 2:**
```dml
register cntfrq   size 4 { param tgt = aarch64.cntfrq; }
```

---

### arm-sbsa-watchdog

#### Device Declaration
```dml
device sbsa_watchdog;
```

#### Device Parameters
```dml
param desc = "model of an ARM SBSA Watchdog";
param documentation = "This implements a Generic Watchdog as described in"
    + "ARM Server Base System Architecture";
```

#### Imports
```dml
import "simics/devs/signal.dml";
import "simics/model-iface/int-register.dml";
import "utility.dml";
import "simics/devs/frequency.dml";
```

#### Memory Banks

**Example 1:**
```dml
bank refresh is regs_common {
    register wrr @ 0x000 "Watchdog Refresh";
    register iid @ 0xfcc "Watchdog Interface Identification";

    register wrr is (refresh_reg, read_zero);
    register iid is (read_only, read) {
        param configuration = "pseudo";
        method read() -> (uint64) {
            return control.iid.val;
        }
        method get() -> (uint64) {
            return read();
        }
    }
}
```

**Example 2:**
```dml
bank control is regs_common {
    param partial = true;
    register wcs        @ 0x000 "Watchdog Control and Status";
    register wor size 8 @ 0x008 "Watchdog Offset";
    register wcv size 8 @ 0x010 "Watchdog Compare Value";
    register iid        @ 0xfcc "Watchdog Interface Identification";

    register wcs is (refresh_reg) {
        field status @ [2:1] is (ignore_write) "Signal status bits";
        field enable @ [0];
    }
    register wor is (refresh_reg)  {
        field offs @ [63:0] is write {
            method write(uint64 value) {
                if (iid.arch.val == 0)
                }
}
}
}
```

---

