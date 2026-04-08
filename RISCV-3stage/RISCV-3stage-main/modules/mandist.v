module mandist_unit (
    input  [31:0] operand_a, // Packed {x1, y1}
    input  [31:0] operand_b, // Packed {x2, y2}
    output [31:0] result
);

    // 1. Unpack the 16-bit coordinates
    wire signed [15:0] x1 = operand_a[31:16];
    wire signed [15:0] y1 = operand_a[15:0];
    wire signed [15:0] x2 = operand_b[31:16];
    wire signed [15:0] y2 = operand_b[15:0];

    // 2. Calculate differences (extend to 17 bits to prevent overflow during subtraction)
    wire signed [16:0] dx = x1 - x2;
    wire signed [16:0] dy = y1 - y2;

    // 3. Absolute values using ternary logic (Behavioral Method)
    wire [15:0] abs_dx = (dx < 0) ? -dx : dx;
    wire [15:0] abs_dy = (dy < 0) ? -dy : dy;

    // 4. Final addition (Zero-extend the final 16-bit distance back to 32 bits for the register file)
    assign result = {16'b0, (abs_dx + abs_dy)}; 

endmodule