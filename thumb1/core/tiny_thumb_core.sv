// -----------------------------------------------------------------------------
// tiny_thumb_core.sv  (iverilog-friendly, fixed instruction fetch)
//
// Minimal multi-cycle Thumb-1 core 

// -----------------------------------------------------------------------------
// Architecture overview
// -----------------------------------------------------------------------------
// This is intentionally a *multi-cycle* (non-pipelined) microarchitecture:
//
//   FETCH  -> request 16-bit instruction at PC over a 32-bit memory bus
//   WAITI  -> wait for memory ready, select the correct halfword, latch IR
//   DECODE -> decode IR into an internal op + operands
//   EXEC   -> run ALU / compute effective address / decide branch target
//   MEM    -> for loads/stores: issue data memory request
//   WAITM  -> wait for data memory ready, then write-back
//
// The goal is clarity and hackability while implementing the full Thumb-1
// instruction set. Each instruction is broken into simple phases rather than
// building a pipeline up-front.
//
// Memory model assumption:
//   - The external memory interface is 32-bit wide (mem_rdata/mem_wdata).
//   - The core can request any byte address (mem_addr), but the memory model
//     returns the aligned 32-bit word containing that address.
//   - For Thumb instruction fetch, mem_addr[1] selects low/high halfword.
//   - valid/ready handshake: the core asserts mem_valid until mem_ready.
//
// Register file model:
//   - R[0:15] models the architectural register set:
//       R0-R7   : low regs
//       R8-R12  : high regs (not yet used by the minimal subset)
//       R13     : SP (stack pointer)
//       R14     : LR (link register / return address)
//       R15     : PC (architectural view of program counter)
//   - Internally we also keep a separate 32-bit PC register. This avoids
//     accidental misuse of R[15] while bringing up fetch/branch logic.
//     In S_DECODE we mirror PC into R[15] so instructions that read PC can
//     use the architectural view.
//
// Flags:
//   - N,Z,C,V are the standard ARM condition flags.
//   - Only a subset of instructions update flags today; this will expand as
//     additional Thumb-1 instructions are implemented.
// -----------------------------------------------------------------------------

