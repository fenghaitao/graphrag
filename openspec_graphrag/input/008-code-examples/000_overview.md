# DML 1.4 Device Model Examples - Overview

This document provides an overview of real-world DML 1.4 device implementations extracted from production Simics device models. These examples demonstrate proven patterns and best practices for implementing common device types in DML 1.4.

## Purpose and Value

This collection serves as a **practical reference library** for DML device development:

- **Real Production Code**: All examples are extracted from actual Simics device models, not synthetic tutorials
- **Proven Patterns**: Shows how experienced developers implement common device features
- **Complete Context**: Includes device declarations, register banks, interfaces, timing, and error handling
- **Category Organization**: Grouped by device type for easy navigation to relevant examples
- **Implementation Details**: Demonstrates DML syntax, idioms, and architectural patterns in action

**When to Use**: Reference these examples when implementing specific device features, understanding DML patterns, or validating your implementation approach against production code.

**How to Use**: 
1. Identify your device category (DMA, Timer, UART, etc.)
2. Review the relevant category document for similar devices
3. Study the implementation patterns for features you need
4. Adapt the patterns to your specific device requirements
5. Cross-reference with DML Best Practices documents for principles and anti-patterns

## Timer Devices

**Documentation:** [008_timer.md](008_timer.md)

Timer devices provide time-based interrupts and watchdog functionality. They typically include countdown timers, PWM generation, and interrupt generation.

**Production Devices**: Synopsys APB Timers, Synopsys APB Watchdog, RISC-V Timer, ARM Generic Timer, ARM SBSA Watchdog

**Key Features**:
- Configurable timer resolution and count values
- Interrupt generation on timeout
- PWM output with configurable duty cycle
- Multiple independent timer channels
- Watchdog functionality with reset generation
- Free-running clock sources

**Implementation Highlights**:
- Lazy evaluation patterns for efficient counting
- Event-based timeout handling
- PWM frequency interface with update notifications
- Countdown and count-up modes
- Timer chaining and cascading

---

## UART Devices

**Documentation:** [009_uart.md](009_uart.md)

UART (Universal Asynchronous Receiver/Transmitter) devices handle serial communication. They manage data transmission, FIFOs, and various communication protocols.

**Production Devices**: Synopsys APB UART, ARM PL011 UART

**Key Features**:
- Configurable baud rate and data format
- TX/RX FIFOs with programmable thresholds
- Interrupt generation for various events (RX data available, TX empty, errors)
- DMA support for efficient data transfer
- Modem control signals (CTS, RTS, DTR, DSR)
- Error detection (parity, framing, overrun, break)

**Implementation Highlights**:
- Serial interface implementations
- FIFO management with threshold interrupts
- Overlaid register support for compatibility modes
- Baud rate calculation and timing
- Line status and error reporting

---

## Interrupt Controller Devices

**Documentation:** [002_interrupt_controller.md](002_interrupt_controller.md)

Interrupt controllers manage and route interrupt signals from peripheral devices to processors. They provide priority management, masking, and distribution capabilities.

**Production Devices**: RISC-V CLINT (Core-Level Interrupt Controller)

**Key Features**:
- Multiple interrupt sources and targets
- Priority-based interrupt handling
- Interrupt masking and enabling
- Support for edge and level triggered interrupts
- Software and timer interrupts
- Multi-HART (hardware thread) support

**Implementation Highlights**:
- Signal interface connections for interrupt lines
- Memory-mapped interrupt pending/enable registers
- Timer comparison for timer interrupts
- Signal raise/lower methods for interrupt delivery

---

## DMA Controller Devices

**Documentation:** [001_dma.md](001_dma.md)

DMA (Direct Memory Access) controllers enable peripheral devices to transfer data directly to/from memory without CPU intervention, improving system performance.

**Production Devices**: Synopsys AHB DMAC, educational DMA examples

**Key Features**:
- Multiple independent DMA channels
- Configurable source and destination addresses
- Support for various transfer modes (memory-to-memory, memory-to-peripheral)
- Interrupt generation on transfer completion
- Hardware and software handshaking
- Linked list and scatter/gather support

**Implementation Highlights**:
- Physical memory interface connections
- Channel management and descriptor processing
- Transfer state machines
- Error handling and status reporting

---

## PCIe Devices

**Documentation:** [004_pcie.md](004_pcie.md)

PCIe (PCI Express) devices implement the PCIe protocol for high-speed peripheral connectivity. They handle configuration space, BAR mapping, and MSI/MSI-X interrupts.

**Production Devices**: Test PCIe device with multiple capabilities, Synopsys PCIe Endpoint Wrapper, educational PCIe samples

**Key Features**:
- PCIe configuration space with capability structures
- Base Address Registers (BARs) for memory mapping
- MSI/MSI-X interrupt support
- Advanced features like SR-IOV and ATS
- Power management capabilities
- Express capability structure

**Implementation Highlights**:
- PCI common library integration (`pci/common.dml`)
- PCIe capability chain implementation
- MSI-X table and PBA (Pending Bit Array) management
- BAR allocation and memory space mapping
- Configuration space register handling

---

## MMU/IOMMU Devices

**Documentation:** [003_mmu.md](003_mmu.md)

MMU (Memory Management Unit) and IOMMU devices provide address translation and memory protection. They enable virtual memory and secure DMA operations.

