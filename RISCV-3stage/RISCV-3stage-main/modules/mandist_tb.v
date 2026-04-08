`timescale 1ns/1ps

module mandist_tb;

    // 1. Declare inputs as 'reg' and outputs as 'wire'
    reg  [31:0] operand_a;
    reg  [31:0] operand_b;
    wire [31:0] result;

    // 2. Instantiate the module under test (UUT)
    mandist_unit uut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .result(result)
    );

    // Helper variables to easily set coordinates before packing
    reg signed [15:0] x1, y1, x2, y2;

    // 3. Apply Test Vectors
    initial begin
        $display("Starting MANDIST Accelerator Testbench...\n");

        // ---------------------------------------------------------
        // Test 1: Simple Positive Distance
        // P1(10, 5) to P2(2, 1) -> |10-2| + |5-1| = 8 + 4 = 12
        // ---------------------------------------------------------
        x1 = 16'd10; y1 = 16'd5;
        x2 = 16'd2;  y2 = 16'd1;
        
        // Pack the 16-bit coordinates into the 32-bit operands
        operand_a = {x1, y1};
        operand_b = {x2, y2};
        #10; // Wait 10ns for combinational logic to settle
        $display("Test 1 - P1(10,5), P2(2,1):   Distance = %d (Expected: 12)", result);

        // ---------------------------------------------------------
        // Test 2: Negative Differences (Tests the Absolute Value)
        // P1(-5, -10) to P2(5, 20) -> |-5-5| + |-10-20| = 10 + 30 = 40
        // ---------------------------------------------------------
        x1 = -16'd5;  y1 = -16'd10;
        x2 =  16'd5;  y2 =  16'd20;
        operand_a = {x1, y1};
        operand_b = {x2, y2};
        #10;
        $display("Test 2 - P1(-5,-10), P2(5,20): Distance = %d (Expected: 40)", result);

        // ---------------------------------------------------------
        // Test 3: Zero Distance (Same Point)
        // P1(7, -3) to P2(7, -3) -> |7-7| + |-3 - (-3)| = 0
        // ---------------------------------------------------------
        x1 =  16'd7; y1 = -16'd3;
        x2 =  16'd7; y2 = -16'd3;
        operand_a = {x1, y1};
        operand_b = {x2, y2};
        #10;
        $display("Test 3 - P1(7,-3), P2(7,-3):   Distance = %d (Expected: 0)", result);

        // ---------------------------------------------------------
        // Test 4: Mixed Greater/Lesser Coordinates
        // P1(0, 15) to P2(10, 0) -> |0-10| + |15-0| = 10 + 15 = 25
        // ---------------------------------------------------------
        x1 = 16'd0;  y1 = 16'd15;
        x2 = 16'd10; y2 = 16'd0;
        operand_a = {x1, y1};
        operand_b = {x2, y2};
        #10;
        $display("Test 4 - P1(0,15), P2(10,0):   Distance = %d (Expected: 25)", result);

        $display("\nTestbench complete.");
        $finish; // End the simulation
    end

endmodule