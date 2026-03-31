`timescale 1ns/1ps

module m_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [2:0]  funct3,     
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    
    output wire [31:0] result,  // CHANGED TO WIRE
    output wire        busy,
    output wire        done
);

    localparam MUL    = 3'b000;
    localparam MULH   = 3'b001;
    localparam MULHSU = 3'b010;
    localparam MULHU  = 3'b011;

    localparam IDLE   = 2'b00;
    localparam CALC   = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0]  state;
    reg [5:0]  count;
    reg [63:0] accumulator;
    reg [31:0] multiplicand;
    reg        invert_result;
    reg [2:0]  op_type;
    reg a_is_neg, b_is_neg;

    assign busy = (state == CALC);
    assign done = (state == FINISH);

    // COMBINATIONAL OUTPUT: Instantly valid during FINISH state
    wire [63:0] final_prod = invert_result ? (~accumulator + 1) : accumulator;
    assign result = (op_type == MUL) ? final_prod[31:0] : final_prod[63:32];

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state         <= IDLE;
            count         <= 6'b0;
            accumulator   <= 64'b0;
            multiplicand  <= 32'b0;
            invert_result <= 1'b0;
            op_type       <= 3'b0;
            a_is_neg      <= 1'b0;
            b_is_neg      <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state   <= CALC;
                        count   <= 6'd32;
                        op_type <= funct3;
                        
                        a_is_neg = (funct3 == MUL || funct3 == MULH || funct3 == MULHSU) && operand_a[31];
                        b_is_neg = (funct3 == MUL || funct3 == MULH) && operand_b[31];
                        invert_result <= a_is_neg ^ b_is_neg;
                        
                        accumulator[31:0]  <= a_is_neg ? (~operand_a + 1) : operand_a;
                        accumulator[63:32] <= 32'b0;
                        multiplicand       <= b_is_neg ? (~operand_b + 1) : operand_b;
                    end
                end
                CALC: begin
                    if (count > 0) begin
                        if (accumulator[0]) accumulator <= { (accumulator[63:32] + multiplicand), accumulator[31:1] };
                        else accumulator <= { 1'b0, accumulator[63:1] };
                        count <= count - 1;
                    end else state <= FINISH;
                end
                FINISH: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
