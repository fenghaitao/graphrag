# DML Common Device Patterns and Examples

## Overview

This document provides practical, reusable patterns and complete examples for common device types in Simics DML. Each example is self-contained and can be used as a starting point for your own device models.

## Table of Contents

1. [Device with Interrupts](#device-with-interrupts)
2. [Basic UART Example](#basic-uart-example)
3. [Simple PCI Device](#simple-pci-device)

---

## Device with Interrupts

A device that can generate interrupts using signal interfaces.

```dml
dml 1.4;

device interrupt_device;

import "utility.dml";
import "simics/devs/signal.dml";
import "simics/device-api.dml";

param classname = "interrupt_device";
param desc = "Device that can generate interrupts";

// connect attribute is used for wire/bus signal/transaction to output
connect irq {
    param configuration = "optional";
    param c_type = "simple_interrupt";
    interface signal;
}

// port attribute is used for wire/bus signal/transaction to input
port reset_n {
    param configuration = "optional";
    param desc = "reset signal input";

    implement signal {
        // empty implementation as a simple example
        method signal_raise() {}
        // empty implementation as a simple example
        method signal_lower() {}
    }
}

bank regs {
    param function = 0x2000;
    param register_size = 4;

    register INTERRUPT_ENABLE @ 0x00 {
        param size = 4;
        param desc = "Interrupt enable register";
    }

    register INTERRUPT_STATUS @ 0x04 {
        param size = 4;
        param desc = "Interrupt status register";

        method write(uint64 value) {
            // Clear interrupt on write
            this.val = this.val & ~value;
            update_interrupt();
        }
    }
}

method update_interrupt() {
    if (regs.INTERRUPT_ENABLE.val & regs.INTERRUPT_STATUS.val) {
        if (irq.obj) {
            irq.signal.signal_raise();
        }
    }
}
```

**Key Features:**
- `connect irq`: Output signal for raising interrupts
- `port reset_n`: Input signal for receiving reset
- Interrupt enable/status registers
- Write-to-clear status bits
- Automatic interrupt update on register changes

**Python Connection Example:**
```python
dev = SIM_create_object("interrupt_device", "my_int_dev")
intc = SIM_get_object("interrupt_controller")
dev.irq = intc
```

---

## Basic UART Example

A 16550-compatible UART device with data and status registers.

```dml
dml 1.4;

device uart_16550;

import "simics/device-api.dml";

param classname = "uart_16550";
param desc = "16550-compatible UART device";

bank uart_regs {
    param function = 0x3f8;
    param register_size = 1;

    // Data register / Divisor latch low
    register RBR_THR_DLL @ 0x00 {
        param size = 1;
        param desc = "Receiver buffer/Transmitter holding/Divisor latch low";

        method write(uint64 value) {
            if (LCR.val & 0x80) {
                // Divisor latch access
                log info: "Divisor latch low set to 0x%02x", value;
            } else {
                // Transmit data
                log info: "UART transmit: 0x%02x ('%c')", value,
                         (value >= 32 && value < 127) ? value : '?';
            }
            this.val = value;
        }

        method read() -> (uint64) {
            if (LCR.val & 0x80) {
                return this.val;  // Divisor latch
            } else {
                log info: "UART receive read";
                return 0x00;  // No data available
            }
        }
    }

    // Interrupt enable register / Divisor latch high
    register IER_DLH @ 0x01 {
        param size = 1;
        param desc = "Interrupt enable/Divisor latch high";
    }

    // Line control register
    register LCR @ 0x03 {
        param size = 1;
        param desc = "Line control register";
        param init_val = 0x03;  // 8N1
    }

    // Line status register
    register LSR @ 0x05 {
        param size = 1;
        param desc = "Line status register";
        param init_val = 0x60;  // TX empty and ready
    }
}
```

**Register Map:**
- `0x3f8 + 0x00`: Data/Divisor Low (context-dependent)
- `0x3f8 + 0x01`: Interrupt Enable/Divisor High
- `0x3f8 + 0x03`: Line Control (controls DLAB bit)
- `0x3f8 + 0x05`: Line Status (always reports ready)

**Key Features:**
- DLAB (Divisor Latch Access Bit) in LCR controls register 0x00/0x01 meaning
- Character transmission logging
- Standard 16550 register layout
- 8N1 default configuration

---

## Simple PCI Device

A basic PCI device with configuration space and BARs.

```dml
dml 1.4;

device simple_pci;

import "simics/device-api.dml";

param classname = "simple_pci";
param desc = "Simple PCI device template";

// PCI configuration space
bank pci_config {
    param function = 0;  // Will be mapped by PCI bus
    param register_size = 4;

    register VENDOR_ID @ 0x00 {
        param size = 2;
        param desc = "PCI Vendor ID";
        param init_val = 0x8086;  // Intel
        param read_only = true;
    }

    register DEVICE_ID @ 0x02 {
        param size = 2;
        param desc = "PCI Device ID";
        param init_val = 0x1234;  // Custom device
        param read_only = true;
    }

    register COMMAND @ 0x04 {
        param size = 2;
        param desc = "PCI Command register";
    }

    register STATUS @ 0x06 {
        param size = 2;
        param desc = "PCI Status register";
        param init_val = 0x0200;  // 66MHz capable
    }
}

// Device-specific registers
bank device_regs {
    param function = 0x1000;  // BAR0 mapping
    param register_size = 4;

    register CONTROL @ 0x00 {
        param size = 4;
        param desc = "Device control register";
    }

    register STATUS @ 0x04 {
        param size = 4;
        param desc = "Device status register";
        param init_val = 0x1;  // Ready
    }
}
```

**PCI Configuration Space Layout:**
- Vendor ID: `0x8086` (Intel)
- Device ID: `0x1234` (custom)
- Status: `0x0200` (66MHz capable)

**Device Registers (BAR0):**
- Base address: `0x1000`
- CONTROL register: `0x00`
- STATUS register: `0x04`

**Key Features:**
- Standard PCI configuration space
- Read-only vendor/device ID
- Separate bank for device-specific registers
- Ready for PCI bus integration

---

## Pattern Summary

### When to Use Each Pattern

| Pattern | Use Case |
|---------|----------|
| Interrupt Device | Device that needs to signal CPU |
| UART | Serial communication device |
| PCI Device | Devices on PCI bus |

### Common Elements Across Patterns

1. **Always import**: `import "simics/device-api.dml";`
2. **Set classname**: `param classname = "device_name";`
3. **Add description**: `param desc = "...";`
4. **Use banks**: Group related registers in banks
5. **Set base address**: `param function = 0x...;`
6. **Add register docs**: `param desc = "...";` for each register

### Extending These Patterns

To extend any pattern:

1. **Add more registers**: Define in the bank with `@ offset`
2. **Add fields**: Use `field name @ [bits]` inside registers
3. **Add custom behavior**: Override `read()` or `write()` methods
4. **Add state**: Use `saved` variables for persistent state
5. **Add logging**: Use `log info:`, `log error:` for debugging

---

**Document Status**: ✅ Complete  
**Extracted From**: DML_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Tested With**: Simics 7.57.0, DML 1.4, API version 7
