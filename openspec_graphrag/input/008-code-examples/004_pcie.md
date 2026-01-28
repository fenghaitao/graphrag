# PCIe Devices

This document describes DML 1.4 device models in the **PCIe** category.

## Device List

- test-1-4-pci-devices (Test Device with Multiple PCIe Capabilities)
- synopsys_pcie_ep_wrapper (Synopsys PCIe Endpoint Wrapper)
- sample-pcie-device (Educational PCIe Endpoint Example)

## Key Features and DML Implementation

### test-1-4-pci-devices

Test device demonstrating various PCIe and PCI-X capabilities.

#### Device Declaration

```dml
device test_misc_device_1_4;
param desc = "tests a PCIe device";
param documentation = "A PCI Express test device";
```

#### Device Setup

```dml
import "pci/common.dml";

is pcie_device;
```

**Description:**
- Imports PCI common library with PCIe support
- Uses `pcie_device` template for full PCIe functionality

### sample-pcie-device

Educational PCIe endpoint demonstrating complete endpoint implementation with MSI-X.

#### Device Declaration

```dml
device sample_pcie_device;
param classname = "sample-pcie-device";
param desc = "sample PCIe device";
```

#### Device Parameters

```dml
param documentation = "A sample PCIe endpoint with a BAR mapped register bank"
                    + " that contains a register that when written sends an"
                    + " MSI-X interrupt after 0.1 seconds. It has 3 PCIe"
                    + " capabilities that are mandatory for an endpoint. While"
                    + " it uses MSI-X for interrupts but MSI could be used"
                    + " also/instead.";
```

#### Device Setup

```dml
import "pcie/common.dml";

is pcie_endpoint;

param pcie_version = 6.0;
```

**Description:**
- Uses `pcie_endpoint` template for endpoint-specific functionality
- PCIe version 6.0 (latest specification)
- Imports PCIe common library

### synopsys_pcie_ep_wrapper

Production-quality PCIe endpoint wrapper for attaching devices.

#### Device Declaration

```dml
device synopsys_pcie_ep_wrapper;
param classname = "synopsys-pcie-ep-wrapper";
param desc = "example endpoint PCIE wrapper";
```

#### Device Parameters

```dml
param documentation = "generic way to attach device(s) as PCIE endpoints."
                    + "<br></br>"
                    + "Features:"
                    + "<ul>"
                    + "<li>Maps device(s) internal address space(s), e.g. register bank, "
                    + "into PCIe endpoint memory space.</li>"
                    + "<li>Supports translating interrupt signal(s) into MSI interrupt(s).</li>"
                    + "<li>Automatic translation of read/write transactions into"
                    + " upstream PCIe transactions. One can for instance plug in"
                    + " device models with built in DMA.</li>"
                    + "</ul>"
                    + "Limitations:"
                    + "<ul>"
                    + "<li>BARs are fixed to 64-bit addressing.</li>"
                    + "<li>BARs are fixed to 16-bit sizing.</li>"
                    + "<li>MSI-X is not implemented.</li>"
                    + "</ul>";
```

## PCIe Config Space Implementation

### Config Space Bank Setup

The PCI configuration space is implemented using a bank with specific templates:

```dml
import "pci/common.dml";

is pcie_device;

bank pcie_config {
    // Configuration space registers defined here
}
```

**Description:**
- **pcie_device template**: Provides base PCIe functionality
- **Bank**: Mapped to configuration space address range
- **Automatic**: Many registers auto-generated from template

### Vendor and Device ID

```dml
attribute PCI_VENDOR_ID is uint64_attr {
    param desc = "Device vendor ID";
}
attribute PCI_DEVICE_ID is uint64_attr {
    param desc = "Device ID";
}
attribute PCI_CLASS_CODE is uint64_attr {
    param desc = "Class code";
}

template read_attr_value is (read, get) {
    param attr_val;
    method read() -> (uint64) {
        return attr_val;
    }
    method get() -> (uint64) {
        return read();
    }
}

bank pcie_config {
    register vendor_id is (read_attr_value) {
        param configuration = "none";
        param attr_val = PCI_VENDOR_ID.val;
    }
    register device_id is (read_attr_value) {
        param configuration = "none";
        param attr_val = PCI_DEVICE_ID.val;
    }
}
```

