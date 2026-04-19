`timescale 1ns/1ps

module tb_dynamic;

    reg clk;
    reg reset;

    // Inputs to the dynamic_execute stage
    reg        issue_we;
    reg [2:0]  issue_op;
    reg [4:0]  issue_rs1;
    reg [4:0]  issue_rs2;
    reg [4:0]  issue_rd;
    reg [31:0] reg_data1;
    reg [31:0] reg_data2;

    // Outputs from the dynamic_execute stage
    wire       pipeline_stall;

    // Instantiate the new dynamic execution engine
    dynamic_execute DUT (
        .clk(clk),
        .reset(reset),
        .issue_we(issue_we),
        .issue_op(issue_op),
        .issue_rs1(issue_rs1),
        .issue_rs2(issue_rs2),
        .issue_rd(issue_rd),
        .reg_data1(reg_data1),
        .reg_data2(reg_data2),
        .pipeline_stall(pipeline_stall)
    );

    // 10ns Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // The Test Sequence
    initial begin
        $display("=================================================");
        $display("   TOMASULO DYNAMIC SCHEDULER SIMULATION         ");
        $display("=================================================");

        // 1. Initialize and Reset
        issue_we = 0; issue_op = 0;
        issue_rs1 = 0; issue_rs2 = 0; issue_rd = 0;
        reg_data1 = 0; reg_data2 = 0;
        reset = 0;
        #15; 
        reset = 1;
        #10;

        // ---------------------------------------------------------
        // CYCLE 1: Issue Instruction 1 (Independent)
        // Operation: ADD x3, x1, x2 (Let's say x1=10, x2=20)
        // ---------------------------------------------------------
        $display("[Time %0t] Issuing INST 1: ADD x3, x1, x2", $time);
        issue_we  = 1;
        issue_op  = 3'b000; // ADD
        issue_rs1 = 5'd1; reg_data1 = 32'd10; // x1 = 10
        issue_rs2 = 5'd2; reg_data2 = 32'd20; // x2 = 20
        issue_rd  = 5'd3;                     // Destination is x3
        #10;

        // ---------------------------------------------------------
        // CYCLE 2: Issue Instruction 2 (Dependent on Inst 1!)
        // Operation: SUB x4, x3, x5 (Let's say x5=5)
        // ---------------------------------------------------------
        // Look closely here: We are asking for x3. The RAT will realize x3 
        // is busy being calculated by Inst 1, and will give this instruction 
        // a TAG instead of data!
        $display("[Time %0t] Issuing INST 2: SUB x4, x3, x5 (Dependent!)", $time);
        issue_we  = 1;
        issue_op  = 3'b001; // SUB
        issue_rs1 = 5'd3; reg_data1 = 32'd0;  // x3 (Data not ready, expecting a Tag!)
        issue_rs2 = 5'd5; reg_data2 = 32'd5;  // x5 = 5
        issue_rd  = 5'd4;                     // Destination is x4
        #10;

        // ---------------------------------------------------------
        // CYCLE 3: Stop issuing and watch the bus
        // ---------------------------------------------------------
        issue_we = 0;
        #20;

        $display("=================================================");
        $finish;
    end

    // Snooping the CDB to print results automatically
    always @(posedge clk) begin
        if (DUT.cdb_valid) begin
            $display("[Time %0t] CDB BROADCAST -> Tag: %0d, Result Value: %0d", 
                     $time, DUT.cdb_tag, DUT.cdb_value);
        end
    end

endmodule