# thumb1 — Minimal Thumb-1–like Core (Verilog)

This project implements a small, multi-cycle Thumb-1–like CPU core in
Verilog/SystemVerilog. It is intended as a hands-on learning project for
ARM architecture, instruction decoding, flag behavior, and basic CPU
microarchitecture.

The design is deliberately simple, explicit, and debuggable rather than
fast or complete.


------------------------------------------------------------------------------

## Instruction Set

**For instruction set documentation** including encoding formats, operand details, and implementation status, see **[instructions.md](architecture.md)**.


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

Tests are selected using symlinks:

    ln -sf tests/<test-name>/prog.hex prog.hex
    ln -sf tests/<test-name>/expected.txt expected.txt

The CPU and memory load "prog.hex" from the working directory, and the
testbench loads the expected signature from "expected.txt".
Switching both symlinks switches the test.

### Example: run the CMP + loop test

    ln -sf tests/cmp_loop/prog.hex prog.hex
    ln -sf tests/cmp_loop/expected.txt expected.txt
    iverilog -g2012 -o sim.out core/tb.sv core/tiny_thumb_core.sv core/tiny_mem_model.sv
    vvp sim.out

Expected output:

    PASS: mem[64] (addr 00000100) = 000000a1

Only ONE test is executed per run. Tests are not concatenated.

### Running all tests (regression suite)

To run all tests automatically:

    ./run_tests.sh

The regression runner will:
- Build the simulation once
- Automatically run each test in tests/
- Report pass/fail status for each test
- Provide a summary with total pass/fail counts
- Exit with non-zero status if any test fails

Example output:

    ========================================
    Thumb-1 Core Regression Test Suite
    ========================================

    Building simulation...
    Build successful

    Running add_store... PASS
    Running cmp_loop... PASS
    Running ldr_literal... PASS

    ========================================
    Test Summary
    ========================================
    Passed: 3
    Failed: 0
    Total:  3

    All tests passed!

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
- tb.sv loads the expected signature from expected.txt
- Each test directory contains both prog.hex and expected.txt

The signature is automatically loaded per-test via the expected.txt symlink,
so switching tests requires no testbench modifications.

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
# First, add Quartus tools to PATH (or source ~/.bashrc if already added)
export PATH=$PATH:/path/to/quartus/bin
# Example: export PATH=$PATH:/home/user/altera_lite/25.1std/quartus/bin

# Select a test program to synthesize
cd de10nano
ln -sf ../tests/cmp_loop/prog.hex prog.hex

# Synthesize and program
make all             # Synthesize (~15 minutes)
make program-sof     # Program FPGA via JTAG
```

The design uses 8KB of block RAM and easily meets 50 MHz timing on Cyclone V.

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

### ldr_literal

Purpose:
- Validate LDR literal (PC-relative load) instruction
- Verify PC alignment to 4-byte boundary
- Verify offset calculation: Align(PC, 4) + (imm8 << 2)

Behavior:
- Load literal value 0xBC from literal pool using PC-relative addressing
- Build address 0x100 in r1
- Store loaded value to [0x100]
- halt

Expected signature:
- mem[64] = 0x000000BC

------------------------------------------------------------------------------

## Current Status

- Instruction fetch/decode/execute path working
- Flags (N/Z at minimum) verified via loop test
- Conditional branching verified
- Memory stores and loads verified
- Multiple directed tests supported
- Synchronous memory model (1-cycle latency) implemented
- FPGA synthesis verified on DE10-Nano board
- Per-test signature automation (expected.txt files)
- Automated regression test suite (run_tests.sh)

------------------------------------------------------------------------------

## Planned Next Steps

- Expand instruction coverage incrementally
- Add more comprehensive test programs

------------------------------------------------------------------------------

This project is intentionally incremental. Each new instruction or feature
should be validated with a small, focused test program before proceeding.