**Description:**
- **Attributes**: Configurable vendor, device, and class IDs
- **Read-Only Registers**: Link to attributes for configuration
- **Template Pattern**: Reusable for multiple ID registers

### Base Address Registers (BARs)

BARs map device memory and I/O regions into PCIe address space.

#### 32-bit Memory BAR

```dml
template memory_base_address_32 is (register, memory_base_address_generic) {
    param size = 4;
    field type { param init_val = 0b00; }
}
```

#### 64-bit Memory BAR

```dml
template memory_base_address_64 is (register, memory_base_address_generic) {
    param size = 8;
    field type { param init_val = 0b10; }
}
```

#### BAR Implementation (synopsys_pcie_ep_wrapper)

```dml
connect device_address_space[i < 3] is (map_target) {
    param desc = "Device application address space";
}

bank pcie_config {
    group bars [i < 3] {
        register bar @ (0x10 + (i * 8)) is (memory_base_address_64) {
            param map_obj = device_address_space[i].obj;
            param size_bits = 16;

            method read_register(uint64 bytes, void *aux) -> (uint64) {
                if (!map_obj)
                    return 0;
                else
                    return default(bytes, aux);
            }
            
            method write_register(uint64 value, uint64 bytes, void *aux) default {
                if (!map_obj)
                    return;

                default(value, bytes, aux);
            }
            
            method enabled() -> (bool) {
                return map_obj != NULL ? default() : false;
            }
        }
    }
}
```

**Description:**
- **Array of BARs**: Creates 3 64-bit BARs
- **Address Calculation**: `0x10 + (i * 8)` for standard PCIe BAR locations
- **Connection**: Links to device address spaces
- **Size**: 16-bit sizing (64KB minimum)
- **Conditional**: Only enabled if device address space connected
- **Read/Write**: Handles mapping presence checks

### Command Register

Controls PCIe device operation:

```dml
register command @ 0x04 {
    field io @ [0] "I/O Space Enable";
    field mem @ [1] "Memory Space Enable";
    field m @ [2] "Bus Master Enable";
    field sc @ [3] "Special Cycles";
    field mwi @ [4] "Memory Write and Invalidate";
    field vga @ [5] "VGA Palette Snoop";
    field pe @ [6] "Parity Error Response";
}
```

**Description:**
- **I/O Enable**: Enables I/O BAR decoding
- **Memory Enable**: Enables memory BAR decoding
- **Bus Master**: Allows device to initiate transactions
- **Other Bits**: VGA snoop, parity error handling, etc.

### Mapping Update Logic

```dml
template memory_base_address_generic is base_address {
    shared method update_mapping() default {
        remove_map();
        if (command._mem.get() != 0 && pci_mapping_enabled()) {
            this.add_map();
        }
    }

    shared method pci_mapping_base() -> (uint64) {
        local uint64 map_base;
        map_base = get_base();
        map_base <<= _base.lsb;

        if (_type.get() == 0b00)
            map_base &= 0xffffffff;
        return map_base;
    }
}
```

**Description:**
- **Dynamic Mapping**: Updates when BAR or command register changes
- **Remove/Add**: Removes old mapping before adding new
- **Enable Check**: Only maps when memory space enabled
- **Base Calculation**: Shifts base address and masks for 32/64-bit

## PCIe Memory Mapped Memory Space

### Upstream Memory Transaction Bridge

Translates device-initiated memory transactions to PCIe:

