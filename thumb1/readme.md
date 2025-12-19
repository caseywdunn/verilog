# thumb1 — Minimal Thumb-1–like Core (Verilog)

This folder contains a small multi-cycle CPU core implemented in Verilog/SystemVerilog that executes a minimal Thumb-1–style subset. It is intended as a learning vehicle for ARM architecture and CPU implementation.

## Contents

- tiny_thumb_core.sv
  The CPU core (multi-cycle FSM, register file, flags, decode/execute).

- tiny_mem_model.sv
  A simple unified instruction/data memory model with:
    - Combinational (async) reads to match the current core timing
    - Synchronous writes with byte strobes
    - Optional HEX initialization (prog.hex)

- tb.sv
  Self-checking testbench that:
    - Loads prog.hex
    - Runs the core for a fixed number of cycles
    - Verifies a “signature” word in memory (defaults to address 0x100)

- prog.hex
  Program image, loaded into memory word 0 upward.

- dump.vcd
  Generated waveform file (created after simulation runs).

------------------------------------------------------------------------------

## How to Run

### Prerequisites
- Icarus Verilog (iverilog) with SystemVerilog enabled
- vvp (part of Icarus)
- GTKWave (optional, for waveforms)

On Debian/Ubuntu:
    sudo apt-get install iverilog gtkwave

### Run the simulation
From the thumb1/ directory:
    iverilog -g2012 -o sim.out tb.sv tiny_thumb_core.sv tiny_mem_model.sv
    vvp sim.out

Expected output (for the default prog.hex described below):
  - A PASS message from the testbench
  - dump.vcd produced

Example:
    VCD info: dumpfile dump.vcd opened for output.
    PASS: mem[64] (addr 00000100) = 0000000a

### View waveforms (optional)
    gtkwave dump.vcd

Useful signals to inspect in GTKWave:
  - tb.dut.PC, tb.dut.IR, tb.dut.st, tb.dut.op
  - tb.dut.R[0], tb.dut.R[1]
  - tb.mem.mem[64] (word at address 0x100)

------------------------------------------------------------------------------

## Overall Architecture

### Execution model
This is a multi-cycle CPU: each instruction is executed over several states instead of being pipelined.

  1. FETCH   – issue memory read for instruction at PC
  2. WAITI   – latch the 16-bit instruction (IR) from memory
  3. DECODE  – classify instruction and latch operands/immediates
  4. EXEC    – perform ALU operation or compute address/branch target
  5. MEM     – perform data memory operation (LDR/STR only)
  6. FETCH   – next instruction

The PC advances by 2 bytes per instruction fetch (Thumb semantics).

### Registers and flags
- Registers R0–R15 stored internally
- R15 mirrors PC for debug visibility
- Flags N, Z, C, V updated by arithmetic and compare instructions

### Memory interface
- mem_valid asserted with mem_addr
- mem_we asserted for stores
- mem_wstrb selects byte lanes
- mem_ready is always high in the model

NOTE: The memory model uses combinational reads. A synchronous-read memory would require additional FSM states.

------------------------------------------------------------------------------

## prog.hex Format

prog.hex is loaded by $readmemh into a 32-bit word array.

Each line is one 32-bit word (8 hex digits).
Each word contains two 16-bit Thumb instructions:
  - lower halfword [15:0] executes first
  - upper halfword [31:16] executes second

This matches little-endian Thumb layout.

------------------------------------------------------------------------------

## Explanation of the First prog.hex Program

prog.hex:
    30072005
    21013802
    60080209
    0000E7FE

Decoded (two Thumb instructions per word):

Word 0:
    0x2005  MOVS r0, #5
    0x3007  ADDS r0, #7

Word 1:
    0x3802  SUBS r0, #2
    0x2101  MOVS r1, #1

Word 2:
    0x0209  LSL  r1, r1, #8
    0x6008  STR  r0, [r1, #0]

Word 3:
    0xE7FE  B .
    0x0000  unused padding

Assembly listing:

    MOVS    r0, #5
    ADDS    r0, #7
    SUBS    r0, #2

    MOVS    r1, #1
    LSL     r1, r1, #8

    STR     r0, [r1, #0]

halt:
    B       halt

The program writes the value 10 to memory address 0x100.

The testbench checks:
    mem[0x100 >> 2] == mem[64] == 10

If true, the testbench reports PASS.

------------------------------------------------------------------------------

## Next Steps

- Add CMP + conditional branch loop test
- Add LDR literal (PC-relative) test
- Convert memory model to synchronous-read and update FSM
- Expand instruction coverage incrementally
