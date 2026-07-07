# Verilog experiments

See readme files within project folders. Start with [hello](hello/README.md)
for the simplest end-to-end example.


## Tooling for simulation

All projects here can be simulated locally with the open-source Icarus Verilog
flow. On macOS these are available via Homebrew:

    brew install icarus-verilog

This provides:

- `iverilog` — compiles Verilog/SystemVerilog into a simulation binary.
- `vvp` — runs the compiled simulation and produces a `.vcd` waveform.

Waveforms are viewed with a **VS Code extension**, not GTKWave. The Homebrew
GTKWave cask is an Intel-only (x86_64) build that no longer runs natively on
Apple Silicon and has been deprecated upstream. Instead install a native VCD
viewer extension such as **Surfer** (`surfer-project.surfer`) or **VaporView**
(`lramseyer.vaporview`), then open the generated `.vcd` file directly in the
editor. The [hello](hello/README.md) project walks through this.

A SystemVerilog language extension such as **Verilog HDL/SystemVerilog**
(`mshr-h.veriloghdl`) is also recommended for syntax highlighting and linting.


## Tooling for FPGA builds

Simulation is enough for most work here. Building for real hardware requires
additional vendor or open-source toolchains that are **not** covered in detail
in this repo:

- **iCEstick (Lattice iCE40)** — the open-source flow: `yosys` (synthesis),
  `nextpnr-ice40` (place & route), and Project IceStorm (`icepack`, `iceprog`).
- **DE-10 Nano (Intel/Altera Cyclone V)** — Intel Quartus Prime, installed
  from Intel's site (not Homebrew).

Install these only when actually targeting hardware.


## Hardware

The specific hardware I use includes:

- iCE40HX1K-STICK-EVN iCEstick FPGA Evaluation Board manufactured by Lattice Semiconductor Corporation.
- [DE-10 Nano](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=167&No=1046) with RAM Module and other peripherals for [MiSTer](https://retrorgb.com/mister.html) FPGA Retro Gaming rig.

When building for FPGA, target one or both.

Not all projects in this repo are necessarily intended for FPGA implementation. But always favor design decisions that are consistent with building for these so I am building relevant expertise. 
