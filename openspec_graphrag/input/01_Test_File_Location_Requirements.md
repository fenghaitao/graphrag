# Test File Location Requirements

## ⚠️ CRITICAL: Read This First

**ALL test files MUST be created in the correct location or they will not be found by Simics test-runner.**

## ✅ CORRECT Test Location

**The ONLY correct location for Simics device model tests:**

```
simics-project/                    # ✅ Correct: hyphen (Simics project directory)
└── modules/<device>/test/
    ├── SUITEINFO
    ├── README
    ├── common.py                  # ✅ Shared configuration
    ├── s-<feature1>.py            # ✅ Individual test files
    ├── s-<feature2>.py
    └── CMakeLists.txt             # Auto-generated, not necessary to create manually
```

### Real Example

```
simics-project/
└── modules/
    └── sample-timer-device/
        ├── sample-timer.dml       # DML device implementation
        ├── module_load.py         # Module initialization
        ├── Makefile               # Build configuration (either Makefile OR CMakeLists.txt)
        ├── CMakeLists.txt         # CMake build configuration (alternative to Makefile)
        └── test/                  # ✅ Test directory here
            ├── SUITEINFO
            ├── README
            ├── common.py
            ├── s-basic-ops.py
            ├── s-timer-expiry.py
            └── CMakeLists.txt     # Auto-generated, not necessary to create manually
```

## ❌ FORBIDDEN Test Locations

**NEVER create tests in these locations:**

### Wrong #1: Underscore Directory (Python Package)

```
simics_project/                    # ❌ FORBIDDEN: underscore (Python package)
simics_project/modules/
simics_project/__init__.py         # ❌ NO Python package markers
simics_project/modules/<device>/test/  # ❌ WRONG location!
```

**Why it's wrong:**
- `simics_project` with underscore is a Python package naming convention
- Simics expects `simics-project` with hyphen as the project directory
- Test-runner will not find tests in underscore directories

### Wrong #2: Project Root Test Directory

```
test/                              # ❌ FORBIDDEN: project root
tests/                             # ❌ FORBIDDEN: project root
<device>_test/                     # ❌ FORBIDDEN: standalone test dir
```

**Why it's wrong:**
- Tests must be co-located with device modules
- Simics test discovery expects `modules/<device>/test/` structure
- Root-level test directories are ignored by test-runner

### Wrong #3: Incorrect Module Structure

```
simics-project/
└── <device>/test/                 # ❌ Missing "modules/" directory
    └── s-test.py

simics-project/
└── modules/<device>/
    ├── test_*.py                  # ❌ Tests in module root, not test/ directory
    └── *_test.py                  # ❌ Wrong naming and location
```

**Why it's wrong:**
- Must have `modules/` directory between project root and device
- Tests must be in dedicated `test/` subdirectory
- Simics test-runner expects specific directory hierarchy

## Why This Matters

### 1. Simics Test Execution Model

Tests run within the Simics runtime environment, not as standalone Python scripts.

```bash
# ✅ CORRECT: Run via Simics test-runner (official method)
cd simics-project
./bin/test-runner --suite modules/<device>/test

# ✅ ALSO OK: Run as standalone test (for quick testing)
cd simics-project
./simics -no-gui -no-win -batch-mode modules/<device>/test/s-test.py
```

### 2. Real Simics Imports

Tests import actual Simics APIs that only exist within the Simics environment:

```python
import simics        # Simics core API
import conf          # Configuration objects
import dev_util      # Device utilities
import stest         # Test assertions
import pyobj         # Python object framework
```

These modules are **not** available in standard Python - they require Simics runtime.

### 3. Test Discovery

Simics test-runner automatically discovers tests using:
- `SUITEINFO` file marks directory as test suite
- `s-*.py` naming pattern for test files
- `modules/<device>/test/` location requirement

## Required Files in Test Directory

### SUITEINFO (Required)

```bash
# Usually empty, but marks directory as test suite
touch SUITEINFO
```

Can optionally contain configuration:
```
# SUITEINFO with configuration
timeout = 300
disabled = false
```

### README (Recommended)

```
# README
This test suite covers the sample-timer-device module.

Coverage:
- Basic register read/write operations
- Timer start/stop functionality
- Timer expiry and interrupt generation
- DMA operations

Known omissions:
- Clock frequency scaling (not yet implemented in device)
```

### common.py (Recommended for Shared Code)

```python
# common.py
import simics
import conf
import dev_util
import pyobj

# Shared configuration setup
def create_config():
    # ... configuration code ...
    return (conf.device, conf.clock)

# Fake objects
class FakePic(pyobj.ConfObject):
    # ... fake object definition ...
    pass
```

### s-*.py (Test Files)

Test files follow the `s-*.py` naming pattern for auto-discovery. You can write tests in two patterns:

**Pattern 1: Direct Execution (Simplest)**
```python
# s-basic-ops.py
import simics
import dev_util
import stest
from common import create_config

(dut, clk) = create_config()
regs = dev_util.bank_regs(dut.bank.regs)

# Test code executes immediately
regs.control.write(0x1)
stest.expect_equal(regs.control.read(), 0x1, "Control register mismatch")
```

