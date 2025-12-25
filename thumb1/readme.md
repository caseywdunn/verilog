# thumb1 — Minimal Thumb-1–like Core (Verilog)

This project implements a small, multi-cycle Thumb-1–like CPU core in
Verilog/SystemVerilog. It is intended as a hands-on learning project for
ARM architecture, instruction decoding, flag behavior, and basic CPU
microarchitecture.

The design is deliberately simple, explicit, and debuggable rather than
fast or complete.

------------------------------------------------------------------------------

## Directory Layout (Current)

thumb1/
├── core/
│   ├── tiny_thumb_core.sv     CPU core
│   ├── tiny_mem_model.sv      Unified instruction/data memory model
│   ├── tb.sv                  Self-checking testbench
│   └── README.md              This file
│
├── tests/
│   ├── add_store/
│   │   └── prog.hex           Basic arithmetic + store test
│   ├── cmp_loop/
│   │   └── prog.hex           CMP + conditional branch loop test
│   └── ldr_literal/
│       └── (reserved)
│
├── prog.hex                   Symlink to the active test program
├── sim.out                    Simulator binary (generated)
└── dump.vcd                   Waveform output (generated)

Exactly ONE program image (prog.hex) is executed per simulation run.

------------------------------------------------------------------------------

## How Tests Are Selected and Run

Tests are selected using a symlink:

    ln -sf tests/<test-name>/prog.hex prog.hex

The CPU and memory always load "prog.hex" from the working directory.
Switching the symlink switches the test.

### Example: run the CMP + loop test

    ln -sf tests/cmp_loop/prog.hex prog.hex
    iverilog -g2012 -o sim.out core/tb.sv core/tiny_thumb_core.sv core/tiny_mem_model.sv
    vvp sim.out

Expected output:

    PASS: mem[64] (addr 00000100) = 000000a1

Only ONE prog.hex is ever executed per run. Tests are not concatenated.

------------------------------------------------------------------------------

## Testbench Behavior

The testbench (tb.sv):

- Holds reset for a few cycles
- Runs the CPU for a fixed number of cycles
- Checks a signature word written by the program
- Fails the simulation if the signature is incorrect

Current convention:

- Programs write a 32-bit signature to address 0x100
- Word index: 0x100 >> 2 = 64
- tb.sv checks mem[64] against EXPECTED_SIG

Changing tests typically requires updating EXPECTED_SIG in tb.sv
(or later, automating this per-test).

------------------------------------------------------------------------------

## FPGA Synthesis

FPGA implementation for DE10-Nano is available in the `de10nano/` directory.

See `de10nano/README.md` for complete synthesis and programming instructions.

Requirements:
- Intel Quartus Prime Lite (tested with 25.1, works with 18.0+)
- DE10-Nano board with USB Blaster connection
- Download: [Quartus Lite](https://www.intel.com/content/www/us/en/collections/products/fpga/software/downloads.html)

Quick start:
```bash
cd de10nano
make all             # Synthesize (~15 minutes)
make program-sof     # Program FPGA via JTAG
```

The design uses 8KB of block RAM and easily meets 50 MHz timing on Cyclone V.


------------------------------------------------------------------------------

## CPU Architecture Overview

### Execution model

The core is multi-cycle (not pipelined). Instructions execute over a small
finite-state machine:

  1. FETCH    Issue memory read for instruction at PC
  2. WAITI    Wait for synchronous memory read (1-cycle latency)
  3. DECODE   Decode opcode and latch operands/immediates
  4. EXEC     Perform ALU operation or compute address/branch target
  5. MEM      Issue data memory operation (LDR/STR only)
  6. WAITM    Wait for synchronous memory read on loads
  7. FETCH    Next instruction

The PC advances by 2 bytes per instruction (Thumb semantics).

Wait states (WAITI, WAITM) handle the 1-cycle read latency of synchronous
block RAM, matching real FPGA memory timing.

### Registers and flags

- Registers R0–R15 stored internally
- R15 mirrors PC for debug visibility
- Flags: N, Z, C, V
  - Updated by ADD, SUB, CMP, shifts, and logical ops as implemented

------------------------------------------------------------------------------

## Memory Model (Important)

tiny_mem_model.sv currently implements:

- Unified instruction + data memory
- **Synchronous reads** (1-cycle latency)
- Synchronous writes with byte strobes
- Proper ready/valid handshake protocol

This models real FPGA block RAM behavior for synthesis compatibility.

The CPU FSM includes wait states (S_WAITI, S_WAITM) to handle the 1-cycle
read latency, matching real block RAM timing behavior.

------------------------------------------------------------------------------

## Implemented Instruction Subset (Current)

The core currently supports a minimal Thumb-1–style subset sufficient for
directed bring-up tests:

Immediate ALU:
- MOVS Rd, #imm8
- ADDS Rd, #imm8
- SUBS Rd, #imm8
- CMP  Rd, #imm8

Shifts:
- LSL Rd, Rm, #imm5
- LSR Rd, Rm, #imm5

Memory (word accesses only):
- STR Rt, [Rn, #(imm5 << 2)]
- LDR Rt, [Rn, #(imm5 << 2)]
- LDR Rt, [PC, #(imm8 << 2)]   (literal load)

Branches:
- B label
- B<cond> label   (EQ, NE, MI, PL)

Optional ALU register group (enabled by parameter):
- AND, EOR, ORR, CMP (register)

------------------------------------------------------------------------------

## prog.hex File Format

prog.hex is loaded via $readmemh into a 32-bit word array.

Each line:
- 8 hex digits (one 32-bit word)
- Contains two 16-bit Thumb instructions
  - lower halfword [15:0] executes first
  - upper halfword [31:16] executes second

This matches little-endian Thumb instruction layout.

------------------------------------------------------------------------------

## Current Tests

### add_store

Purpose:
- Validate basic arithmetic
- Validate STR
- Validate PC sequencing and fetch

Behavior:
- r0 = 5 + 7 - 2 = 10
- r1 = 0x100
- store r0 to [0x100]
- halt

Expected signature:
- mem[64] = 0x0000000A

### cmp_loop

Purpose:
- Validate SUBS + CMP flag behavior
- Validate conditional branch (BNE)
- Validate backward branch offset sign extension

Behavior:
- r0 initialized to 3
- loop: r0-- ; CMP r0,#0 ; BNE loop
- on completion, write 0xA1 to [0x100]
- halt

Expected signature:
- mem[64] = 0x000000A1

------------------------------------------------------------------------------

## Current Status

- Instruction fetch/decode/execute path working
- Flags (N/Z at minimum) verified via loop test
- Conditional branching verified
- Memory stores and loads verified
- Multiple directed tests supported
- Synchronous memory model (1-cycle latency) implemented
- FPGA synthesis verified on DE10-Nano board

------------------------------------------------------------------------------

## Planned Next Steps

- LDR literal test (PC-relative addressing)
- Per-test expected signature automation
- Regression runner for all tests
- Expand instruction coverage incrementally
- Add more comprehensive test programs
- (Later) pipelining or Harvard split

------------------------------------------------------------------------------

This project is intentionally incremental. Each new instruction or feature
should be validated with a small, focused test program before proceeding.
