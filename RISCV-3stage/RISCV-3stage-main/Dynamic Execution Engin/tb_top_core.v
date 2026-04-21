`timescale 1ns / 1ps

module tb_top_core;

    // 1. Declare Testbench Signals
    reg  clk;
    reg  reset;
    wire [15:0] demo_led_output;

    // 2. Instantiate the Unit Under Test (UUT)
    top_core UUT (
        .clk(clk),
        .reset(reset),
        .demo_led_output(demo_led_output)
    );

    // 3. Clock Generation (100 MHz -> 10ns period)
    always #5 clk = ~clk;

    // 4. File I/O Variables
    integer log_file;

    // 5. Test Sequence
    initial begin
        // Open the text file for writing
        log_file = $fopen("execution_log.txt", "w");
        $fdisplay(log_file, "=== TOMASULO OUT-OF-ORDER COMMIT LOG ===");
        $display("=== TOMASULO OUT-OF-ORDER COMMIT LOG ===");

        // Initialize clock and assert reset
        clk = 0;
        reset = 0; // Active low reset
        
        // Wait 20 nanoseconds, then release reset
        #20;
        reset = 1;
        $display("[Time: %0t] Processor out of reset. Execution started...", $time);
        $fdisplay(log_file, "[Time: %0t] Processor out of reset. Execution started...", $time);

        // Let the processor run enough cycles to finish our test program
        #2000; 

        $display("Simulation Finished. Check execution_log.txt for details.");
        $fdisplay(log_file, "Simulation Finished.");
        $fclose(log_file); // Safely close the file
        $finish;
    end

    // 6. Eavesdropping on the ROB Commits
    // By using "UUT.", we can peek inside the top_core module wires!
    always @(posedge clk) begin
        if (reset) begin
            // Did the ROB commit a math instruction to the Register File?
            if (UUT.commit_reg_we) begin
                $display(  "[Time: %0t] COMMIT REG : Wrote %0d to Register x%0d", $time, UUT.commit_reg_data, UUT.commit_reg_rd);
                $fdisplay(log_file, "[Time: %0t] COMMIT REG : Wrote %0d to Register x%0d", $time, UUT.commit_reg_data, UUT.commit_reg_rd);
            end
            
            // Did the ROB commit a Store instruction to Physical RAM?
            if (UUT.commit_mem_we) begin
                $display(  "[Time: %0t] COMMIT MEM : Saved %0d to RAM Address %0d", $time, UUT.commit_mem_data, UUT.commit_mem_addr);
                $fdisplay(log_file, "[Time: %0t] COMMIT MEM : Saved %0d to RAM Address %0d", $time, UUT.commit_mem_data, UUT.commit_mem_addr);
            end
        end
    end

    // 7. Waveform Dumping
    initial begin
        $dumpfile("tomasulo_waves.vcd");
        $dumpvars(0, tb_top_core);
    end

endmodule
