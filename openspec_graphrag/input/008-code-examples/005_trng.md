# TRNG (True Random Number Generator) Device

This document describes the DML 1.4 device model for **TRNG** (True Random Number Generator).

## Device List

- synopsys-trng (DW Synopsys TRNG NIST SP800-90C)

## Key Features and DML Implementation

### synopsys-trng

The Synopsys TRNG is a production-quality True Random Number Generator implementing NIST SP800-90C standards.

#### Device Declaration

```dml
device synopys_dwc_trng;
param classname = "synopsys-dwc-trng";
param desc = "DWC Synopsys TRNG NIST SP800-90C";
```

#### Device Parameters

```dml
param documentation = "model of DWC Synopsys TRNG NIST SP800-90C, REV 6545-002"
                    + "<br></br>"
                    + "Supported features:"
                    + "<ul>"
                    + "<li>Full support for the NIST core component (random number generation core):"
                    + "<ul>"
                    + "<li>Interrupts</li>"
                    + "<li>State machine and sequence validation</li>"
                    + "<li>Commands</li>"
                    + "<li>Noise source and host provided nonce</li>"
                    + "</ul>"
                    + "</li>"
                    + "<li>EDU is implemented and includes:"
                    + "<ul>"
                    + "<li>EDU registers</li>"
                    + "<li>Virtual TRNG channels</li>"
                    + "<li>ESM Nonce port</li>"
                    + "<li>RBC channels, which provide random data streams to external devices</li>"
                    + "</ul>"
                    + "</li>"
                    + "<li>Secure and non-secure address regions are implemented</li>"
                    + "</ul>"
                    + "Limitations:"
                    + "<ul>"
                    + "<li>Does not model the DRBG pseudo random number generator"
                    + " according to NIST SP800-90C but instead uses"
                    + " the Simics genrand library</li>"
                    + "</ul>";
```

#### Device Structure

```dml
import "utility.dml";
import "regs.dml";
import "bank-accessor-interface.dml";
import "bank-reset-storage.dml";

is hreset;

bank regs {
    is bank_accessor_interface;
    is bank_rdl_reset;
}
```

### Bank Templates Usage

The TRNG uses DML templates to organize register banks and functionality.

#### Bank Accessor Interface

```dml
bank regs {
    is bank_accessor_interface;
    is bank_rdl_reset;
}
```

**Description:**
- `bank_accessor_interface`: Provides standard bank access methods
- `bank_rdl_reset`: Implements register reset behavior based on RDL (Register Description Language) specifications

#### NIST Register Bank Template

```dml
template nist_regs is (nist_state_machine) {
    param base : uint64;
    
    // Control and status registers
    register CTRL               @ base + 0x0 "Control register to execute actions";
    register MODE               @ base + 0x4 "Enable/Disable runtime features";
    register SMODE              @ base + 0x8 "Enable/Disable mission mode runtime features";
    register STAT               @ base + 0xc "Allows user to monitor internal status";
    register IE                 @ base + 0x10 "Enable/Disable interrupts";
    register ISTAT              @ base + 0x14;
    register ALARMS             @ base + 0x18;
    
    // Information registers
    register COREKIT_REL        @ base + 0x1c "coreKit release information";
    register FEATURES           @ base + 0x20 "Buildtime parameter values";
    
    // Random data output registers
    register RAND[i < 4]        @ base + 0x24 + i * 0x4;
    
    // Personalization and seed registers
    register NPA_DATA[i < 16]   @ base + 0x34 + i * 0x4;
    register SEED[i < 12]       @ base + 0x74 + i * 0x4;
    register TIME_TO_SEED       @ base + 0xd0;
    
    // Configuration registers
    register BUILD_CFG0         @ base + 0xf0 "Build-time configuration parameters";
    register BUILD_CFG1         @ base + 0xf4 "Build-time configuration parameters";
}
```

**Description:**
- **Template Parameters**: `base` parameter allows flexible register addressing
- **Array Registers**: `RAND[i < 4]` creates 4 consecutive random data registers
- **Inheritance**: Template inherits from `nist_state_machine` for state management
- **Register Organization**: Groups registers by function (control, status, data, config)

### TRNG Function Implementation

#### 1. Entropy Generation

The core of TRNG is entropy generation using the Simics genrand library:

```dml
import "simics/util/genrand.dml";

attribute noise_seed is (range_limited_attr) {
    param documentation = "Seed for noise generator."
                        + " For cases where multiple instances of this device is present"
                        + " it is good practice to configure these with different seeds"
                        + " to avoid both sources outputting the same data.";
    param configuration = "required";
    param valid_range = [0, (1 << 32) - 1];
}

template entropy is init {
    session rand_state_t* rs;
    
    attribute total_entropy_bytes is (int64_attr) {
        param documentation = "Total number of entropy bytes generated";
    }
    
    method init() {
        genrand_reseed(0);
    }
    
    method genrand_reseed(uint64 seed) {
        if (rs)
            genrand_destroy(rs);
        rs = genrand_init(seed);
    }
    
    method generate(buffer_t buf) {
        log info, 3: "%d random bytes", buf.len;
        total_entropy_bytes.val += buf.len;

        // Generate random data word by word
        local int words = (buf.len + 3) / 4;
        for (local int i = 0; i < words; i++) {
            local uint32 v = genrand_uint32(rs);
            local int ofs = i * sizeof(v);

            // Handle partial word at end
            if ((ofs + sizeof(v)) <= buf.len)
                memcpy(&buf.data[ofs], &v, sizeof(v));
            else
                memcpy(&buf.data[ofs], &v, buf.len - ofs);
        }
    }
}
```

**Description:**
- **Random State**: Maintains `rand_state_t*` for generator state
- **Seeding**: `genrand_reseed()` initializes generator with seed
- **Generation**: `generate()` fills buffer with random bytes using `genrand_uint32()`
- **Tracking**: Counts total entropy bytes generated
- **Efficiency**: Generates 32-bit words and handles partial words at buffer end

#### 2. State Machine Control

```dml
register CTRL {
    field CMD @ [3:0] is (write, write_only) "Execute command" {
        method write(uint64 value) {
            if (STAT.BUSY.result() == 1) {
                log spec_viol, 1 then 3 :
                    "%s, Illegal write (0x%X -> [%s]) while %s is set",
                    this.qname, value, COMMANDS.to_string(value), STAT.BUSY.qname;
                return;
            }
            try_run_cmd(value);
        }
    }
}
```

**Description:**
- **Command Protection**: Prevents command execution while BUSY
- **Validation**: Checks state before accepting new commands
- **Logging**: Reports specification violations with detailed context

#### 3. Operating Mode Control

```dml
register MODE {
    field KAT_SEL @ [8:7] "Select test component for known-answer test" {
        param KAT_DRBG = 0x0;
        param KAT_DF = 0x1;
        param KAT_BOTH = 0x2;
        param init_val = KAT_BOTH;
    }
    
    field KAT_VEC @ [6:5] "Select test vectors for known answer tests" {
        param KAT_VEC0 = 0x0;
        param KAT_VEC1 = 0x1;
        param KAT_VEC2 = 0x2;
        param KAT_ALL = 0x3;
        param init_val = KAT_ALL;
    }
    
    field ADDIN_PRESENT @ [4] "Indicates availability of additional input";
    field PRED_RESIST   @ [3] "Enable/Disable prediction resistance";
    
    field SEC_ALG @ [0] "Select security strength in DRBG" {
        is (dynamic_init_val);
        param init_expr = DRBG_CONFIG_AES_256.val ? 1 : 0;
        
        method seed_bits() -> (int) {
            return this.val == 1 ? 384 : 256;
        }
    }
}
```

**Description:**
- **Known Answer Test (KAT)**: Configurable test vectors for validation
- **Security Strength**: Supports 256-bit and 384-bit modes
- **Dynamic Initialization**: `init_expr` sets value based on configuration attribute
- **Prediction Resistance**: Optional feature for enhanced security

#### 4. Mission Mode and Nonce Control

```dml
register SMODE is (post_init, rdl_reg_hard_reset) {
    field NOISE_COLLECT     @ [31]    "Enable raw noise collection mode";
    field INDIV_HT_DISABLE  @ [23:16] "Disable/Enable statistical tests individually";
    field MAX_REJECTS       @ [9:2]   "Maximum number rejections before ring tweak";
    
    field MISSION_MODE @ [1] "Sets the operating mode to TEST or MISSION" {
        is (write);

        param TEST_MODE = 0x0;
        param MISSION_MODE = 0x1;
        param IS_TEST_MODE = this.val == TEST_MODE;
        param init_val = MISSION_MODE;

        method write(uint64 value) {
            if (this.val != value) {
                SMODE.hard_reset();
                default(value);
                do_zeroize();
            }
        }
    }
    
    field NONCE @ [0] "Set the core in nonce seeding mode" {
        is write;
        method write(uint64 value) {
            if (this.val != value) {
                default(value);
                do_zeroize();
            }
        }
    }
    
    method post_init() {
        update_status_pins();
    }
    
    method update_status_pins() {
        nist.secure_mode.set_level(this.MISSION_MODE.val);
        nist.nonce_mode.set_level(this.NONCE.val);
    }
}
```