```dml
port upstream_mem "memory transaction bridge into PCIE" {
    session translation_t txl;
    
    implement transaction_translator {
        method translate(uint64 addr,
                         access_t access,
                         transaction_t *prev,
                         exception_type_t (*callback)(translation_t translation,
                                                      transaction_t *transaction,
                                                      cbdata_call_t cbdata),
                         cbdata_register_t cbdata) -> (exception_type_t) {
            if (!upstream_target.connected()) {
                log error: "Not connected to an upstream target!";
                return Sim_PE_IO_Not_Taken;
            }
            
            if (!pcie_config.command.m.val) {
                log spec_viol: "PCIe bus master not enabled,"
                             + "terminating upstream transaction!";
                return Sim_PE_IO_Not_Taken;
            }
            
            txl.target = upstream_target.map_target;

            local pcie_type_t type = ATOM_get_transaction_pcie_type(prev);
            if (type != PCIE_Type_Not_Set) {
                log error: "Expected pcie transaction type to be unset, got %s!",
                           pcie_type_name(type);
                return Sim_PE_IO_Error;
            }

            local atom_t atoms[3] = {
                ATOM_pcie_requester_id(pcie_config.get_device_id()),
                ATOM_pcie_type(PCIE_Type_Mem),
                ATOM_list_end(0),
            };

            local transaction_t t;
            t.prev = prev;
            t.atoms = atoms;
            return callback(txl, &t, cbdata);
        }
    }
}
```

**Description:**
- **Transaction Translator**: Bridges device memory accesses to PCIe
- **Bus Master Check**: Verifies bus master enabled before allowing DMA
- **Connection Check**: Ensures upstream connection present
- **PCIe Atoms**: Adds requester ID and PCIe memory type
- **Error Handling**: Returns appropriate error codes for violations

### iATU (Internal Address Translation Unit)

The iATU provides flexible address translation for PCIe transactions.

#### iATU Outbound Regions

Translates CPU address space to PCIe address space:

```dml
param PCIE_MEM      = 0b00000;
param PCIE_IO       = 0b00010;
param PCIE_CFG0     = 0b00100;
param PCIE_CFG1     = 0b00101;

group iatu_outbound[r < num_iatu_outbound_regions] {
    register ctrl_1        size 4 @ iatu_offset + 0x000 + 0x200 * r;
    register ctrl_2        size 4 @ iatu_offset + 0x004 + 0x200 * r;
    register base_addr     size 8 @ iatu_offset + 0x008 + 0x200 * r;
    register limit_addr_lo size 4 @ iatu_offset + 0x010 + 0x200 * r;
    register target_addr   size 8 @ iatu_offset + 0x014 + 0x200 * r;
    register limit_addr_hi size 4 @ iatu_offset + 0x020 + 0x200 * r;

    register ctrl_1 {
        field func_num             @ [22:20];
        field increase_region_size @ [13];
        field attr                 @ [10:9];
        field td                   @ [8];
        field tc                   @ [7:5];
        field type                 @ [4:0];
    }
    
    register ctrl_2 {
        field enable                   @ [31];
        field invert_mode              @ [29];
        field cfg_shift_mode           @ [28];
        field header_substitute_en     @ [23];
        field inhibit_payload          @ [22];
        field tlp_header_fields_bypass @ [21];
        field snp                      @ [20];
        field func_bypass              @ [19];
        field msb2bits_tag             @ [18:17];
        field tag_substitute_en        @ [16];
        field tag                      @ [15:8];
        field msg_code                 @ [7:0];
    }
}
```

**Description:**
- **Multiple Regions**: Array of translation regions
- **Type Field**: Selects Memory, I/O, or Config transactions
- **Base/Limit**: Defines source address range
- **Target**: Destination PCIe address
- **Control Fields**: Function number, traffic class, attributes
- **Enable**: Per-region enable control

#### iATU Inbound Regions

Translates PCIe address space to internal device space:

