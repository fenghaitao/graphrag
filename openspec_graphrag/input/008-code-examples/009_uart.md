# UART Devices

This document describes DML 1.4 device models in the **UART** category.

## Device List

- synopsys-apb-uart (DW Synopsys APB UART)
- pl011-uart (ARM PrimeCell UART)

## Key Features and DML Implementation

### synopsys-apb-uart

The Synopsys APB UART is a production-quality UART peripheral with comprehensive features including FIFOs, DMA support, modem control, and various interrupt modes.

#### Device Declaration

```dml
device synopsys_apb_uart;
param classname = "synopsys-apb-uart";
param desc = "DW Synopsys APB UART";
```

#### Device Parameters

```dml
param documentation = "model of DW Synopsys APB UART, REV 4.02a"
                    + "<br></br>"
                    + "Supported features:"
                    + "<ul>"
                    + "<li>FIFOs are supported.</li>"
                    + "<li>All interrupts are supported.</li>"
                    + "<li>Modem control is supported.</li>"
                    + "<li>DMA with threshold levels is supported.</li>"
                    + "<li>Resetting the UART, RX-FIFO and TX-FIFO through register writes.</li>"
                    + "</ul>"
                    + "Limitations:"
                    + "<ul>"
                    + "<li>UART RS485 is not supported.</li>"
                    + "<li>9-bit data not supported.</li>"
                    + "</ul>";
```

#### Register Map

The UART uses overlaid registers for compatibility with different access modes:

```dml
bank regs {
    param register_size = 4;
    
    // Data and baud rate registers (overlaid based on DLAB bit)
    register RBR_DLL_THR    @ 0x0 "Registers RBR, DLL and THR overlaid";
    register RBR is unmapped       "Receive Buffer Register";
    register DLL is unmapped       "Divisor Latch (Low)";
    register THR is unmapped       "Transmit Holding Register";
    
    // Interrupt enable and baud rate high (overlaid based on DLAB)
    register DLH_IER        @ 0x4 "Registers DLH and IER overlaid";
    register DLH is unmapped       "Divisor Latch High (DLH) Register";
    register IER is unmapped       "Interrupt Enable Register";
    
    // FIFO control and interrupt identification (overlaid)
    register FCR_IIR        @ 0x8 "Shared area for w/o FCR and r/o IIR register";
    register FCR is (unmapped)     "FIFO Control Register";
    register IIR is (unmapped)     "Interrupt Identification Register";
    
    // Control and status registers
    register LCR            @ 0xc "Line Control Register";
    register MCR            @ 0x10 "Modem Control Register";
    register LSR            @ 0x14 "Line Status Register";
    register MSR            @ 0x18 "Modem Status Register";
    
    // FIFO management registers
    register USR            @ 0x7c "UART Status register";
    register TFL            @ 0x80 "Transmit FIFO Level";
    register RFL            @ 0x84 "Receive FIFO Level";
    register SRR            @ 0x88 "Software Reset Register";
}
```

### UART Peripheral Logic Implementation

#### 1. Transmit (TX) Logic

The transmit path handles data from CPU to serial output, with FIFO buffering and baud rate timing.

**Transmit Buffer Register (THR):**

```dml
register THR is (hard_reset) {
    // Tracks if data is present in non-FIFO mode
    saved bool reg_has_data;
    
    field THR @ [7:0] is (write, write_only) {
        method write(uint64 value) {
           this.parent.push(value);
        }
    }
    
    method is_empty() -> (bool) {
        return in_fifo_mode ? tx_fifo.is_empty() : !reg_has_data;
    }
    
    method is_full() -> (bool) {
        return in_fifo_mode ? tx_fifo.is_full() : reg_has_data;
    }
    
    method pop() -> (uint8) {
        assert(!is_empty());
        local uint8 value;
        if (in_fifo_mode) {
             value = tx_fifo.pop();
        } else {
            reg_has_data = false;
            value = this.val;
        }
        irq_dev.update();
        return value;
    }
    
    method push(uint8 value) {
        if (in_fifo_mode) {
            tx_fifo.push(value);
        } else {
            reg_has_data = true;
            this.val = value;
        }
        irq_dev.update();
        transfer.try_start();
    }
}
```

**Character Transmission Logic:**

