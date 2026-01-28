# Simics Model Test Best Practices - Master Index

## Overview

This is the master index for Simics device model testing documentation. The content has been organized into focused, independent documents to make learning and reference easier.

## Document Organization

Each document focuses on a single testing subject without mixing contexts:

### Core Documents

| Document | Focus | When to Read |
|----------|-------|--------------|
| [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md) | ⚠️ **CRITICAL** - Where to create test files, test patterns | **READ FIRST** - Before creating any test |
| [02_Test_Configuration_Setup](02_Test_Configuration_Setup.md) | Device configuration, clocks, memory mapping, common.py template | Setting up test environment |
| [03_Test_Register_Access](03_Test_Register_Access.md) | Register and field testing patterns | Testing device registers |
| [04_Test_Fake_Objects_Mocking](04_Test_Fake_Objects_Mocking.md) | Mocking interfaces and dependencies | Isolating device under test |
| [05_Test_DMA_Memory](05_Test_DMA_Memory.md) | DMA and memory testing | Testing DMA operations |
| [06_Test_Events_Timing](06_Test_Events_Timing.md) | Time-dependent behavior testing | Testing timers and events |

## Quick Navigation

### For First-Time Test Writers

**Recommended Reading Order:**
1. Start with [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md) - **CRITICAL** to avoid location errors
2. Read [02_Test_Configuration_Setup](02_Test_Configuration_Setup.md) - Learn minimal config and common.py patterns
3. Read [03_Test_Register_Access](03_Test_Register_Access.md) - Basic register testing
4. Reference others as needed (04, 05, 06) for specific features

### For Specific Testing Tasks

- **Creating test files?** → [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md)
- **Configuring device?** → [02_Test_Configuration_Setup](02_Test_Configuration_Setup.md)
- **Testing registers?** → [03_Test_Register_Access](03_Test_Register_Access.md)
- **Need to mock interfaces?** → [04_Test_Fake_Objects_Mocking](04_Test_Fake_Objects_Mocking.md)
- **Testing DMA?** → [05_Test_DMA_Memory](05_Test_DMA_Memory.md)
- **Testing timers?** → [06_Test_Events_Timing](06_Test_Events_Timing.md)
- **Need common.py template?** → [02_Test_Configuration_Setup](02_Test_Configuration_Setup.md) (see "Complete common.py Template" section)

### For Troubleshooting

Common issues and solutions:

| Problem | Document to Check |
|---------|-------------------|
| Test files not found by test-runner | [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md) |
| "Queue not set" error | [02_Test_Configuration_Setup](02_Test_Configuration_Setup.md) |
| Segfault on test run | [04_Test_Fake_Objects_Mocking](04_Test_Fake_Objects_Mocking.md) |
| Register access errors | [03_Test_Register_Access](03_Test_Register_Access.md) |
| Events don't fire | [06_Test_Events_Timing](06_Test_Events_Timing.md) |
| DMA verification fails | [05_Test_DMA_Memory](05_Test_DMA_Memory.md) |
| Test functions not executing | [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md) (see "s-*.py Test Files" section) |

## Document Dependencies

```
01_Test_File_Location_Requirements (standalone - no dependencies)
    ↓
02_Test_Configuration_Setup (requires understanding of file location)
    ↓
03_Test_Register_Access (builds on configuration)
    ↓
04_Test_Fake_Objects_Mocking (uses configuration patterns)
05_Test_DMA_Memory (uses configuration + register access)
06_Test_Events_Timing (uses configuration + register access)
```

## Best Practices Summary

### Essential Rules (Read These First)

1. ✅ **Test Location**: Tests MUST be in `simics-project/modules/<device>/test/`
2. ✅ **Clock Setup**: Set `clk.freq_mhz` BEFORE `SIM_add_configuration()`
3. ✅ **Return conf_object**: Return `conf.<name>` from `create_config()`, NOT pre-conf objects
4. ✅ **Bank Access**: Use `dev_util.bank_regs(device.bank.<bank_name>)`, read DML for exact name
5. ✅ **Call Test Functions**: If you wrap test code in a function, MUST call it at the end

### Common Anti-Patterns to Avoid

- ❌ Creating tests in `simics_project/` (underscore) instead of `simics-project/` (hyphen)
- ❌ Setting clock frequency after `SIM_add_configuration()`
- ❌ Missing `.bank.` namespace when accessing registers
- ❌ Scanning/discovering bank names dynamically instead of reading DML
- ❌ Defining test functions but forgetting to call them

## Document Status

- **Extracted From**: Test_Best_Practices.md
- **Split Date**: December 12, 2025
- **Total Documents**: 6 focused documents + this index
- **Tested With**: Simics 7.57.0, Simics Model Builder

## Using This Documentation

1. **Start here** for navigation and overview
2. **Follow recommended reading order** for first-time users
3. **Jump to specific topics** using quick navigation
4. **Use troubleshooting table** when encountering errors
5. **Reference individual documents** for deep dives into specific testing areas

---

**Next Steps**: If this is your first time writing Simics tests, start with [01_Test_File_Location_Requirements](01_Test_File_Location_Requirements.md).