```dml
group iatu_inbound[r < num_iatu_inbound_regions] {
    register ctrl_1        size 4 @ iatu_offset + 0x100 + 0x200 * r;
    register ctrl_2        size 4 @ iatu_offset + 0x104 + 0x200 * r;
    register base_addr     size 8 @ iatu_offset + 0x108 + 0x200 * r;
    register limit_addr_lo size 4 @ iatu_offset + 0x110 + 0x200 * r;
    register target_addr   size 8 @ iatu_offset + 0x114 + 0x200 * r;
    register limit_addr_hi size 4 @ iatu_offset + 0x120 + 0x200 * r;

    register ctrl_2 {
        field enable                   @ [31];
        field match_mode               @ [30];
        field invert_mode              @ [29];
        field cfg_shift_mode           @ [28];
        field fuzzy_type_match_code    @ [27];
        field response_code            @ [25:24];
        field single_addr_loc_trans_en @ [23];
        field msg_code_match_en        @ [21];
        field func_num_match_en        @ [19];
        field attr_match_en            @ [16];
        field td_match_en              @ [15];
        field tc_match_en              @ [14];
        field msg_type_match_mode      @ [13];
        field bar_num                  @ [10:8];
        field msg_code                 @ [7:0];
    }
}
```

**Description:**
- **Match Mode**: Flexible matching criteria for incoming transactions
- **BAR Mapping**: Associates region with specific BAR
- **Match Enable**: Selective matching on function, TC, TD, attributes
- **Response Code**: Controls response for matched transactions

#### iATU Configuration

```dml
attribute atu_min_region_size is (uint64_attr) {
    param init_val default 64 * 1024;
    param documentation = "Specifies the minimum size of an address"
        + " translation region. For example, if set to 64 kB; the lower 16 bits"
        + " of the Base, Limit and Target registers are zero and all address"
        + " regions are aligned on 64 kB boundaries."
        + " (Value Range: 4k, 8k, 16k, 32k or 64k, default 64k)";
}

attribute atu_max_region_size is (uint64_attr) {
    param init_val default 32;
    param documentation = "Specifies the maximum allowable size of an"
        + " Address Translation Region in iATU for both inbound and outbound"
        + " TLPs. This parameter determines the number of programmable bits in"
        + " the iATU Upper Limit Address Register for both inbound and"
        + " outbound. (Value Range: 0(4GB) to 32(16 EB), default 0)";
}
```

**Description:**
- **Min Size**: Alignment requirement (4KB to 64KB)
- **Max Size**: Maximum region size (4GB to 16EB)
- **Configurable**: Allows hardware configuration variation

## PCIe Extension Functionality

### MSI (Message Signaled Interrupts)

Converts legacy interrupts to PCIe messages:

```dml
port device_irqs_msi[i < 32] {
    implement signal {
        method signal_raise() {
            pcie_config.msi.raise(i);
        }
        method signal_lower() {
            pcie_config.msi.lower(i);
        }
    }
}
```

**Description:**
- **Array of Ports**: Up to 32 MSI interrupt vectors
- **Signal Interface**: Compatible with standard interrupt signals
- **Automatic Translation**: Converts to PCIe MSI messages
- **Per-Vector**: Independent raise/lower for each interrupt

### Complete PCIe Endpoint Example (sample-pcie-device)

The sample-pcie-device demonstrates a complete, minimal PCIe endpoint implementation.

#### Config Space Setup

```dml
bank pcie_config {
    register device_id { param init_val = 0x1234; }
    register vendor_id { param init_val = 0x5678; }

    // BAR1 mapped to register bank
    register bar1 @ 0x18 is (memory_base_address_64) {
        param map_obj = bar_mapped_bank.obj;
        param size_bits = 14;
    }

    register capabilities_ptr { param init_val = 0x40; }
}
```

**Description:**
- **Device/Vendor IDs**: Simple initialization with param init_val
- **BAR1**: 64-bit memory BAR at offset 0x18 (not 0x10)
- **Size**: 14-bit sizing (16KB region)
- **Mapping**: Maps to bar_mapped_bank object
- **Capability Pointer**: Points to first capability at 0x40

#### Power Management Capability

```dml
is defining_pm_capability;
param pm_offset = capabilities_ptr.init_val;
param pm_next_ptr = pm_offset + 0x08;
```

