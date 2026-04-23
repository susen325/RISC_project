`timescale 1ns / 1ps

module tb_top_core;
// 1. Declare Testbench Signals
    reg  clk;
    reg  reset;
    wire [15:0] demo_led_output;
    wire [31:0] commit_instr;     // <-- 2. Declare the wire here

    // 2. Instantiate the Unit Under Test (UUT)
    top_core UUT (
        .clk(clk),
        .reset(reset),
        .demo_led_output(demo_led_output),
        .commit_instr(commit_instr) // <-- 3. Plug it in here!
    );

    // 3. Clock Generation
    always #5 clk = ~clk;

    // 4. File I/O Variables
    integer log_file;

    // 5. INSTRUCTION DECODER (For readable logs)
    reg [8*4:1] instr_name; 
    wire [31:0] c_inst = commit_instr; // <-- 4. Remove the "UUT." prefix
    wire [6:0]  op     = c_inst[6:0];
    wire [2:0]  f3     = c_inst[14:12];
    wire [6:0]  f7     = c_inst[31:25];

    always @(*) begin
        if      (op == 7'b0010011) instr_name = "ADDI";
        else if (op == 7'b0100011) instr_name = "SW  ";
        else if (op == 7'b0000011) instr_name = "LW  ";
        else if (op == 7'b0110011 && f7 == 7'b0000001 && f3 == 3'b000) instr_name = "MUL ";
        else if (op == 7'b0110011 && f7 == 7'b0000001 && f3 == 3'b100) instr_name = "DIV ";
        else instr_name = "??? ";
    end

    // 6. Test Sequence
    initial begin
        log_file = $fopen("execution_log.txt", "w");
        $fdisplay(log_file, "=== TOMASULO OUT-OF-ORDER COMMIT LOG ===");
        $display("=== TOMASULO OUT-OF-ORDER COMMIT LOG ===");

        clk = 0; reset = 0; 
        
        #20;
        reset = 1;
        $display("[Time: %0t] Processor out of reset. Execution started...", $time);
        $fdisplay(log_file, "[Time: %0t] Processor out of reset. Execution started...", $time);

        #4000; 

        $display("Simulation Finished. Check execution_log.txt for details.");
        $fdisplay(log_file, "Simulation Finished.");
        $fclose(log_file); 
        $finish;
    end

    // 7. Eavesdropping on the ROB Commits
    always @(posedge clk) begin
        if (reset) begin
            if (UUT.commit_reg_we) begin
                $display(  "[Time: %0t] COMMIT [%s] : Wrote %0d to Register x%0d", 
                           $time, instr_name, UUT.commit_reg_data, UUT.commit_reg_rd);
                $fdisplay(log_file, "[Time: %0t] COMMIT [%s] : Wrote %0d to Register x%0d", 
                           $time, instr_name, UUT.commit_reg_data, UUT.commit_reg_rd);
            end
            
            if (UUT.commit_mem_we) begin
                $display(  "[Time: %0t] COMMIT [%s] : Saved %0d to RAM Address %0d", 
                           $time, instr_name, UUT.commit_mem_data, UUT.commit_mem_addr);
                $fdisplay(log_file, "[Time: %0t] COMMIT [%s] : Saved %0d to RAM Address %0d", 
                           $time, instr_name, UUT.commit_mem_data, UUT.commit_mem_addr);
            end
        end
    end

endmodule