**Production Devices**: ARM SMMU-v3, ARM MMU-600, ARM MMU-700, ARM SMMU translate interface

**Key Features**:
- Multi-level page table walking
- Address translation caching (TLB)
- Access permission checking
- Fault handling and reporting
- Stream ID and context management
- Translation request/response queuing

**Implementation Highlights**:
- Memory-space interface for translated accesses
- Transaction-based translation pipeline
- TLB cache management per Translation Buffer Unit (TBU)
- Command queue processing
- Fault recording and interrupt generation

---

## I2C Devices

**Documentation:** [006_i2c.md](006_i2c.md)

I2C devices implement the I2C protocol for communication between integrated circuits. They manage bus arbitration, addressing, and data transfer.

**Key Features:**
- Master and slave/target mode support
- Configurable bus speed and timing
- Address management and bus arbitration
- FIFO support for buffering data

**Example Implementation:**
```dml
device synopsys_apb_i2c;
```

---

## I3C Devices

**Documentation:** [007_i3c.md](007_i3c.md)

I3C devices implement the I3C protocol, an evolution of I2C with higher speeds and additional features for modern SoC designs.

**Key Features:**
- Backward compatible with I2C
- Higher data transfer rates
- In-band interrupts
- Hot-join capability

---

## TRNG Devices

**Documentation:** [005_trng.md](005_trng.md)

TRNG (True Random Number Generator) devices provide hardware-based random number generation for cryptographic and security applications.

**Key Features:**
- Hardware-based entropy generation
- Cryptographically secure random numbers
- Health testing and validation

---

## I2C Devices

**Documentation:** [006_i2c.md](006_i2c.md)

I2C devices implement the I2C protocol for communication between integrated circuits. They manage bus arbitration, addressing, and data transfer.

**Production Devices**: Synopsys APB I2C, educational I2C samples, I2C-Link-v2

**Key Features**:
- Master and slave/target mode support
- Configurable bus speed and timing (standard, fast, high-speed)
- 7-bit addressing
- Address management and bus arbitration
- FIFO support for buffering data
- SMBus protocol support (Quick, Host Notify, Alert)
- Bulk transfer support

**Implementation Highlights**:
- I2C bus interface implementation
- State machine for protocol handling
- Clock stretching support
- TX/RX FIFO management
- Interrupt generation for bus events

---

## I3C Devices

**Documentation:** [007_i3c.md](007_i3c.md)

I3C devices implement the I3C protocol, an evolution of I2C with higher speeds and additional features for modern SoC designs.

**Production Devices**: Synopsys MIPI I3C Host Controller, educational I3C samples, I3C-Link

**Key Features**:
- Backward compatible with I2C
- Higher data transfer rates
- In-band interrupts (IBI)
- Hot-join capability
- Dynamic address assignment (DAA)
- Common Command Codes (CCC) - broadcast and direct
- Command and response queues
- TX/RX data buffers

**Implementation Highlights**:
- I3C bus interface with protocol state machine
- Command queue processing
- Dynamic address management
- IBI (In-Band Interrupt) handling
- Error status tracking (CRC, parity, etc.)
- Mixed I2C/I3C bus support

---

## TRNG Devices

**Documentation:** [005_trng.md](005_trng.md)

TRNG (True Random Number Generator) devices provide hardware-based random number generation for cryptographic and security applications.

**Production Devices**: Synopsys DWC TRNG NIST SP800-90C

**Key Features**:
- Hardware-based entropy generation
- Cryptographically secure random numbers
- NIST SP800-90C compliance
- Health testing and validation
- Virtual TRNG channels
- Random Byte Channel (RBC) for external devices
- Secure and non-secure address regions

**Implementation Highlights**:
- NIST core component for random number generation
- Entropy Distribution Unit (EDU) with virtual channels
- State machine for command processing
- Noise source and host-provided nonce support
- ESM (External State Machine) Nonce port
- Interrupt generation for ready/error states

---

## Common DML 1.4 Patterns

### Device Structure

All DML 1.4 devices follow this basic structure:

```dml
dml 1.4;

device device_name;
param classname = "device-name";
param desc = "Device description";

// Imports
import "utility.dml";
import "simics/devs/signal.dml";

// Attributes
attribute attr_name {
    param documentation = "Attribute description";
    param type = "i"; // integer type
}

// Banks and Registers
bank regs {
    register reg_name @ 0x00;
}

// Connect to other devices through interfaces
connect irq {
    interface signal;
}

// Interfaces for connecting by other devices
implement ethernet_common {
    method frame(const frags_t *frame, eth_frame_crc_status_t crc_status) {
        ...
    }
}
port reset {
    implement signal {
        method signal_raise() { ... }
        method signal_lower() { ... }
    }
}

// Implementation details (callbacks, side-effects)
```

## Navigation

Browse the category-specific documentation for detailed examples:

- [DMA Controllers](001_dma.md)
- [Interrupt Controllers](002_interrupt_controller.md)
- [MMU/IOMMU](003_mmu.md)
- [PCIe](004_pcie.md)
- [TRNG](005_trng.md)
- [I2C](006_i2c.md)
- [I3C](007_i3c.md)
- [Timer](008_timer.md)
- [UART](009_uart.md)