```dml
group transfer is (hard_reset) {
    saved bool posted;
    
    method try_start() {
        // Check if transmission is allowed
        if (console.ready && !LCR.BC.val && !HTX.HTX.val) {
            if (!THR.is_empty() && !posted) {
                local uint8 value = THR.pop();
                if (valid_baud_rate()) {
                    posted = true;
                    // Optionally simulate baud rate delay
                    if (SIMULATE_BAUDRATE.val)
                        after character_time_s() s : send(value[LCR.DLS.data_bits() - 1: 0]);
                    else
                        send(value[LCR.DLS.data_bits() - 1: 0]);
                } else {
                    log spec_viol, 1 then 4:
                        "Baud divisor is zero, no UART communication will take place";
                }
            }
        } else {
            if (posted) {
                posted = false;
                cancel_after();
            }
        }
    }
    
    method send(uint8 character) {
        posted = false;
        // Handle loopback mode or normal transmission
        if (!MCR.LoopBack.val)
            console.try_write(character);
        else
            RBR.push(character);  // Loopback to receive buffer
        try_start();  // Try to send next character
    }
}
```

**Baud Rate Calculation:**

```dml
method baud_divisor() -> (uint64) {
    return (DLH.DLH.val << 8) + DLL.DLL.val;
}

method valid_baud_rate() -> (bool) { 
    return baud_divisor() != 0; 
}

method character_time_s() -> (double) {
    local uint64 divisor = 16 * baud_divisor();
    if (divisor == 0)
        return 0;

    local uint64 baud_rate = FREQ_HZ.val / divisor;

    if (baud_rate == 0)
        return 1.0;
    else
        return 1.0 / cast(baud_rate, double);
}
```

#### 2. Receive (RX) Logic

The receive path handles data from serial input to CPU, with FIFO buffering and error detection.

**Receive Buffer Register (RBR):**

```dml
register RBR is (hard_reset) {
    // Tracks if data is present in non-FIFO mode
    saved bool reg_has_data;
    
    field RBR @ [8:0] is (read, read_only, get) {
        method read() -> (uint64) {
            local uint64 value;
            if (!IER.ELCOLR.val) { 
                // Clear error IRQs on read
                LSR.BI.val = 0;
                LSR.FE.val = 0;
                LSR.PE.val = 0;
                LSR.OE.val = 0;
            }

            if (in_fifo_mode) {
                value = rx_fifo.pop();
            } else {
                reg_has_data = false;
                value = this.val;
            }
            irq_dev.update();
            return value;
        }
        
        method get() -> (uint64) {
            return in_fifo_mode ? rx_fifo.peek() : this.val;
        }
    }
    
    method is_empty() -> (bool) {
        return in_fifo_mode ? rx_fifo.is_empty() : !reg_has_data;
    }
    
    method push(uint8 value) {
        if (in_fifo_mode) {
            rx_fifo.push(value);
        } else {
            reg_has_data = true;
            this.val = value;
        }
        irq_dev.update();
    }
}
```

**Serial Device Connection:**

```dml
connect console is (hard_reset) {
    param documentation = "Console or device connected to the serial port";

    saved bool ready = true;
    interface serial_device;

    method try_write(int val) {
        if (this.obj) {
            if (serial_device.write(val) == 0) {
                ready = false;
                // Will be notified when ready again
            }
        }
    }

    implement serial_device {
        // Called when external device sends data to UART
        method receive(int value, uint64 delay) {
            if (value != -1) {
                RBR.push(value);
            }
        }

        // Called when external device is ready for more data
        method receive_ready() {
            ready = true;
            transfer.try_start();
        }
    }
}
```

#### 3. FIFO Management Logic

FIFOs buffer transmit and receive data, with configurable depth and threshold levels.

**FIFO Control Register:**