**Description:**
- **Mission Mode**: Switches between TEST and MISSION operation
- **Nonce Mode**: Enables host-provided nonce for seeding
- **Zeroization**: Clears sensitive state on mode change
- **Status Pins**: Updates external signals to reflect operating mode

#### 5. Status Monitoring

```dml
register STAT is (read_only) {
    field BUSY @ [31] "Indicates the state of the core" {
        is (computed_read_only);
        is hard_reset;
        is post_init;

        saved bool health_test_ongoing;
        
        method result() -> (uint64) {
            if (health_test_ongoing)
                return 1;
            else
                return state.ongoing ? 1 : 0;
        }
        
        method post_init() {
            if (!SIM_is_restoring_state(dev.obj))
                health_test();
        }
        
        method hard_reset() {
            default();
            health_test();
        }
        
        method health_test() {
            health_test_ongoing = true;
            if (STATE_CHANGE_TIME_NS.val > 0)
                after cast(STATE_CHANGE_TIME_NS.val, float) / 1e9 s : clear();
            else
                clear();
        }
        
        method clear() {
            health_test_ongoing = false;
        }
    }

    field STARTUP_TEST_IN_PROG @ [10] "Startup test in progress" {
        is (computed_read_only);
        method result() -> (uint64) {
            return BUSY.health_test_ongoing ? 1 : 0;
        }
    }
    
    field DRBG_STATE @ [8:7] "DRBG state is instantiated" {
        is (computed_read_only);

        param NOT_INIT = 0x0;
        param NS = 0x1;  // Built in noise source
        param HOST = 0x2;  // Host provided nonce
        
        method result() -> (uint64) {
            if (nist.DRBG.seeded) {
                return SMODE.NONCE.val ? HOST : NS;
            } else {
                return NOT_INIT;
            }
        }
    }
    
    field MISSION_MODE @ [6] is (computed_read_only) {
        method result() -> (uint64) {
            return SMODE.MISSION_MODE.val;
        }
    }
    
    field NONCE_MODE @ [5] is (computed_read_only) {
        method result() -> (uint64) {
            return SMODE.NONCE.val;
        }
    }
    
    field SEC_ALG @ [4] is (computed_read_only) {
        method result() -> (uint64) {
            return MODE.SEC_ALG.val;
        }
    }
}
```

**Description:**
- **BUSY Status**: Indicates ongoing operations (health test or state machine)
- **Health Test Simulation**: Uses event scheduling to simulate test duration
- **Computed Fields**: Status fields calculate values from other registers
- **DRBG State**: Reports initialization state (not initialized, noise source, or host nonce)
- **Mode Reflection**: Status fields mirror current operating mode

#### 6. Entropy State Serialization

```dml
attribute state {
    param internal = true;
    param type = "d";

    method set(attr_value_t val) throws {
        local bytes_t blob = { 
            .data = SIM_attr_data(val),
            .len = SIM_attr_data_size(val) 
        };

        if (!genrand_restore(rs, blob)) {
            SIM_c_attribute_error("%s attribute value is not a valid serialization", qname);
            throw;
        }
    }
    
    method get() -> (attr_value_t) {
        local bytes_t blob = genrand_serialization(rs);
        return SIM_make_attr_data_adopt(blob.len, cast(blob.data, void *));
    }
}
```

**Description:**
- **Checkpoint Support**: Serializes and restores random generator state
- **Internal Attribute**: Not exposed to user configuration
- **Error Handling**: Validates restored state before applying
- **Memory Management**: Uses `adopt` for efficient memory handling

## Summary

The TRNG device implements several key patterns:

1. **Template-Based Organization**: Uses DML templates for code reuse and organization
2. **Bank Templates**: `bank_accessor_interface` and `bank_rdl_reset` for standard behavior
3. **Entropy Generation**: Simics genrand library for random number generation
4. **State Machine**: NIST-compliant state management with validation
5. **Operating Modes**: Mission/test mode and nonce/noise source modes
6. **Health Testing**: Startup health tests with configurable timing
7. **Computed Status**: Read-only status fields calculate values dynamically
8. **Checkpoint Support**: Full serialization/deserialization of generator state
9. **Security Features**: Zeroization on mode change, prediction resistance
10. **Multi-Instance Support**: Configurable seeds for independent instances

The implementation demonstrates:
- Professional random number generation with NIST compliance
- Efficient use of DML templates and computed fields
- Proper state management and checkpointing
- Security-conscious design with mode protection and zeroization
