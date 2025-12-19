`timescale 1ns/1ps

module tb_counter;

    logic clk;
    logic rst_n;
    logic [3:0] count;

    // Instantiate DUT
    counter dut (
        .clk   (clk),
        .rst_n (rst_n),
        .count (count)
    );

    // Clock: 10 ns period
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk   = 0;
        rst_n = 0;

        // Dump waveforms
        $dumpfile("counter.vcd");
        $dumpvars(0, tb_counter);

        // Hold reset for 2 cycles
        #20;
        rst_n = 1;

        // Run for 20 cycles
        #200;

        $finish;
    end

endmodule
