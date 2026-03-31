`timescale 1ns/1ps

module m_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [2:0]  funct3,     // Used to decode MUL, MULH, MULHSU, MULHU
    input  wire [31:0] operand_a,
    input  wire [31:0] operand_b,
    
    output reg  [31:0] result,
    output reg         busy,
    output reg         done
);

    // RV32M funct3 codes for Multiplication
    localparam MUL    = 3'b000;
    localparam MULH   = 3'b001;
    localparam MULHSU = 3'b010;
    localparam MULHU  = 3'b011;

    // FSM States
    localparam IDLE   = 2'b00;
    localparam CALC   = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0]  state;
    reg [5:0]  count;
    reg [63:0] accumulator;
    reg [31:0] multiplicand;
    reg        invert_result;
    reg [2:0]  op_type;
    
    // Moved declarations here for strict Verilog compliance
    reg a_is_neg;
    reg b_is_neg;
    reg [63:0] final_prod;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state         <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            result        <= 32'b0;
            count         <= 6'b0;
            accumulator   <= 64'b0;
            multiplicand  <= 32'b0;
            invert_result <= 1'b0;
            op_type       <= 3'b0;
            a_is_neg      <= 1'b0;
            b_is_neg      <= 1'b0;
            final_prod    <= 64'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        state   <= CALC;
                        count   <= 6'd32;
                        op_type <= funct3;
                        
                        // Determine signs based on instruction
                        a_is_neg = (funct3 == MUL || funct3 == MULH || funct3 == MULHSU) && operand_a[31];
                        b_is_neg = (funct3 == MUL || funct3 == MULH) && operand_b[31];
                        
                        invert_result <= a_is_neg ^ b_is_neg;
                        
                        // Take absolute values for unsigned shift-and-add
                        accumulator[31:0]  <= a_is_neg ? (~operand_a + 1) : operand_a;
                        accumulator[63:32] <= 32'b0;
                        multiplicand       <= b_is_neg ? (~operand_b + 1) : operand_b;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        if (accumulator[0]) begin
                            // Add multiplicand to the upper half, shift right
                            accumulator <= { (accumulator[63:32] + multiplicand), accumulator[31:1] };
                        end else begin
                            // Just shift right
                            accumulator <= { 1'b0, accumulator[63:1] };
                        end
                        count <= count - 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Apply two's complement if the final result should be negative
                    final_prod = invert_result ? (~accumulator + 1) : accumulator;

                    // Select output based on instruction type
                    if (op_type == MUL) begin
                        result <= final_prod[31:0];
                    end else begin
                        result <= final_prod[63:32]; // MULH, MULHSU, MULHU
                    end

                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
