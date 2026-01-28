# Simics Modeling Philosophy

## Overview

This document describes the core principles and philosophy behind modeling devices in Simics, focusing on the transaction-level modeling approach and what makes an effective Simics device model.

## Transaction-Level Device Modeling (TLM)

In Transaction-Level Device Modeling (TLM), each interaction with a device, typically, a processor reading from or writing to the registers of the devices, is handled at once: the device is presented with a request, computes the reply, and returns it in a single function call. This is far more efficient and easier to program than modeling the details of how bits and bytes are moved across interconnects, cycle-by-cycle.

In general, immediate non-pipelined completion of an operation is sufficient for modeling device's behavior. When the device driver expects a delay, that delay must be modeled, however the specific action or activity that leads to the delay does not need to be modeled. A classic example is a device that uses a hardware interrupt to signal command completion. The driver expects to be able to run code to prepare for the interrupt after writing the command to the device. In a transactional model, the device model must include a delay between the completion of the command and the interrupt signaling the completion to the system. In this manner, the device local effects of a transaction are computed immediately, but notification of completion is deferred until the proper time has elapsed.

Transaction-level models are typically implemented using the DML tool. DML provides a C-like programming language designed specifically for this type of modeling. Although device models can be written directly in C, using DML reduces development time and makes the code more readable and maintainable, and reduces the risk of making errors.

## Simics High Level Modeling Approach

Simics models take a functional approach to modeling where entire transactions are handled in a single function.

- Models should focus on the what instead of the how.
  - Model details are optimized for the software that will run on those models. Details that are irrelevant to software execution do not need to be modeled.
  - Explicit pre-defined device states can be easily provided to the software.
- Models should be incrementally created to support different phases of the product development life cycle.
  - Initial model provides just enough emulation in order for the firmware team to begin their efforts.
- Functional models can be quickly created and connected together like building blocks.
  - The system configuration is separate from device models.

## Do Not Model Unnecessary Detail

It is easy to fall into the trap of modeling detailed aspects of the hardware that are invisible to the software. The overhead of modeling this detail can significantly slow the simulation. A trivial example is a counter that counts down on each clock cycle and interrupts when it gets to zero. An obvious way to model this is to model the counter register and decrement it on each clock cycle until it gets to zero. Simics will waste a lot of processing resources accurately maintaining the value of the counter. But this is not necessary. The counter is only visible to the software if it is explicitly read. A much better implementation is for the model to sleep until the appropriate time to interrupt arrives. If, in the meantime, the software reads the register then a calculation will need to be done to work out what would be in the register at that point. Since this probably happens rarely, if at all, the overhead of this is minimal.

A good Simics model implements the what and not the how of device functionality, timing of the hardware can also often be simplified to make more efficient and simple device models.

## Core Principles Summary

1. **Transaction-Level, Not Cycle-Accurate**: Handle entire operations in single function calls
2. **Functional Over Detailed**: Model "what" happens, not "how" it happens
3. **Software-Visible Behavior Only**: Don't model hardware details invisible to software
4. **Lazy Evaluation**: Calculate values on-demand rather than updating every cycle
5. **Incremental Development**: Build models iteratively to support different development phases
6. **Modular Design**: Create functional models as building blocks that can be connected

---

**Document Status**: ✅ Complete  
**Extracted From**: DML_Best_Practices.md  
**Last Updated**: December 11, 2025