module tiny_thumb_core #(
  parameter ENABLE_ALU_REG_GROUP = 1,
  parameter STRICT_THUMB_SHIFT32 = 0
)(
  input  wire        clk,
  input  wire        rst_n,

  output reg         mem_valid,
  output reg         mem_we,
  output reg  [31:0] mem_addr,
  output reg  [31:0] mem_wdata,
  output reg  [3:0]  mem_wstrb,
  input  wire        mem_ready,
  input  wire [31:0] mem_rdata
);

  // ----------------------------
  // Architectural state
  // ----------------------------
  // ---------------------------------------------------------------------------
  // Architectural state
  // ---------------------------------------------------------------------------
  // General-purpose register file. Eventually all Thumb-1 instructions should
  // interact with these registers exactly as the ARM ARM specifies.
  //
  //  R[0:7]   : low registers (heavily used in Thumb-1 encodings)
  //  R[8:12]  : high registers (used by "high register operations"/BX/etc.)
  //  R[13]    : SP (stack pointer)
  //  R[14]    : LR (link register) - holds return address for BL/BLX (future)
  //  R[15]    : architectural PC view. Many Thumb encodings treat PC as
  //             "current instruction address + 4" and/or require alignment.
  //
  // For bring-up, we keep a dedicated PC register as the *microarchitectural*
  // next-fetch pointer. We mirror that value into R[15] at decode time so
  // PC-relative addressing and future "read PC" behaviors can use R[15].
  reg [31:0] R [0:15];

  // Microarchitectural PC used by the fetch state machine (byte address).
  reg [31:0] PC;

  // Instruction register (latched 16-bit Thumb instruction).
  reg [15:0] IR;

  // Condition flags (CPSR bits). Used by conditional branches today; later by
  // IT blocks, ADC/SBC, comparisons, etc.
  reg N, Z, C, V;

  // ----------------------------
  // State machine encoding (no enums)
  // ----------------------------
  // The core is "one outstanding memory transaction at a time".
  // - S_FETCH/S_WAITI handle instruction fetch (read-only).
  // - S_MEM/S_WAITM handle data accesses for LDR/STR variants.
  // This structure makes it straightforward to extend for more instructions:
  // you either (a) finish in S_EXEC, or (b) use S_MEM/S_WAITM for a memory op.
  localparam S_RESET  = 4'd0;
  localparam S_FETCH  = 4'd1;
  localparam S_WAITI  = 4'd2;
  localparam S_DECODE = 4'd3;
  localparam S_EXEC   = 4'd4;
  localparam S_MEM    = 4'd5;
  localparam S_WAITM  = 4'd6;
  localparam S_TRAP   = 4'd8;

  reg [3:0] st;

  // Decoded op encoding
  // These are *internal* micro-ops, not architectural opcodes.
  // The decode stage maps a 16-bit Thumb instruction into one of these ops
  // plus explicit fields (d_rd/d_rn/d_rm/imm/etc.). This is much easier to grow
  // than trying to execute directly from the raw instruction bits.
  localparam OP_NONE    = 4'd0;
  localparam OP_MOV_IMM = 4'd1;
  localparam OP_CMP_IMM = 4'd2;
  localparam OP_ADD_IMM = 4'd3;
  localparam OP_SUB_IMM = 4'd4;
  localparam OP_LSL_IMM = 4'd5;
  localparam OP_LSR_IMM = 4'd6;
  localparam OP_STR_IMM = 4'd7;
  localparam OP_LDR_IMM = 4'd8;
  localparam OP_LDR_LIT = 4'd9;
  localparam OP_B       = 4'd10;
  localparam OP_BCOND   = 4'd11;
  localparam OP_ALU_REG = 4'd12;

  reg [3:0] op;

  // Latched fields
  reg [2:0] d_rd, d_rn, d_rm, d_rt;
  reg [7:0] d_imm8;
  reg [4:0] d_imm5;
  reg [10:0] d_imm11;
  reg [3:0] d_cond4;
  reg [3:0] d_aluop;

  // ---------------------------------------------------------------------------
  // Internal temporaries / latches
  // ---------------------------------------------------------------------------
  // eff_addr:
  //   Latched effective address for load/store style instructions. Computed in
  //   S_EXEC and then used in S_MEM/S_WAITM so the address is stable across the
  //   memory handshake.
  reg [31:0] eff_addr;

  // load_data:
  //   Temporary holding register for data coming back from memory before it is
  //   written to the destination register in S_WAITM.
  reg [31:0] load_data;

  // fetch_addr:
  //   Address used to *select the correct 16-bit halfword* out of a 32-bit read.
  //   The fetch address must be stable between the request and the response.
  //   (If mem_addr is updated with non-blocking assigns, using it directly can
  //   select the wrong halfword when mem_ready arrives in the next cycle.)
  reg [31:0] fetch_addr;

  integer i;

  // ----------------------------
  // Helper functions (iverilog-friendly)
  // ----------------------------
  function [31:0] align4;
    input [31:0] x;
    begin
      align4 = {x[31:2], 2'b00};
    end
  endfunction

  // Sign-extend using shifts (no variable part-select)
  function [31:0] sext_shift;
    input [31:0] x;
    input integer bits;
    reg signed [31:0] sx;
    begin
      sx = x <<< (32-bits);
      sext_shift = sx >>> (32-bits);
    end
  endfunction

  function cond_ok;
    input [3:0] cond;
    begin
      case (cond)
        4'h0: cond_ok = (Z == 1'b1); // EQ
        4'h1: cond_ok = (Z == 1'b0); // NE
        4'h4: cond_ok = (N == 1'b1); // MI
        4'h5: cond_ok = (N == 1'b0); // PL
        default: cond_ok = 1'b0;
      endcase
    end
  endfunction

  // ----------------------------
  // Instruction classify (combinational wires)
  // ----------------------------
  wire [15:0] insn = IR;

  wire is_bcond   = ((insn & 16'hF000) == 16'hD000) && (insn[11:8] != 4'hF);
  wire is_b       = ((insn & 16'hF800) == 16'hE000);
  wire is_ldr_lit = ((insn & 16'hF800) == 16'h4800);
  wire is_ldr_imm = ((insn & 16'hF800) == 16'h6800);
  wire is_str_imm = ((insn & 16'hF800) == 16'h6000);

  wire is_mov_imm = ((insn & 16'hF800) == 16'h2000);
  wire is_cmp_imm = ((insn & 16'hF800) == 16'h2800);
  wire is_add_imm = ((insn & 16'hF800) == 16'h3000);
  wire is_sub_imm = ((insn & 16'hF800) == 16'h3800);

  wire is_lsl_imm = ((insn & 16'hF800) == 16'h0000);
  wire is_lsr_imm = ((insn & 16'hF800) == 16'h0800);

  wire is_alu_reg = ((insn & 16'hFC00) == 16'h4000);

  // ----------------------------
  // Main FSM
  // ----------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      st <= S_RESET;
      op <= OP_NONE;

      PC <= 32'd0;
      IR <= 16'd0;

      N <= 1'b0; Z <= 1'b0; C <= 1'b0; V <= 1'b0;

      mem_valid <= 1'b0;
      mem_we    <= 1'b0;
      mem_addr  <= 32'd0;
      mem_wdata <= 32'd0;
      mem_wstrb <= 4'd0;

      eff_addr  <= 32'd0;
      load_data <= 32'd0;
      fetch_addr <= 32'd0;

      for (i = 0; i < 16; i = i + 1)
        R[i] <= 32'd0;

    end else begin
      // Default bus outputs each cycle
      mem_valid <= 1'b0;
      mem_we    <= 1'b0;
      mem_addr  <= 32'd0;
      mem_wdata <= 32'd0;
      mem_wstrb <= 4'd0;

      case (st)

        S_RESET: begin
          st <= S_FETCH;
        end

        // ------------------------
        // FETCH: request instruction word at PC (byte address)
        // ------------------------
        S_FETCH: begin
          // Issue an *instruction fetch* read request.
          //
          // Note: PC is a byte address. Thumb instructions are 16-bit, so we
          // advance the PC by 2 for the next fetch. The memory interface is
          // still 32-bit, so the memory model will return the aligned word
          // containing this halfword.
          mem_valid <= 1'b1;
          mem_we    <= 1'b0;
          mem_addr  <= PC;

          // Spec behaviour: PC advances by 2 bytes per Thumb instruction fetch.
          // We increment here (rather than after the response) so that:
          //   - PC always points at "next instruction" after FETCH, and
          //   - the current instruction address is recovered as (PC - 2).
          PC <= PC + 32'd2;

          st <= S_WAITI;
        end

        // ------------------------
        // WAITI: latch IR once memory responds
        // Fixed: use stable fetch_addr for halfword selection.
        // ------------------------
        S_WAITI: begin
          // Wait for instruction fetch to complete.
          //
          // Because PC was already incremented in S_FETCH, the address of the
          // instruction being fetched is (PC - 2). We capture it into fetch_addr
          // and use that to select the correct halfword from mem_rdata.
          //
          // IMPORTANT: fetch_addr is assigned with a *blocking* assignment so
          // it is stable for halfword selection in the same cycle that mem_ready
          // is observed.
          fetch_addr = (PC - 32'd2);

          mem_valid <= 1'b1;
          mem_we    <= 1'b0;
          mem_addr  <= fetch_addr;

          if (mem_ready) begin
            if (fetch_addr[1] == 1'b0)
              IR <= mem_rdata[15:0];
            else
              IR <= mem_rdata[31:16];

            st <= S_DECODE;
          end
        end

        // ------------------------
        // DECODE: decide op + latch fields
        // ------------------------
        S_DECODE: begin
          op <= OP_NONE;

          if (is_bcond) begin
            if (insn[11:8]==4'h0 || insn[11:8]==4'h1 || insn[11:8]==4'h4 || insn[11:8]==4'h5) begin
              op <= OP_BCOND;
              d_cond4 <= insn[11:8];
              d_imm8  <= insn[7:0];
              st <= S_EXEC;
            end else begin
              st <= S_TRAP;
            end

          end else if (is_b) begin
            op <= OP_B;
            d_imm11 <= insn[10:0];
            st <= S_EXEC;

          end else if (is_ldr_lit) begin
            op <= OP_LDR_LIT;
            d_rt   <= insn[10:8];
            d_imm8 <= insn[7:0];
            st <= S_EXEC;

          end else if (is_ldr_imm) begin
            op <= OP_LDR_IMM;
            d_imm5 <= insn[10:6];
            d_rn   <= insn[5:3];
            d_rt   <= insn[2:0];
            st <= S_EXEC;

          end else if (is_str_imm) begin
            op <= OP_STR_IMM;
            d_imm5 <= insn[10:6];
            d_rn   <= insn[5:3];
            d_rt   <= insn[2:0];
            st <= S_EXEC;

          end else if (is_mov_imm) begin
            op <= OP_MOV_IMM;
            d_rd   <= insn[10:8];
            d_imm8 <= insn[7:0];
            st <= S_EXEC;

          end else if (is_cmp_imm) begin
            op <= OP_CMP_IMM;
            d_rd   <= insn[10:8];
            d_imm8 <= insn[7:0];
            st <= S_EXEC;

          end else if (is_add_imm) begin
            op <= OP_ADD_IMM;
            d_rd   <= insn[10:8];
            d_imm8 <= insn[7:0];
            st <= S_EXEC;

          end else if (is_sub_imm) begin
            op <= OP_SUB_IMM;
            d_rd   <= insn[10:8];
            d_imm8 <= insn[7:0];
            st <= S_EXEC;

          end else if (is_lsl_imm) begin
            op <= OP_LSL_IMM;
            d_imm5 <= insn[10:6];
            d_rm   <= insn[5:3];
            d_rd   <= insn[2:0];
            st <= S_EXEC;

          end else if (is_lsr_imm) begin
            op <= OP_LSR_IMM;
            d_imm5 <= insn[10:6];
            d_rm   <= insn[5:3];
            d_rd   <= insn[2:0];
            st <= S_EXEC;

          end else if (ENABLE_ALU_REG_GROUP && is_alu_reg) begin
            if (insn[9:6]==4'h0 || insn[9:6]==4'h1 || insn[9:6]==4'hC || insn[9:6]==4'hA) begin
              op <= OP_ALU_REG;
              d_aluop <= insn[9:6];
              d_rm    <= insn[5:3];
              d_rd    <= insn[2:0];
              st <= S_EXEC;
            end else begin
              st <= S_TRAP;
            end

          end else begin
            st <= S_TRAP;
          end
        end

        // ------------------------
        // EXEC: compute results / flags / addresses
        // ------------------------
        S_EXEC: begin
          reg [31:0] A, B, RES;
          reg [32:0] WIDE;
          reg [31:0] off;

          A = 32'd0; B = 32'd0; RES = 32'd0; WIDE = 33'd0; off = 32'd0;

          case (op)

            OP_MOV_IMM: begin
              RES = {24'd0, d_imm8};
              R[{1'b0,d_rd}] <= RES;
              N <= RES[31];
              Z <= (RES == 32'd0);
              st <= S_FETCH;
            end

            OP_CMP_IMM: begin
              A = R[{1'b0,d_rd}];
              B = {24'd0, d_imm8};
              RES = A - B;
              N <= RES[31];
              Z <= (RES == 32'd0);
              C <= (A >= B);
              V <= ((A[31]^B[31]) & (A[31]^RES[31]));
              st <= S_FETCH;
            end

            OP_ADD_IMM: begin
              A = R[{1'b0,d_rd}];
              B = {24'd0, d_imm8};
              RES = A + B;
              WIDE = {1'b0,A} + {1'b0,B};
              R[{1'b0,d_rd}] <= RES;
              N <= RES[31];
              Z <= (RES == 32'd0);
              C <= WIDE[32];
              V <= ((~(A[31]^B[31])) & (A[31]^RES[31]));
              st <= S_FETCH;
            end

            OP_SUB_IMM: begin
              A = R[{1'b0,d_rd}];
              B = {24'd0, d_imm8};
              RES = A - B;
              R[{1'b0,d_rd}] <= RES;
              N <= RES[31];
              Z <= (RES == 32'd0);
              C <= (A >= B);
              V <= ((A[31]^B[31]) & (A[31]^RES[31]));
              st <= S_FETCH;
            end

            OP_LSL_IMM: begin
              A = R[{1'b0,d_rm}];
              if (d_imm5 == 5'd0) begin
                RES = A;
              end else begin
                RES = A << d_imm5;
                C <= A[32 - d_imm5];
              end
              R[{1'b0,d_rd}] <= RES;
              N <= RES[31];
              Z <= (RES == 32'd0);
              st <= S_FETCH;
            end

            OP_LSR_IMM: begin
              A = R[{1'b0,d_rm}];
              if (d_imm5 == 5'd0) begin
                if (STRICT_THUMB_SHIFT32) begin
                  RES = 32'd0;
                  C <= A[31];
                end else begin
                  RES = A;
                end
              end else begin
                RES = A >> d_imm5;
                C <= A[d_imm5-1];
              end
              R[{1'b0,d_rd}] <= RES;
              N <= RES[31];
              Z <= (RES == 32'd0);
              st <= S_FETCH;
            end

            OP_STR_IMM: begin
              eff_addr <= R[{1'b0,d_rn}] + ({27'd0,d_imm5} << 2);
              st <= S_MEM;
            end

            OP_LDR_IMM: begin
              eff_addr <= R[{1'b0,d_rn}] + ({27'd0,d_imm5} << 2);
              st <= S_MEM;
            end

            OP_LDR_LIT: begin
              eff_addr <= align4(PC) + ({24'd0,d_imm8} << 2);
              st <= S_MEM;
            end

            OP_B: begin
              off = sext_shift({20'd0, d_imm11, 1'b0}, 12);
              PC <= PC + off;
              st <= S_FETCH;
            end

            OP_BCOND: begin
              off = sext_shift({23'd0, d_imm8, 1'b0}, 9);
              if (cond_ok(d_cond4))
                PC <= PC + off;
              st <= S_FETCH;
            end

            OP_ALU_REG: begin
              A = R[{1'b0,d_rd}];
              B = R[{1'b0,d_rm}];

              case (d_aluop)
                4'h0: begin // AND
                  RES = A & B;
                  R[{1'b0,d_rd}] <= RES;
                  N <= RES[31]; Z <= (RES==32'd0);
                  st <= S_FETCH;
                end
                4'h1: begin // EOR
                  RES = A ^ B;
                  R[{1'b0,d_rd}] <= RES;
                  N <= RES[31]; Z <= (RES==32'd0);
                  st <= S_FETCH;
                end
                4'hC: begin // ORR
                  RES = A | B;
                  R[{1'b0,d_rd}] <= RES;
                  N <= RES[31]; Z <= (RES==32'd0);
                  st <= S_FETCH;
                end
                4'hA: begin // CMP
                  RES = A - B;
                  N <= RES[31];
                  Z <= (RES == 32'd0);
                  C <= (A >= B);
                  V <= ((A[31]^B[31]) & (A[31]^RES[31]));
                  st <= S_FETCH;
                end
                default: st <= S_TRAP;
              endcase
            end

            default: st <= S_TRAP;
          endcase
        end

        // ------------------------
        // MEM: issue memory op
        // ------------------------
        S_MEM: begin
          mem_valid <= 1'b1;
          mem_addr  <= eff_addr;

          if (op == OP_STR_IMM) begin
            mem_we    <= 1'b1;
            mem_wdata <= R[{1'b0,d_rt}];
            mem_wstrb <= 4'b1111;
          end else begin
            mem_we    <= 1'b0;
            mem_wstrb <= 4'b0000;
          end

          st <= S_WAITM;
        end

        // ------------------------
        // WAITM: wait for memory response; commit load
        // ------------------------
        S_WAITM: begin
          mem_valid <= 1'b1;
          mem_addr  <= eff_addr;

          if (op == OP_STR_IMM) begin
            mem_we    <= 1'b1;
            mem_wdata <= R[{1'b0,d_rt}];
            mem_wstrb <= 4'b1111;
          end else begin
            mem_we    <= 1'b0;
            mem_wstrb <= 4'b0000;
          end

          if (mem_ready) begin
            if (op == OP_LDR_IMM || op == OP_LDR_LIT) begin
              load_data <= mem_rdata;
              R[{1'b0,d_rt}] <= mem_rdata;
            end
            st <= S_FETCH;
          end
        end

        S_TRAP: begin
          st <= S_TRAP;
        end

        default: st <= S_TRAP;
      endcase

      // Keep architectural R15 in sync with the microarchitectural PC.
      //
      // Why do this at the *end* of the clocked block?
      //   - Many Thumb encodings read PC with an implicit +4 and/or alignment.
      //     Those semantics should be implemented in the decode/execute paths
      //     for the relevant instructions (e.g., LDR literal, ADR, ADD(PC)).
      //   - Here we simply expose the current next-fetch PC value in R[15] so
      //     debug traces and future instruction implementations have an
      //     architectural register to reference.
      R[15] <= PC;
    end
  end

endmodule
