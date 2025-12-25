module tb;

  // 100 MHz-ish clock
  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst_n = 1'b0;

  // Memory bus
  wire        mem_valid;
  wire        mem_we;
  wire [31:0] mem_addr;
  wire [31:0] mem_wdata;
  wire [3:0]  mem_wstrb;
  wire        mem_ready;
  wire [31:0] mem_rdata;

  // Signature configuration
  localparam integer SIG_ADDR       = 32'h0000_0100;
  localparam integer SIG_WORD_INDEX = (SIG_ADDR >> 2); // 0x100 >> 2 = 64

  // Set this depending on which test prog.hex is linked to.
  // add_store test:   32'd10
  // cmp_loop test:    32'h000000A1
  // ldr_literal test: 32'h000000BC
  localparam [31:0]  EXPECTED_SIG   = 32'h000000BC;

  // DUT
  tiny_thumb_core dut (
    .clk       (clk),
    .rst_n     (rst_n),
    .mem_valid (mem_valid),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_ready (mem_ready),
    .mem_rdata (mem_rdata)
  );

  // Memory (8 KB to fit iCE40HX1K constraints: 2048 words × 32 bits = 64 Kbits)
  tiny_mem_model #(
    .WORDS(2048),
    .INIT_HEX("prog.hex")
  ) mem (
    .clk       (clk),
    .rst_n     (rst_n),
    .mem_valid (mem_valid),
    .mem_we    (mem_we),
    .mem_addr  (mem_addr),
    .mem_wdata (mem_wdata),
    .mem_wstrb (mem_wstrb),
    .mem_ready (mem_ready),
    .mem_rdata (mem_rdata)
  );

  // VCD
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb);
  end

  initial begin
    // Reset
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;

    // Run long enough for the program to execute
    repeat (800) @(posedge clk);

    // Self-check signature
    if (mem.mem[SIG_WORD_INDEX] !== EXPECTED_SIG) begin
      $display("FAIL: mem[%0d] (addr %h) = %h, expected %h",
               SIG_WORD_INDEX, SIG_ADDR, mem.mem[SIG_WORD_INDEX], EXPECTED_SIG);
      $fatal(1);
    end else begin
      $display("PASS: mem[%0d] (addr %h) = %h",
               SIG_WORD_INDEX, SIG_ADDR, mem.mem[SIG_WORD_INDEX]);
    end

    $finish;
  end

endmodule
