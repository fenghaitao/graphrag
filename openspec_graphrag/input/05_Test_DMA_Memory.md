# Test DMA and Memory Operations

## Overview

This document covers testing DMA (Direct Memory Access) operations and memory interactions in Simics device models, including memory setup, DMA verification, and descriptor-based testing.

## Table of Contents

1. [Memory Object Setup](#memory-object-setup)
2. [Basic DMA Testing](#basic-dma-testing)
3. [Descriptor-Based DMA](#descriptor-based-dma)
4. [Memory Layout Utilities](#memory-layout-utilities)
5. [Advanced DMA Patterns](#advanced-dma-patterns)
6. [Troubleshooting](#troubleshooting)

---

## Memory Object Setup

### Creating Test Memory

```python
import dev_util

# Create memory object for testing
mem = dev_util.Memory()

# Connect to device
dev.phys_mem = mem.obj  # Device will read/write this memory
```

### Memory Object Interface

```python
# Write data to memory
mem.write(address, data)

# Read data from memory
data = mem.read(address, length)

# Clear memory region
mem.write(address, [0] * length)
```

---

## Basic DMA Testing

### DMA Test Pattern

```python
import dev_util
import stest

# 1. Setup Memory
mem = dev_util.Memory()
dev.phys_mem = mem.obj

# 2. Prepare Source Data
src_addr = 0x1000
dst_addr = 0x2000
transfer_size = 256

# Create test data pattern
src_data = tuple(range(transfer_size))  # [0, 1, 2, ..., 255]

# Write source data to memory
mem.write(src_addr, src_data)

# 3. Configure DMA Transfer
regs.dma_src.write(src_addr)
regs.dma_dst.write(dst_addr)
regs.dma_len.write(transfer_size)
regs.dma_cmd.write(1)  # Start DMA

# 4. Wait for DMA Completion
simics.SIM_continue(1000)  # Give time for DMA to complete

# 5. Verify Transfer Result
dst_data = mem.read(dst_addr, transfer_size)
stest.expect_equal(list(dst_data), list(src_data), "DMA transfer mismatch")
```

### DMA Test Components

#### Component 1: Memory Preparation

```python
# Clear destination to verify write
mem.write(dst_addr, [0] * transfer_size)

# Write known pattern to source
pattern = [0xAA, 0xBB, 0xCC, 0xDD] * (transfer_size // 4)
mem.write(src_addr, pattern)
```

#### Component 2: DMA Configuration

Register names depend on your DML implementation:

```python
# Example DMA registers (adjust to match your DML)
regs.DMA_SRC_ADDR.write(src_addr)      # Source address
regs.DMA_DST_ADDR.write(dst_addr)      # Destination address  
regs.DMA_TRANSFER_SIZE.write(size)     # Transfer size in bytes
regs.DMA_CONTROL.write(0x1)            # Start bit
```

#### Component 3: Completion Detection

```python
# Method 1: Wait for status bit
simics.SIM_continue(1000)
status = regs.DMA_STATUS.read()
stest.expect_equal(status & 0x1, 1, "DMA completion bit not set")

# Method 2: Wait for interrupt (with fake PIC)
simics.SIM_continue(1000)
stest.expect_equal(fake_pic.raised, 1, "DMA completion interrupt not raised")

# Method 3: Poll until complete
max_iterations = 1000
for i in range(max_iterations):
    status = regs.DMA_STATUS.read()
    if status & 0x1:  # Done bit
        break
    simics.SIM_continue(10)
else:
    raise stest.fail("DMA did not complete within timeout")
```

#### Component 4: Result Verification

```python
# Read destination memory
result = mem.read(dst_addr, transfer_size)

# Verify exact match
stest.expect_equal(list(result), list(src_data), "DMA data mismatch")

# Verify partial match (first/last bytes)
stest.expect_equal(result[0], src_data[0], "First byte mismatch")
stest.expect_equal(result[-1], src_data[-1], "Last byte mismatch")

# Verify byte-by-byte
for i in range(transfer_size):
    stest.expect_equal(result[i], src_data[i], 
                       f"Mismatch at byte {i}")
```

---

## Descriptor-Based DMA

### Using Layout for Descriptors

DMA descriptors are memory structures that describe transfers. Use `dev_util.Layout` to map Python objects to memory.

```python
import dev_util

# Create descriptor in memory
desc_addr = 0x3000

desc = dev_util.Layout_LE(mem, desc_addr, {
    'src_addr':  (0, 4),   # Offset 0, 4 bytes
    'dst_addr':  (4, 4),   # Offset 4, 4 bytes
    'length':    (8, 4),   # Offset 8, 4 bytes
    'flags':     (12, 4),  # Offset 12, 4 bytes
    'next_desc': (16, 4)   # Offset 16, 4 bytes (chain pointer)
})
```

### Layout Syntax

```python
Layout_LE(memory_object, base_address, field_dict)
```

**Field dictionary format:**
```python
{
    'field_name': (offset, size_in_bytes)
}
```

### Descriptor-Based DMA Test

```python
import dev_util
import stest

# Setup
mem = dev_util.Memory()
dev.phys_mem = mem.obj

# Create DMA descriptor
desc_addr = 0x3000
desc = dev_util.Layout_LE(mem, desc_addr, {
    'src_addr': (0, 4),
    'dst_addr': (4, 4),
    'length':   (8, 4),
    'control':  (12, 4),
    'status':   (16, 4)
})

# Prepare test data
src_addr = 0x1000
dst_addr = 0x2000
size = 128
data = tuple(range(size))

mem.write(src_addr, data)

# Configure descriptor
desc.src_addr = src_addr
desc.dst_addr = dst_addr
desc.length = size
desc.control = 0x1  # Enable
desc.status = 0x0   # Clear status

# Start DMA with descriptor address
regs.DMA_DESC_ADDR.write(desc_addr)
regs.DMA_START.write(0x1)

# Wait for completion
simics.SIM_continue(1000)

# Verify descriptor status updated
stest.expect_equal(desc.status, 0x1, "Descriptor status not updated")

# Verify data transfer
result = mem.read(dst_addr, size)
stest.expect_equal(list(result), list(data), "DMA data mismatch")
```

### Chained Descriptors

```python
# Create descriptor chain
desc1_addr = 0x3000
desc2_addr = 0x3100

desc1 = dev_util.Layout_LE(mem, desc1_addr, {
    'src_addr': (0, 4),
    'dst_addr': (4, 4),
    'length':   (8, 4),
    'next':     (12, 4)
})

desc2 = dev_util.Layout_LE(mem, desc2_addr, {
    'src_addr': (0, 4),
    'dst_addr': (4, 4),
    'length':   (8, 4),
    'next':     (12, 4)
})

# Configure first descriptor
desc1.src_addr = 0x1000
desc1.dst_addr = 0x2000
desc1.length = 256
desc1.next = desc2_addr  # Chain to desc2

# Configure second descriptor
desc2.src_addr = 0x1100
desc2.dst_addr = 0x2100
desc2.length = 256
desc2.next = 0  # End of chain

# Start chained DMA
regs.DMA_DESC_ADDR.write(desc1_addr)
regs.DMA_START.write(0x1)

# Wait for both transfers
simics.SIM_continue(2000)

# Verify both transfers completed
result1 = mem.read(0x2000, 256)
result2 = mem.read(0x2100, 256)
# ... verify both ...
```

---

## Memory Layout Utilities

### Layout_LE vs Layout_BE

```python
# Little Endian layout (Intel, ARM)
desc_le = dev_util.Layout_LE(mem, addr, fields)

# Big Endian layout (PowerPC, some ARM modes)
desc_be = dev_util.Layout_BE(mem, addr, fields)
```

### Complex Structures

```python
# Network packet descriptor
pkt_desc = dev_util.Layout_LE(mem, 0x4000, {
    'buffer_addr':     (0, 4),      # Packet buffer address
    'length':          (4, 2),      # Packet length
    'vlan_tag':        (6, 2),      # VLAN tag
    'flags':           (8, 4),      # Control flags
    'timestamp_low':   (12, 4),     # Timestamp lower 32 bits
    'timestamp_high':  (16, 4),     # Timestamp upper 32 bits
    'checksum':        (20, 2),     # Checksum
    'status':          (22, 2),     # Status
    'next_desc':       (24, 4)      # Next descriptor pointer
})

# Access fields
pkt_desc.buffer_addr = 0x10000
pkt_desc.length = 1500
pkt_desc.vlan_tag = 0x81
pkt_desc.flags = 0x3
```

### Bit-Level Access in Layouts

For bit-level fields, use masks and shifts:

```python
# Descriptor with packed flags
desc = dev_util.Layout_LE(mem, addr, {
    'addr': (0, 4),
    'control': (4, 4)
})

# Set control field bits
ENABLE_BIT = 0x1
INTERRUPT_BIT = 0x2
CHAIN_BIT = 0x4

desc.control = ENABLE_BIT | INTERRUPT_BIT | CHAIN_BIT

# Check control bits
if desc.control & ENABLE_BIT:
    print("DMA enabled")
```

---

## Advanced DMA Patterns

### Pattern 1: Scatter-Gather DMA

```python
# Multiple source buffers to single destination
src_buffers = [0x1000, 0x2000, 0x3000]
dst_addr = 0x10000
buffer_size = 256

# Write test data to source buffers
for i, src in enumerate(src_buffers):
    data = [i] * buffer_size  # Different pattern per buffer
    mem.write(src, data)

# Create descriptor chain
for i, src in enumerate(src_buffers):
    desc_addr = 0x5000 + (i * 32)
    desc = dev_util.Layout_LE(mem, desc_addr, {
        'src': (0, 4),
        'dst': (4, 4),
        'len': (8, 4),
        'next': (12, 4)
    })
    
    desc.src = src
    desc.dst = dst_addr + (i * buffer_size)
    desc.len = buffer_size
    desc.next = desc_addr + 32 if i < len(src_buffers) - 1 else 0

# Start scatter-gather DMA
regs.DMA_DESC_ADDR.write(0x5000)
regs.DMA_START.write(0x1)

# Wait and verify
simics.SIM_continue(3000)

# Verify all buffers transferred
for i in range(len(src_buffers)):
    offset = i * buffer_size
    result = mem.read(dst_addr + offset, buffer_size)
    expected = [i] * buffer_size
    stest.expect_equal(list(result), expected, 
                       f"Buffer {i} transfer failed")
```

### Pattern 2: Bidirectional DMA Test

```python
# Test both read and write DMA
test_data = tuple(range(256))

# Test 1: Host to Device (Write)
mem.write(0x1000, test_data)
regs.DMA_SRC.write(0x1000)
regs.DMA_DST.write(0x8000)  # Device internal memory
regs.DMA_LEN.write(256)
regs.DMA_DIR.write(0)  # Host -> Device
regs.DMA_CMD.write(1)

simics.SIM_continue(1000)
# Verify via reading device memory (if accessible)

# Test 2: Device to Host (Read)
regs.DMA_SRC.write(0x8000)  # Device internal memory
regs.DMA_DST.write(0x2000)
regs.DMA_LEN.write(256)
regs.DMA_DIR.write(1)  # Device -> Host
regs.DMA_CMD.write(1)

simics.SIM_continue(1000)

result = mem.read(0x2000, 256)
stest.expect_equal(list(result), list(test_data), "Read DMA mismatch")
```

### Pattern 3: DMA with Stride

```python
# Transfer with gaps (stride)
src_addr = 0x1000
dst_addr = 0x2000
element_size = 4
stride = 16  # Gap between elements
count = 64

# Write source data (packed)
src_data = list(range(count))
for i in range(count):
    mem.write(src_addr + (i * element_size), [src_data[i]] * element_size)

# Configure strided DMA
regs.DMA_SRC.write(src_addr)
regs.DMA_DST.write(dst_addr)
regs.DMA_ELEM_SIZE.write(element_size)
regs.DMA_STRIDE.write(stride)
regs.DMA_COUNT.write(count)
regs.DMA_CMD.write(1)

simics.SIM_continue(2000)

# Verify strided destination
for i in range(count):
    result = mem.read(dst_addr + (i * stride), element_size)
    expected = [src_data[i]] * element_size
    stest.expect_equal(list(result), expected, f"Element {i} mismatch")
```

---

## Troubleshooting

### Problem: Memory Read Returns Wrong Data

**Symptom:** `mem.read()` returns different data than written

**Fix:** Check address alignment and endianness

```python
# Ensure address is aligned
addr = 0x1000  # ✅ Aligned to 4 bytes
# addr = 0x1001  # ❌ Misaligned

# Use correct endianness
desc = dev_util.Layout_LE(mem, addr, fields)  # For LE devices
# desc = dev_util.Layout_BE(mem, addr, fields)  # For BE devices
```

### Problem: DMA Transfer Incomplete

**Symptom:** Only partial data transferred

**Fix:** Check transfer size and wait time

```python
# Verify size matches
src_size = len(src_data)
regs.DMA_LEN.write(src_size)  # ✅ Match data size

# Wait long enough
simics.SIM_continue(1000)  # May need more steps/cycles for large transfers
```

### Problem: Descriptor Not Updated

**Symptom:** Descriptor status field stays 0

**Fix:** Verify device writes to descriptor memory

```python
# Check device has memory access
dev.phys_mem = mem.obj  # ✅ Required for device to write memory

# Check descriptor address is correct
print(f"Descriptor at: 0x{desc_addr:x}")
regs.DMA_DESC_ADDR.write(desc_addr)
```

---

## Complete DMA Test Example

```python
import simics
import conf
import dev_util
import stest

# Configuration
def create_config():
    dev = simics.pre_conf_object('dut', 'dma_device')
    clk = simics.pre_conf_object('clk', 'clock')
    clk.freq_mhz = 100
    dev.queue = clk
    
    simics.SIM_add_configuration([dev, clk], None)
    return conf.dut

# Setup
device = create_config()
regs = dev_util.bank_regs(device.bank.regs)

# Create memory
mem = dev_util.Memory()
device.phys_mem = mem.obj

# Test data
src_addr = 0x1000
dst_addr = 0x2000
size = 512
test_data = tuple(range(size))

# Write source
mem.write(src_addr, test_data)

# Clear destination
mem.write(dst_addr, [0] * size)

# Configure DMA
regs.DMA_SRC_ADDR.write(src_addr)
regs.DMA_DST_ADDR.write(dst_addr)
regs.DMA_TRANSFER_SIZE.write(size)
regs.DMA_CONTROL.write(0x1)  # Start

# Wait for completion
simics.SIM_continue(2000)

# Verify status
status = regs.DMA_STATUS.read()
stest.expect_equal(status & 0x1, 1, "DMA not complete")

# Verify transfer
result = mem.read(dst_addr, size)
stest.expect_equal(list(result), list(test_data), "DMA transfer failed")

print("DMA test passed!")
```

---

## Best Practices

### ✅ DO:

1. **Use dev_util.Memory()** for test memory objects
2. **Clear destination** before DMA to verify write
3. **Wait sufficient time** for DMA completion
4. **Verify status bits** indicate completion
5. **Use Layout** for complex descriptors
6. **Test boundary conditions** (size 0, max size)
7. **Test error cases** (invalid addresses, misalignment)

### ❌ DON'T:

1. **Don't assume immediate completion** - always wait with SIM_continue
2. **Don't forget to connect memory** - set `dev.phys_mem = mem.obj`
3. **Don't use real addresses** - use test addresses like 0x1000, 0x2000
4. **Don't test without verification** - check data matches
5. **Don't ignore alignment** - respect device alignment requirements
6. **Don't test only happy path** - test errors too

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Next Reading**: [06_Test_Events_Timing.md](06_Test_Events_Timing.md)
