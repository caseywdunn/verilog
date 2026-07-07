# hello — 4-bit Counter (Verilog)

The simplest possible project in this repo: a 4-bit synchronous counter and
a self-contained testbench. It exists to confirm the simulation toolchain
works end to end — compile, run, and view a waveform — before moving on to
larger designs.


------------------------------------------------------------------------------

## Files

hello/
├── counter.sv        The design under test: a 4-bit counter
├── tb_counter.sv     Testbench that clocks the counter and dumps waveforms
├── sim.out           Compiled simulation binary (generated)
├── counter.vcd       Waveform output (generated)
└── README.md         This file


------------------------------------------------------------------------------

## What the design does

`counter` increments a 4-bit value on every rising clock edge, wrapping from
15 back to 0. An active-low reset (`rst_n`) forces the count to 0.

The testbench (`tb_counter.sv`):
- Generates a 10 ns clock (5 ns high, 5 ns low).
- Holds `rst_n` low for the first 20 ns (2 cycles), then releases it.
- Runs for 20 more cycles and calls `$finish`.
- Writes a `counter.vcd` waveform via `$dumpfile` / `$dumpvars`.


------------------------------------------------------------------------------

## Running the simulation

From the `hello/` directory:

    iverilog -g2012 -o sim.out tb_counter.sv counter.sv
    vvp sim.out

Expected output:

    VCD info: dumpfile counter.vcd opened for output.
    tb_counter.sv:35: $finish called at 220000 (1ps)

`iverilog` compiles the SystemVerilog into `sim.out`; `vvp` runs it and
produces `counter.vcd`.


------------------------------------------------------------------------------

## Viewing the waveform in VS Code

Waveforms are viewed with a VS Code extension rather than GTKWave (see the
top-level [readme.md](../readme.md) for why).

### One-time setup: install the Surfer extension

Install from the command line:

    code --install-extension surfer-project.surfer

Or open the Extensions view (Cmd+Shift+X), search for **Surfer**
(`surfer-project.surfer`), and click Install. (Any other VCD viewer such as
**VaporView**, `lramseyer.vaporview`, works too.) Reload the window if
prompted so the extension activates.

### Opening the waveform

Click `counter.vcd` in the VS Code file explorer. Surfer opens it as a
waveform view. If it opens as plain text instead, right-click the file →
**Open With…** → **Surfer**.

### Adding signals

Surfer shows two panels on the left — **Scopes** (the module hierarchy) and
**Variables** (signals in the selected scope). They work as a pair:

1. In the **Scopes** panel, click **`tb_counter`** (the top-level testbench
   module). This is what populates the Variables panel — nothing appears there
   until a scope is selected.
2. In the **Variables** panel, you now see `clk`, `rst_n`, and `count`. Add
   each to the waveform by selecting it and pressing **Enter** (or
   double-clicking, or right-click → Add). Cmd-click to select all three and
   add them together.
3. If the waveform area looks empty after adding signals, press **`f`** (zoom
   to fit) — the default zoom can leave the trace off-screen.

### Reading the trace

- `clk` toggles every 5 ns (10 ns period).
- `rst_n` is low for the first 20 ns, holding `count` at 0.
- After `rst_n` goes high, `count` increments 0 → 1 → 2 → … on each rising
  clock edge, wrapping at 15.
- `count` is a 4-bit bus; right-click it to change the radix (decimal / hex /
  binary) if you want to read the value differently.

Re-run the simulation and reopen (or reload) `counter.vcd` to see updated
waveforms after any change.