**Description:**
- **Template**: Uses `defining_pm_capability` for standard PM
- **Offset**: Located at 0x40 (from capabilities_ptr)
- **Next Pointer**: Points to next capability (0x48)
- **Automatic**: Template generates all PM registers

#### MSI-X Capability Configuration

```dml
is defining_msix_capability;
param msix_offset = pm_next_ptr;
param msix_next_ptr = msix_offset + 0x0C;
param msix_num_vectors = 32;

// MSI-X table in BAR1 address space
param msix_table_offset_bir = (2 << 0) | (0x1000 << 3);
param msix_pba_offset_bir = (2 << 0) | ((0x1000 + (0x10 * msix_num_vectors)) << 3);
param msix_data_bank = msix_data;
```

**Description:**
- **Template**: Uses `defining_msix_capability` for MSI-X support
- **Offset**: Follows PM capability at 0x48
- **Vectors**: 32 MSI-X interrupt vectors
- **Table Location**: Encoded as (BAR number | offset << 3)
  - BAR 2 (which is BAR1 in 64-bit mode)
  - Offset 0x1000 in BAR space
- **PBA Location**: Pending Bit Array after the table
  - Size: 0x10 bytes per vector × 32 vectors = 0x200 bytes
  - Placed at 0x1000 + 0x200 = 0x1200
- **Data Bank**: Points to msix_data bank for table storage

#### PCIe Express Capability

```dml
is defining_exp_capability;
param exp_offset = msix_next_ptr;
param exp_next_ptr = 0x0;
param exp_dp_type = PCIE_DP_Type_EP;
```

**Description:**
- **Template**: Uses `defining_exp_capability` for PCIe Express
- **Offset**: Follows MSI-X at 0x54
- **Next Pointer**: 0x0 indicates end of capability chain
- **Device Type**: Endpoint (PCIE_DP_Type_EP)

#### BAR-Mapped Register Bank

```dml
bank bar_mapped_bank {
    register hello_world size 2 @ 0x0;

    register hello_world is write {
        param init_val = 0x1234;

        method write(uint64 value) {
            default(value);
            after 0.1s: pcie_config.msix.raise(value);
        }
    }
}
```

**Description:**
- **Bank**: Mapped through BAR1 into PCIe memory space
- **Register**: 16-bit register at offset 0x0 in BAR
- **Init Value**: 0x1234
- **Write Behavior**: 
  - Stores the written value
  - Schedules MSI-X interrupt after 0.1 seconds
  - Interrupt vector number = written value
- **Timing**: Demonstrates delayed interrupt generation

#### MSI-X Table Bank

```dml
bank msix_data is msix_table {
    param msix_bank = pcie_config;
}
```

**Description:**
- **Template**: Uses `msix_table` for MSI-X table implementation
- **Link**: References pcie_config bank for configuration
- **Automatic**: Template handles all MSI-X table operations
- **Storage**: Stores vector control, message address, and message data

#### Complete Flow Example

1. **Device Initialization**:
   - PCIe config space initialized with capabilities
   - BAR1 mapped to bar_mapped_bank
   - MSI-X table allocated in BAR1 space

2. **BAR Mapping**:
   - Host writes to BAR1 register to set base address
   - bar_mapped_bank becomes accessible at BAR1 base

3. **MSI-X Setup**:
   - Host configures MSI-X table entries (address, data, control)
   - Host enables MSI-X in capability control register

4. **Interrupt Generation**:
   - Software writes to hello_world register (e.g., value=5)
   - Device schedules interrupt after 0.1s
   - MSI-X vector 5 is raised
   - PCIe memory write generated to host with MSI-X message

**Key Features Demonstrated:**
- Complete capability chain implementation
- BAR mapping with register bank
- MSI-X configuration and usage
- Delayed interrupt generation (event-based)
- Clean separation of config space and BAR space
- Proper MSI-X table/PBA placement

### PCIe Capabilities

#### Power Management Capability

