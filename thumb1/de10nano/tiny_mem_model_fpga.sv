// -----------------------------------------------------------------------------
// tiny_mem_model_fpga.sv
//
// FPGA synthesis version of memory model for Quartus
// Uses Quartus RAM initialization attributes
// -----------------------------------------------------------------------------
module tiny_mem_model #(
  parameter int WORDS = 4096,
  parameter string INIT_HEX = ""  // Ignored in FPGA version
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

  (* ramstyle = "M10K" *) reg [31:0] mem [0:WORDS-1];

  wire [31:0] word_index = mem_addr >> 2;

  // Delayed valid signals for 1-cycle read latency
  reg valid_r;
  reg we_r;

  // Block RAM read port - registered output pattern
  always @(posedge clk) begin
    mem_rdata <= mem[word_index];
  end

  // Block RAM write port with byte enables
  always @(posedge clk) begin
    if (mem_valid && mem_we) begin
      if (mem_wstrb[0]) mem[word_index][ 7: 0] <= mem_wdata[ 7: 0];
      if (mem_wstrb[1]) mem[word_index][15: 8] <= mem_wdata[15: 8];
      if (mem_wstrb[2]) mem[word_index][23:16] <= mem_wdata[23:16];
      if (mem_wstrb[3]) mem[word_index][31:24] <= mem_wdata[31:24];
    end
  end

  // Zero-fill for simulation
  integer j;
  initial begin
    for (j = 0; j < WORDS; j = j + 1)
      mem[j] = 32'd0;
    $readmemh("prog.hex", mem);
  end

  // Ready signal: delayed version of valid for 1-cycle read latency
  // Writes complete same-cycle, reads complete next-cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_r <= 1'b0;
      we_r <= 1'b0;
      mem_ready <= 1'b0;
    end else begin
      valid_r <= mem_valid;
      we_r <= mem_we;

      // Ready is immediate for writes, delayed for reads
      if (mem_valid && mem_we) begin
        mem_ready <= 1'b1;  // Write completes same cycle
      end else if (valid_r && !we_r) begin
        mem_ready <= 1'b1;  // Read completes next cycle
      end else begin
        mem_ready <= 1'b0;
      end
    end
  end

endmodule
