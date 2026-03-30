`timescale 1ns/1ps

module d_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [2:0]  funct3,     // Used to decode DIV, DIVU, REM, REMU
    input  wire [31:0] operand_a,  // Dividend
    input  wire [31:0] operand_b,  // Divisor
    
    output reg  [31:0] result,
    output reg         busy,
    output reg         done
);

    // RV32M funct3 codes for Division/Remainder
    localparam DIV  = 3'b100;
    localparam DIVU = 3'b101;
    localparam REM  = 3'b110;
    localparam REMU = 3'b111;

    // FSM States
    localparam IDLE   = 2'b00;
    localparam CALC   = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0]  state;
    reg [5:0]  count;
    
    reg [31:0] Q;           // Quotient register
    reg [31:0] R;           // Remainder register
    reg [31:0] divisor_abs; // Absolute value of divisor
    
    // Flags for final sign correction and edge cases
    reg negate_q;
    reg negate_r;
    reg div_by_zero;
    reg overflow;
    reg [2:0] op_type;
    reg [31:0] orig_dividend;

    // Combinational subtraction for the restoring algorithm
    wire [32:0] shift_R = {R[30:0], Q[31]};
    wire [32:0] diff    = shift_R - {1'b0, divisor_abs};

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state         <= IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;
            result        <= 32'b0;
            count         <= 6'b0;
            Q             <= 32'b0;
            R             <= 32'b0;
            divisor_abs   <= 32'b0;
            negate_q      <= 1'b0;
            negate_r      <= 1'b0;
            div_by_zero   <= 1'b0;
            overflow      <= 1'b0;
            op_type       <= 3'b0;
            orig_dividend <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy    <= 1'b1;
                        state   <= CALC;
                        count   <= 6'd32;
                        op_type <= funct3;
                        orig_dividend <= operand_a;
                        
                        // Edge Case Detection
                        div_by_zero <= (operand_b == 32'b0);
                        overflow    <= (operand_a == 32'h80000000) && (operand_b == 32'hFFFFFFFF) && (funct3 == DIV || funct3 == REM);

                        // Determine signs for Signed Operations (DIV, REM)
                        if (funct3 == DIV || funct3 == REM) begin
                            negate_q <= operand_a[31] ^ operand_b[31];
                            negate_r <= operand_a[31]; // In RISC-V, remainder sign matches dividend
                            
                            Q           <= operand_a[31] ? (~operand_a + 1) : operand_a;
                            divisor_abs <= operand_b[31] ? (~operand_b + 1) : operand_b;
                        end else begin
                            // Unsigned Operations (DIVU, REMU)
                            negate_q <= 1'b0;
                            negate_r <= 1'b0;
                            Q           <= operand_a;
                            divisor_abs <= operand_b;
                        end
                        
                        R <= 32'b0;
                    end
                end

                CALC: begin
                    if (count > 0) begin
                        if (diff[32]) begin 
                            // Divisor is larger: Restore (do not subtract)
                            R <= shift_R[31:0];
                            Q <= {Q[30:0], 1'b0};
                        end else begin      
                            // Divisor fits: Subtract
                            R <= diff[31:0];
                            Q <= {Q[30:0], 1'b1};
                        end
                        count <= count - 1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    reg [31:0] final_q;
                    reg [31:0] final_r;

                    // 1. Handle Edge Cases
                    if (div_by_zero) begin
                        final_q = 32'hFFFFFFFF;
                        final_r = orig_dividend;
                    end else if (overflow) begin
                        final_q = 32'h80000000;
                        final_r = 32'b0;
                    end else begin
                        // 2. Apply Two's Complement if necessary
                        final_q = negate_q ? (~Q + 1) : Q;
                        final_r = negate_r ? (~R + 1) : R;
                    end

                    // 3. Route Output based on Instruction
                    if (op_type == DIV || op_type == DIVU) begin
                        result <= final_q;
                    end else begin // REM, REMU
                        result <= final_r;
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