```dml
bank pm {
    param pm_offset   = 0x10;
    param pm_next_ptr = 0x90;
    is defining_pci_pm_capability;
}
```

#### PCI-X Capability

```dml
bank pcix {
    param pcix_offset   = 0x10;
    param pcix_next_ptr = 0x90;
    is defining_pci_pcix_capability;
}
```

#### PCIe Express Capability

```dml
bank max_link_with_param {
    param max_link_width = 8;

    param exp_offset   = 0x50;
    param exp_next_ptr = 0x60;
    is defining_pcie_capability_links_v5;
}
```

**Description:**
- **Capability Chain**: Linked list of capabilities via next_ptr
- **Offset Parameters**: Define location in config space
- **Templates**: Pre-defined capability structures
- **Link Width**: Configurable PCIe link width

#### Secondary PCIe Extended Capability

```dml
param spe_offset   = 0x100;
param spe_next_ptr = 0x200;
is defining_pcie_spe_capability_v5;
```

#### Physical Layer 16.0 GT/s Capability

```dml
param pl16g_offset   = 0x200;
param pl16g_next_ptr = 0x300;
param pl16g_max_lanes = 8;
is defining_pcie_pl16g_capability_v5;
```

#### Physical Layer 32.0 GT/s Capability

```dml
param pl32g_offset   = 0x300;
param pl32g_next_ptr = 0x400;
param pl32g_max_lanes = 8;
is defining_pcie_pl32g_capability_v5;
```

#### Lane Margining at Receiver Capability

```dml
param lmar_offset   = 0x400;
param lmar_next_ptr = 0x500;
param lmar_max_lanes = 8;
is defining_pcie_lmar_capability_v5;
```

#### Receiver Configuration ILC Capability

```dml
param rcilc_offset   = 0x500;
param rcilc_next_ptr = 0x0;
is defining_pcie_rcilc_capability_v5;
```

**Description:**
- **Extended Capabilities**: Located in extended config space (≥0x100)
- **Speed Support**: Supports PCIe Gen4 (16 GT/s) and Gen5 (32 GT/s)
- **Lane Configuration**: Configurable lane count
- **Capability Chain**: Linked via next_ptr (0x0 = end of chain)

### Memory Space Connections

```dml
template atu_ms is (map_target) {
    is init_as_subobj;
    interface map_demap;
    param classname = "memory-space";
}

template iatu_root_port {
    connect inbound_io is (atu_ms);
    connect inbound_mem is (atu_ms);
    connect inbound_cfg is (atu_ms);
}
```

**Description:**
- **Memory Space Objects**: Separate spaces for I/O, memory, and config
- **Map/Demap Interface**: Dynamic mapping support
- **Subobject**: Created as simulation object child

## Summary

PCIe devices in DML 1.4 implement several key patterns:

1. **Config Space**: Template-based configuration register implementation
2. **BARs**: Flexible 32/64-bit memory and I/O mapping
3. **Command Register**: Controls device decoding and bus mastering
4. **Dynamic Mapping**: Automatic BAR mapping updates
5. **Transaction Translation**: Device-to-PCIe transaction bridging
6. **iATU**: Flexible address translation for inbound/outbound
7. **MSI/MSI-X Support**: Interrupt message generation
8. **Capability Chain**: Linked list of standard and extended capabilities
9. **Multi-Speed**: Support for PCIe Gen1 through Gen6
10. **Memory Spaces**: Separate address spaces for different transaction types
11. **Event-Based Interrupts**: Delayed/scheduled interrupt generation
12. **MSI-X Table/PBA**: Proper placement in BAR space

The implementation demonstrates:
- Professional PCIe modeling following specification
- Complete endpoint implementation (sample-pcie-device)
- Flexible address translation with iATU
- Comprehensive capability support (PM, MSI-X, Express, Gen4/5)
- Efficient use of DML templates and inheritance
- Proper transaction atom handling
- Clean separation of concerns (config/memory/translation)
- BAR-mapped register banks with interrupt generation
