// -----------------------------------------------------------------------------
// de10nano_top.sv
//
// Top-level wrapper for Tiny Thumb-1 Core on Terasic DE10-Nano board
//
// Board Resources:
//   - 50 MHz clock (FPGA_CLK1_50)
//   - 2 push buttons (KEY0, KEY1) - active low
//   - 4 slide switches (SW0-SW3)
//   - 8 LEDs (LED0-LED7)
//   - Cyclone V SE 5CSEBA6U23I7
//
// Memory Configuration:
//   - 8KB internal block RAM (2048 words)
//   - Program loaded via $readmemh at synthesis
//
// Display:
//   - LED7-LED0: Lower 8 bits of current PC (divided by 2 for instruction address)
//   - Can be modified to show register values or status
//
// Reset:
//   - KEY0: System reset (active low)
//   - KEY1: Manual single-step (future feature)
//
// -----------------------------------------------------------------------------
module de10nano_top (
    // Clock
    input  wire        FPGA_CLK1_50,

    // Push buttons (active low)
    input  wire [1:0]  KEY,

    // Slide switches
    input  wire [3:0]  SW,

    // LEDs
    output wire [7:0]  LED
);

    // -------------------------------------------------------------------------
    // Clock and Reset
    // -------------------------------------------------------------------------
    wire clk;
    wire rst_n;

    assign clk = FPGA_CLK1_50;
    assign rst_n = KEY[0];  // Active-low reset on KEY0

    // -------------------------------------------------------------------------
    // CPU Instance
    // -------------------------------------------------------------------------
    wire        mem_valid;
    wire        mem_we;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire        mem_ready;
    wire [31:0] mem_rdata;

    tiny_thumb_core #(
        .ENABLE_ALU_REG_GROUP(1),
        .STRICT_THUMB_SHIFT32(0)
    ) cpu (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    // -------------------------------------------------------------------------
    // Memory Instance (8KB = 2048 words)
    // -------------------------------------------------------------------------
    tiny_mem_model #(
        .WORDS(2048),
        .INIT_HEX("prog.hex")
    ) memory (
        .clk(clk),
        .rst_n(rst_n),
        .mem_valid(mem_valid),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_ready(mem_ready),
        .mem_rdata(mem_rdata)
    );

    // -------------------------------------------------------------------------
    // LED Display
    // -------------------------------------------------------------------------
    // Slow counter to make activity visible
    reg [31:0] slow_counter;
    reg [7:0] led_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slow_counter <= 32'd0;
            led_reg <= 8'h00;
        end else begin
            slow_counter <= slow_counter + 1;

            // Display mode selected by SW[0]
            if (SW[0]) begin
                // Mode 1: Slow counter (visible)
                // Divide by 2^23 (~6Hz at 50MHz)
                led_reg <= slow_counter[30:23];
            end else begin
                // Mode 0: Show PC (instruction address) with activity indicator
                if (mem_valid && !mem_we) begin
                    // Lower 7 bits = PC address, top bit = activity blink
                    led_reg <= {slow_counter[23], mem_addr[8:2]};
                end
            end
        end
    end

    assign LED = ~led_reg;  // Invert for active-low LEDs

endmodule
