// -----------------------------------------------------------------------------
// tiny_mem_model.sv
//
// Unified single-ported memory model (iverilog-friendly)
//
// IMPORTANT: Synchronous read (1-cycle latency), synchronous write.
// This models real FPGA block RAM behavior for synthesis compatibility.
// -----------------------------------------------------------------------------
module tiny_mem_model #(
  parameter int WORDS = 4096,
  parameter string INIT_HEX = ""
)(
  input  wire        clk,
  input  wire        rst_n,

  input  wire        mem_valid,
  input  wire        mem_we,
  input  wire [31:0] mem_addr,
  input  wire [31:0] mem_wdata,
  input  wire [3:0]  mem_wstrb,
  output reg         mem_ready,
  output reg  [31:0] mem_rdata
);

  reg [31:0] mem [0:WORDS-1];

  wire [31:0] word_index = mem_addr >> 2;

  // Track if we were reading last cycle for 1-cycle read latency
  reg was_reading;

  // Synchronous read/write with proper handshake
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rdata <= 32'd0;
      mem_ready <= 1'b0;
      was_reading <= 1'b0;
    end else begin
      if (mem_valid && mem_we) begin
        // Writes complete immediately (same cycle)
        mem_ready <= 1'b1;
        was_reading <= 1'b0;
      end else if (mem_valid && !mem_we) begin
        // Reads take 1 cycle: latch data now, signal ready next cycle
        mem_rdata <= mem[word_index];
        mem_ready <= was_reading;  // Ready on 2nd consecutive cycle
        was_reading <= 1'b1;
      end else begin
        mem_ready <= 1'b0;
        was_reading <= 1'b0;
      end
    end
  end

  // Zero-fill then load program
  integer i;
  initial begin
    for (i = 0; i < WORDS; i = i + 1)
      mem[i] = 32'd0;

    if (INIT_HEX != "") begin
      $readmemh(INIT_HEX, mem);
    end
  end

  // Synchronous write with byte strobes
  always @(posedge clk) begin
    if (mem_valid && mem_we) begin
      if (mem_wstrb[0]) mem[word_index][ 7: 0] <= mem_wdata[ 7: 0];
      if (mem_wstrb[1]) mem[word_index][15: 8] <= mem_wdata[15: 8];
      if (mem_wstrb[2]) mem[word_index][23:16] <= mem_wdata[23:16];
      if (mem_wstrb[3]) mem[word_index][31:24] <= mem_wdata[31:24];
    end
  end

endmodule
