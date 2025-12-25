# Tiny Thumb-1 Core for DE10-Nano

This directory contains the FPGA implementation of the Tiny Thumb-1 CPU core for the Terasic DE10-Nano board.

## Board Overview

**Terasic DE10-Nano:**
- FPGA: Intel Cyclone V SE 5CSEBA6U23I7
- Clock: 50 MHz
- 2 push buttons (KEY0, KEY1) - active low
- 4 slide switches (SW0-SW3)
- 8 LEDs (LED0-LED7)
- HPS (ARM Cortex-A9) - not used in this project
- SDRAM - not used in this basic implementation

## Memory Configuration

- **8KB internal block RAM** (2048 words × 32 bits)
- Program loaded from `prog.hex` during synthesis
- Uses FPGA block RAM (M10K blocks)

## Architecture Overview

The FPGA design contains **two independent systems**:

1. **Hardware Counter** (FPGA fabric logic)
   - 32-bit counter increments at 50 MHz
   - Visible on LEDs when SW[0]=ON
   - **Not a program** - built directly into the FPGA top-level module
   - Purpose: Verify programming and clock operation

2. **Thumb-1 CPU Core** (your processor)
   - Executes instructions from `prog.hex` (loaded during synthesis)
   - Runs at 50 MHz, multi-cycle architecture
   - Activity shown on LEDs when SW[0]=OFF
   - Purpose: The actual CPU you're testing and developing

## I/O Mapping

### Inputs
- **KEY[0]**: System reset (active low) - Press to reset the CPU
- **KEY[1]**: Reserved for future use (single-step mode)
- **SW[0]**: Display mode select
  - OFF (0): Show program counter (instruction address)
  - ON (1): Show memory address being accessed
- **SW[3:1]**: Reserved for future use

### Outputs
- **LED[7:0]**: Display (active low)
  - SW[0]=OFF: Shows CPU program counter with LED7 blinking for activity
  - SW[0]=ON: Hardware counter (~6 Hz) - **not a program**, built-in FPGA logic to verify programming and clock

## Build and Programming Instructions

### Prerequisites
- Intel Quartus Prime (tested with 25.1, should work with 18.0+)
- Quartus tools must be in your PATH
- USB Blaster II driver installed

### Hardware Setup

**Connecting the DE10-Nano:**

