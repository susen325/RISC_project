`timescale 1ns/1ps

module tb_mandist;

    reg  [31:0] op_a;
    reg  [31:0] op_b;
    wire [31:0] result;

    // Instantiate the custom hardware accelerator
    mandist_unit DUT (
        .operand_a(op_a),
        .operand_b(op_b),
        .result(result)
    );

    initial begin
        $display("=================================================");
        $display("   MANDIST Custom Hardware Accelerator Test      ");
        $display("=================================================");

        // Test 1: Standard Positive Coordinates
        // P1: (10, 5) -> P2: (2, 2)
        // Distance: |10 - 2| + |5 - 2| = 8 + 3 = 11
        op_a = {16'd10, 16'd5};
        op_b = {16'd2,  16'd2};
        #10;
        $display("Test 1: P1(10,5) to P2(2,2)     | Expected: 11 | Actual: %0d", result);

        // Test 2: Negative Coordinates
        // P1: (-5, -5) -> P2: (-10, -2)
        // Distance: |-5 - -10| + |-5 - -2| = 5 + 3 = 8
        op_a = {16'hFFFB, 16'hFFFB}; // -5 is FFFB in 16-bit hex
        op_b = {16'hFFF6, 16'hFFFE}; // -10 is FFF6, -2 is FFFE
        #10;
        $display("Test 2: P1(-5,-5) to P2(-10,-2) | Expected: 8  | Actual: %0d", result);

        // Test 3: Crossing the Origin (Proves 17-bit extension works)
        // P1: (-100, 50) -> P2: (100, -50)
        // Distance: |-100 - 100| + |50 - -50| = 200 + 100 = 300
        op_a = {16'hFF9C, 16'd50};   // -100 is FF9C
        op_b = {16'd100,  16'hFFCE}; // -50 is FFCE
        #10;
        $display("Test 3: P1(-100,50) to P2(100,-50)| Expected: 300| Actual: %0d", result);

        $display("=================================================");
        $finish;
    end

endmodule