**Pattern 2: Function Wrapper (⚠️ MUST Call Function!)**
```python
# s-interrupts.py
import simics
import dev_util
import stest
from common import create_config

def test_interrupts():
    (dut, clk, pic) = create_config()
    regs = dev_util.bank_regs(dut.bank.regs)
    
    # Test interrupt generation
    regs.trigger_irq.write(0x1)
    stest.expect_equal(pic.raised, 1, "Interrupt not raised")

# ⚠️ CRITICAL: Must call the function!
if __name__ == "__main__":
    test_interrupts()
```

**❌ Common Mistake: Defining But Not Calling**
```python
# ❌ WRONG - Test NEVER runs (silent failure):
def test_feature():
    device = create_config()
    regs.control.write(0x1)
    # File ends - test_feature() is NEVER called!

# ✅ CORRECT - Actually execute the test:
def test_feature():
    device = create_config()
    regs.control.write(0x1)

test_feature()  # ✅ Call the function!
```

## Running Tests

### Method 1: Official Test Runner (Recommended)

```bash
cd simics-project

# Run entire test suite
./bin/test-runner --suite modules/<device>/test

# Run specific test
./bin/test-runner --suite modules/<device>/test --test s-basic-ops

# Run with verbose output
./bin/test-runner --suite modules/<device>/test -v

# List available tests
./bin/test-runner --suite modules/<device>/test --list
```

### Method 2: Direct Simics Execution (Quick Testing)

```bash
cd simics-project

# Run single test file
./simics -no-gui -no-win -batch-mode modules/<device>/test/s-basic-ops.py

# Run with output
./simics -batch-mode modules/<device>/test/s-basic-ops.py
```

### Method 3: CMake/CTest Integration

```bash
cd simics-project/build

# Run via CMake test target
cmake --build . --target test

# Or via ctest
ctest -R sample-timer-device
```

## Validation After Test Creation

### Check Test Location

```bash
# Verify tests in correct location
ls -1 simics-project/modules/*/test/s-*.py | wc -l  # Should be > 0

# Verify no forbidden directories exist
if [ -d simics_project ]; then
    echo "❌ ERROR: Forbidden simics_project/ directory found!"
    echo "Tests must be in simics-project/ not simics_project/"
    exit 1
fi
```

### Verify Test Discovery

```bash
cd simics-project

# List all discovered tests
./bin/test-runner --list | grep "<device>"

# Should show:
# modules/<device>/test/s-basic-ops
# modules/<device>/test/s-timer-expiry
# ...
```

### Test Quick Smoke Test

```bash
cd simics-project

# Run one test to verify it works
./bin/test-runner --suite modules/<device>/test --test s-basic-ops

# Should see:
# Running test: s-basic-ops
# Test s-basic-ops: PASSED
```

## Common Location Errors and Fixes

### Error: "No such test suite"

```bash
$ ./bin/test-runner --suite modules/my-device/test
Error: No such test suite: modules/my-device/test
```

**Fix:**
1. Check SUITEINFO file exists: `ls modules/my-device/test/SUITEINFO`
2. Verify location: `pwd` should be in `simics-project/`
3. Check directory name uses hyphens, not underscores

### Error: "No tests found"

```bash
$ ./bin/test-runner --suite modules/my-device/test
Test suite: modules/my-device/test
No tests found
```

**Fix:**
1. Check test files use `s-*.py` naming: `ls modules/my-device/test/s-*.py`
2. Verify files are Python scripts, not directories
3. Ensure files have executable logic (not just function definitions)

### Error: Module import failure

```python
ImportError: No module named 'simics'
```

**Fix:**
1. Must run via `./simics` or `./bin/test-runner`, not `python s-test.py`
2. Simics APIs only available in Simics runtime environment

## Best Practices

### ✅ DO:

1. **Always use hyphen** in directory names: `simics-project`
2. **Follow module structure**: `modules/<device>/test/`
3. **Use s-*.py naming** for auto-discovery
4. **Create SUITEINFO** to mark test suite
5. **Run via test-runner** for official testing
6. **Keep tests co-located** with device modules

### ❌ DON'T:

1. **Don't use underscores** in project directory: `simics_project`
2. **Don't create test/** at project root
3. **Don't use test_*.py** or *_test.py naming
4. **Don't run tests with python** command directly
5. **Don't forget SUITEINFO** file
6. **Don't separate tests** from device modules

## Quick Reference

| Requirement | Correct Value |
|-------------|---------------|
| Project directory | `simics-project/` (hyphen) |
| Test location | `simics-project/modules/<device>/test/` |
| Test naming | `s-<feature>.py` |
| Suite marker | `SUITEINFO` file in test/ |
| Run command | `./bin/test-runner --suite modules/<device>/test` |

---

**Document Status**: ✅ Complete  
**Extracted From**: Test_Best_Practices.md  
**Last Updated**: December 11, 2025  
**Next Reading**: [02_Test_Configuration_Setup.md](02_Test_Configuration_Setup.md)