1. **Power:** Connect 5V power supply to the barrel jack
2. **USB Blaster:** Connect the **USB Blaster port** (mini-USB, usually near the center/top of the board) to your computer
   - **NOT** the USB OTG port (that's for the ARM processor)
   - The port may be labeled "USB Blaster" or just "USB"
3. **Verify connection:**
   ```bash
   export PATH=$PATH:/path/to/quartus/bin
   jtagconfig
   ```
   You should see:
   ```
   1) DE-SoC [1-X.X]
      4BA00477   SOCVHPS
      02D020DD   5CSEBA6(.|ES)/5CSEMA6/..
   ```

**First-time USB Blaster setup (Linux):**

If `jtagconfig` shows "No JTAG hardware available", set up USB permissions:

```bash
# Create udev rule
sudo tee /etc/udev/rules.d/51-altera-usb-blaster.rules > /dev/null << 'EOF'
# USB Blaster
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6001", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6002", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6003", MODE="0666"
# USB Blaster II
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6010", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
EOF

# Reload rules
sudo udevadm control --reload-rules
sudo udevadm trigger

# Unplug and replug the USB Blaster
```

### Synthesis and Programming Workflow

**1. Add Quartus to PATH (add to ~/.bashrc for persistence):**
```bash
export PATH=$PATH:/home/youruser/altera_lite/25.1std/quartus/bin
# Or wherever your Quartus installation is located
```

**2. Select a test program:**
```bash
cd /path/to/thumb1/de10nano

# Use the current test program
cp ../prog.hex .

# Or select a specific test:
ln -sf ../tests/cmp_loop/prog.hex prog.hex
```

**3. Synthesize the design:**
```bash
make all
```

This runs the full synthesis flow (~15-20 minutes):
- **Analysis & Synthesis** - Elaborates design, infers memory blocks
- **Fitter** - Places and routes logic onto FPGA
- **Assembler** - Generates .sof bitstream file
- **Timing Analyzer** - Verifies timing constraints are met

Output: `output_files/de10nano_top.sof`

**4. Program the FPGA:**
```bash
make program-sof
```

This programs the FPGA via JTAG. The configuration is **temporary** - it will be lost when you power cycle the board. Your MiSTer setup is not affected.

### Alternative: Quartus GUI

1. Open `de10nano_top.qpf` in Quartus
2. Processing → Start Compilation
3. Tools → Programmer
4. Select your USB Blaster
5. Add `output_files/de10nano_top.sof`
6. Click Start

## Makefile Targets

- `make all` - Full synthesis flow
- `make map` - Analysis & Synthesis only
- `make fit` - Fitter only (requires map)
- `make asm` - Generate .sof file (requires fit)
- `make sta` - Static timing analysis
- `make program-sof` - Program FPGA via JTAG
- `make rbf` - Generate .rbf file (for MiSTer or flash programming)
- `make clean` - Remove all generated files
- `make update-prog` - Copy prog.hex from parent directory
- `make help` - Show all targets

## Usage on the Board

Once programmed, the FPGA will start running immediately:

1. **LED Activity:**
   - **SW[0]=OFF (default)**: Shows CPU program counter with activity blink
     - LED7 (leftmost) blinks to show the FPGA is running
     - LED6-LED0 show which instruction the CPU is fetching
     - Pattern changes as CPU executes different instructions
   - **SW[0]=ON**: Hardware counter mode (verification only)
     - All 8 LEDs count up slowly (~6 Hz)
     - This is **built-in FPGA hardware**, not a program running on the CPU
     - **Purpose:** Verify that programming succeeded and 50 MHz clock is running
     - Always use this mode first to confirm FPGA is working

2. **Reset:** Press **KEY[0]** to reset the CPU
   - LEDs will return to initial state
   - Program starts executing from address 0

3. **Debug:** If LEDs are frozen or not changing:
   - Toggle SW[0] to ON - you should see a counting pattern
   - If counter works but CPU doesn't, check the program in prog.hex
   - Press KEY[0] to reset

### LED Interpretation

**SW[0]=OFF (CPU Program Counter Display):**
- **LED7**: Activity indicator - blinks at ~6 Hz when FPGA clock is running
- **LED6-LED0**: CPU Program Counter bits [8:2]
  - Shows which 32-bit word in memory the CPU is accessing
  - CPU fetches instructions, so this displays instruction addresses
  - Pattern changes as the CPU program executes different code paths
- **This shows CPU activity** - what your Thumb-1 core is doing

**SW[0]=ON (Hardware Counter - Verification Mode):**
- All 8 LEDs display bits [30:23] of a hardware counter running in FPGA fabric
- **This is NOT a CPU program** - it's dedicated hardware logic built into the FPGA top-level
- Counter increments at 50 MHz, displayed bits update ~6 times per second for visibility
- **Use this to verify:**
  - FPGA programming succeeded (if LEDs count, FPGA is programmed)
  - 50 MHz clock is running (counter won't increment without clock)
  - Reset button (KEY[0]) works - counter resets to 0 when pressed
- **Always check this first** after programming to confirm FPGA is functional

### Debugging

If the LEDs freeze:
- Check if your program has a halt condition or infinite loop
- Press KEY[0] to reset
- Try a different test program

## MiSTer Integration

Since your DE10-Nano is set up as a MiSTer:

### Option 1: Direct JTAG Programming
Use `make program-sof` as described above. This temporarily loads the design without affecting your MiSTer setup.

### Option 2: Generate RBF for MiSTer Core
```bash
make rbf
```

This generates `output_files/de10nano_top.rbf` which can be loaded as a MiSTer core:
1. Copy the .rbf file to your MiSTer SD card
2. Use the OSD menu to load it as a custom core
3. (Requires creating a .mra file for proper MiSTer integration)

**Note:** Full MiSTer core integration requires additional work (menu system, config files, etc.). The JTAG programming method is simpler for development.

## Resource Usage (Estimated)

- **Logic Elements:** ~1000-1500 (out of 40,000)
- **Memory Bits:** 65,536 (8KB for program/data)
- **M10K Blocks:** 8 (out of 119)
- **Maximum Clock Frequency:** ~80-100 MHz (running at 50 MHz)

Plenty of room for expansion!

## Changing the Program

To run a different test program:

```bash
# From de10nano directory
ln -sf ../tests/add_store/prog.hex prog.hex
make clean
make all
make program-sof
```

**Important:** You must rebuild after changing prog.hex because the memory is initialized during synthesis.

## Troubleshooting

### "No JTAG hardware available"
**Symptom:** `jtagconfig` returns "No JTAG hardware available"

**Solutions:**
1. **Check USB connection:**
   - Use the **USB Blaster port** (mini-USB, near center/top of board)
   - NOT the USB OTG port (side of board, near Ethernet)
   - Verify with `lsusb | grep Altera` - should show device ID 09fb:6810

2. **Set up USB permissions (Linux):**
   ```bash
   # Create udev rule
   sudo tee /etc/udev/rules.d/51-altera-usb-blaster.rules > /dev/null << 'EOF'
   SUBSYSTEM=="usb", ATTR{idVendor}=="09fb", ATTR{idProduct}=="6810", MODE="0666"
   EOF
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   # Unplug and replug USB cable
   ```

3. **Install USB Blaster drivers (Windows):**
   - Use Quartus Programmer to install drivers
   - Or manually install from `<quartus>/drivers/usb-blaster-ii/`

### "quartus_map: command not found"
Add Quartus to your PATH:
```bash
export PATH=$PATH:/path/to/quartus/bin
# Example: export PATH=$PATH:~/altera_lite/25.1std/quartus/bin

# Add to ~/.bashrc to make permanent:
echo 'export PATH=$PATH:/path/to/quartus/bin' >> ~/.bashrc
```

### LEDs not changing / appear frozen

**Important:** The hardware counter (SW[0]=ON) and CPU (SW[0]=OFF) are independent. Test them separately.

1. **First: Verify FPGA programming and clock**
   - Toggle SW[0] to ON position
   - You should see a **counting pattern** (~6 Hz) - this is hardware, not the CPU
   - If counter works: ✅ FPGA is programmed, clock is running
   - If counter doesn't work: ❌ FPGA/clock issue (see below)

2. **If hardware counter doesn't work:**
   - Verify board is detected: `jtagconfig`
   - Reprogram the FPGA: `make program-sof`
   - Check power connection to board
   - Check USB Blaster connection

3. **If hardware counter works but CPU appears stuck (SW[0]=OFF):**
   - This is normal! Most test programs finish in microseconds and halt
   - The CPU has run the program and is sitting at a halt instruction
   - LED pattern will be static but LED7 should still blink (clock running)
   - Press KEY[0] to reset the CPU and run the program again
   - To verify CPU works, try: `ln -sf ../tests/cmp_loop/prog.hex prog.hex && make clean && make all && make program-sof`

### Synthesis/Timing failures
**Timing violations:**
The design should easily meet 50 MHz timing. If you see failures:
- Check the timing report: `output_files/de10nano_top.sta.rpt`
- Look for negative slack in setup analysis
- Most likely cause: modified design or very old Quartus version

**Synthesis errors:**
- Verify all source files exist: `de10nano_top.sv`, `tiny_thumb_core.sv`, `tiny_mem_model_fpga.sv`
- Check that `prog.hex` exists in the de10nano directory
- Run `make clean` before rebuilding

### CPU program seems stuck or not running
- **First:** Verify with SW[0]=ON that the hardware counter is running (proves FPGA works)
- **Remember:** Test programs are tiny and complete in microseconds
- Most programs execute, write results to memory, then halt in an infinite loop
- A "frozen" CPU display (SW[0]=OFF) usually means the program finished and halted
- LED7 should still blink even when CPU is halted (shows clock is running)
- Press KEY[0] to reset and re-run the program
- Try a different test program from `../tests/` to see different behavior

## Next Steps

Potential enhancements:
- Add 7-segment display to show register values
- Use HPS for program loading (no recompile needed)
- Add UART for debug output
- Interface with MiSTer SDRAM for larger programs
- Add GPIO for peripherals
- Implement single-step mode using KEY[1]

## Files

- `de10nano_top.sv` - Top-level wrapper
- `de10nano_top.qpf` - Quartus project file
- `de10nano_top.qsf` - Quartus settings and pin assignments
- `Makefile` - Build automation
- `prog.hex` - Program memory initialization
- `../core/tiny_thumb_core.sv` - CPU core
- `../core/tiny_mem_model.sv` - Memory model

## References

- [DE10-Nano User Manual](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=205&No=1046&PartNo=4)
- [Cyclone V Device Handbook](https://www.intel.com/content/www/us/en/programmable/documentation/sam1403482614086.html)
- Thumb-1 core documentation: `../readme.md`