```dml
register FCR is (write) {
    field RT @ [7:6] is (optional_wo_field) "RCVR Trigger" {
        param ignore = FIFO_MODE.val == 0;
        
        param FIFO_CHAR1_TRIGGER = 0x0;
        param FIFO_QUARTER_FULL = 0x1;
        param FIFO_HALF = 0x2;
        param FIFO_FULL_2 = 0x3;
        
        method owrite(uint64 value) {
            default(value);
            irq_dev.update();
            update_dmac_receive();
        }
        
        method above_threshold() -> (bool) {
            if (FIFO_MODE.val == 0)
                return false;
            
            switch (this.val) {
                case FIFO_CHAR1_TRIGGER:
                    return !rx_fifo.is_empty();
                case FIFO_QUARTER_FULL:
                    return rx_fifo.len() >= (FIFO_MODE.val / 4);
                case FIFO_HALF:
                    return rx_fifo.len() >= (FIFO_MODE.val / 2);
                case FIFO_FULL_2:
                    return rx_fifo.len() >= (FIFO_MODE.val - 2);
                default:
                    assert(false);
            }
        }
    }
    
    field TET @ [5:4] is (optional_wo_field) "TX Empty Trigger" {
        param ignore = !THRE_MODE_USER.val;

        param FIFO_EMPTY_TRIGGER = 0x0;
        param FIFO_2_CHAR_TRIGGER = 0x1;
        param FIFO_QUARTER_FULL = 0x2;
        param FIFO_HALF = 0x3;
        
        method below_threshold() -> (bool) {
            assert(THRE_MODE_USER.val);
            switch (this.val) {
                case FIFO_EMPTY_TRIGGER:
                    return tx_fifo.is_empty();
                case FIFO_2_CHAR_TRIGGER:
                    return tx_fifo.len() <= 2;
                case FIFO_QUARTER_FULL:
                    return tx_fifo.len() <= (FIFO_MODE.val / 4);
                case FIFO_HALF:
                    return tx_fifo.len() <= (FIFO_MODE.val / 2);
                default:
                    assert(false);
            }
        }
    }
    
    field XFIFOR @ [2] is (write) "XMIT FIFO Reset" {
        method write(uint64 value) {
            if (value == 1) {
                tx_fifo.clear();
                irq_dev.update();
                dmac_transmit.hard_reset();
            }
        }
    }
    
    field RFIFOR @ [1] is (write) "RCVR FIFO Reset" {
        method write(uint64 value) {
            if (value == 1) {
                rx_fifo.clear();
                irq_dev.update();
                dmac_receive.hard_reset();
            }
        }
    }
    
    field FIFOE @ [0] is (write) "FIFO Enable" {
        method write(uint64 value) {
            default(value);
            irq_dev.update();
            update_dmac_transmit();
            update_dmac_receive();
        }
    }
}
```

**FIFO Status Registers:**

```dml
register TFL is (optional_register) {
    field TFL @ [31:0] is (read, read_only, get) "Number data entries in tx FIFO" {
        method get() -> (uint64) {
            return tx_fifo.len();
        }
    }
}

register RFL is (optional_register) {
    field RFL @ [31:0] is (read, read_only, get) "Number data entries in rx FIFO" {
        method get() -> (uint64) {
            return rx_fifo.len();
        }
    }
}
```

#### 4. Interrupt Generation Logic

The UART generates interrupts for various conditions, prioritized and managed through interrupt identification.

**Interrupt Identification Register:**

```dml
register IIR is (read_only) {
    field IID @ [3:0] is (read, get, hard_reset) "Interrupt ID" {
        param MODEM_STATUS = 0x0;
        param NO_INTERRUPT = 0x1;
        param THR_EMPTY = 0x2;
        param RX_DATA_AVAILABLE = 0x4;
        param RX_LINE_STATUS = 0x6;
        param BUSY_DETECT = 0x7;
        param CHAR_TIMEOUT = 0xc;
        
        method read() -> (uint64) {
            local uint64 iid = this.get();
            // Reading THR_EMPTY interrupt acknowledges it
            if (iid == THR_EMPTY) {
                IER.ack_threshold();
                irq_dev.update();
            }
            return iid;
        }
        
        method get() -> (uint64) {
            // Interrupt priority (highest to lowest)
            if (IER.line_status_irq()) {
                return RX_LINE_STATUS;
            } else if (IER.rx_data_irq()) {
                return RX_DATA_AVAILABLE;
            } else if (rx_fifo.char_timeout.occurred) {
                return CHAR_TIMEOUT;
            } else if (IER.thre_status_irq()) {
                return THR_EMPTY;
            } else if (IER.modem_status_irq()) {
                return MODEM_STATUS;
            } else if (USR.BUSY.detected) {
                return BUSY_DETECT;
            } else {
                return NO_INTERRUPT;
            }
        }
        
        method is_active() -> (bool) {
            return this.get() != NO_INTERRUPT;
        }
    }
}
```

**Interrupt Enable Register:**

```dml
register IER {
    field PTIME @ [7] is (optional_rw_field) "Programmable THRE Interrupt Mode Enable";
    field EDSSI @ [3] "Enable Modem Status Interrupt";
    field ELSI @ [2] "Enable Receiver Line Status Interrupt";
    field ETBEI @ [1] "Enable Transmit Holding Register Empty Interrupt";
    field ERBFI @ [0] "Enable Received Data Available Interrupt";
    
    method line_status_irq() -> (bool) {
        return (ELSI.val &&
               (LSR.BI.val || LSR.FE.val || LSR.PE.val || LSR.OE.val));
    }
    
    method rx_data_irq() -> (bool) {
        return ERBFI.val && FCR.RT.above_threshold();
    }
    
    method thre_status_irq() -> (bool) {
        if (!ETBEI.val)
            return false;
        
        if (PTIME.val && THRE_MODE_USER.val) {
            // Programmable THRE mode
            return FCR.TET.below_threshold();
        } else {
            // Standard mode: interrupt when THR empty
            return THR.is_empty();
        }
    }
    
    method modem_status_irq() -> (bool) {
        return (EDSSI.val && 
               (MSR.DCTS.val || MSR.DDSR.val || 
                MSR.TERI.val || MSR.DDCD.val));
    }
}
```

**Interrupt Connection:**

```dml
connect irq_dev {
    interface signal;
    param documentation = "Interrupt signal to interrupt controller";
    
    method update() {
        if (this.obj) {
            if (IIR.IID.is_active())
                signal.signal_raise();
            else
                signal.signal_lower();
        }
    }
}
```

#### 5. Line Status Logic

Line status tracks the state of the UART data path and error conditions.

**Line Status Register:**

```dml
register LSR is (read_only, hard_reset) {
    field RFE @ [7] "Receiver FIFO Error" {
        is optional_ro_field;
        param exists = FIFO_MODE.val != 0;
    }
    
    field TEMT @ [6] is (get) "Transmitter Empty" {
        method get() -> (uint64) {
            return (THR.is_empty() && !transfer.posted) ? 1 : 0;
        }
    }
    
    field THRE @ [5] is (get) "Transmit Holding Register Empty" {
        method get() -> (uint64) {
            return THR.is_empty() ? 1 : 0;
        }
    }
    
    field BI @ [4] "Break Interrupt";
    field FE @ [3] "Framing Error";
    field PE @ [2] "Parity Error";
    field OE @ [1] "Overrun Error";
    
    field DR @ [0] is (get) "Data Ready" {
        method get() -> (uint64) {
            return RBR.is_empty() ? 0 : 1;
        }
    }
}
```

#### 6. Register Overlaying Logic

Some registers share the same address, selected by the DLAB (Divisor Latch Access Bit).

**Overlaid Register Access:**

```dml
register RBR_DLL_THR {
    param configuration = "none";
    
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        if (LCR.DLAB.val)
            DLL.write_register(value, enabled_bytes, aux);
        else
            THR.write_register(value, enabled_bytes, aux);
    }
    
    method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
        if (LCR.DLAB.val)
            return DLL.read_register(enabled_bytes, aux);
        else
            return RBR.read_register(enabled_bytes, aux);
    }
}

register DLH_IER {
    param configuration = "none";
    
    method write_register(uint64 value, uint64 enabled_bytes, void *aux) {
        if (LCR.DLAB.val)
            DLH.write_register(value, enabled_bytes, aux);
        else
            IER.write_register(value, enabled_bytes, aux);
    }
    
    method read_register(uint64 enabled_bytes, void *aux) -> (uint64) {
        if (LCR.DLAB.val)
            return DLH.read_register(enabled_bytes, aux);
        else
            return IER.read_register(enabled_bytes, aux);
    }
}
```

### Summary

The UART peripheral implements several key patterns:

1. **Dual-Mode Buffering**: Supports both single-register and FIFO modes for transmit and receive
2. **Baud Rate Timing**: Optionally simulates character transmission delay based on baud rate
3. **Interrupt Priority**: Implements standard UART interrupt priority scheme
4. **FIFO Thresholds**: Configurable thresholds trigger interrupts and DMA requests
5. **Error Detection**: Tracks parity, framing, overrun, and break errors
6. **Register Overlaying**: Shares register addresses using DLAB bit for compatibility
7. **Loopback Mode**: Supports internal loopback for testing
8. **DMA Support**: Integrates with DMA controllers for efficient data transfer

The implementation demonstrates efficient UART modeling with:
- Event-based character transmission (not cycle-accurate)
- On-demand status calculation
- Proper interrupt handling and priority
- FIFO management with threshold detection
- Serial device interface integration

