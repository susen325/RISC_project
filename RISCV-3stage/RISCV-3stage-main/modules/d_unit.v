`timescale 1ns/1ps

module d_unit (
    input  wire        clk,
    input  wire        reset,
    input  wire        start,
    input  wire [2:0]  funct3,     
    input  wire [31:0] operand_a,  
    input  wire [31:0] operand_b,  
    
    output wire [31:0] result, // CHANGED TO WIRE
    output wire        busy,   
    output wire        done    
);

    localparam DIV  = 3'b100;
    localparam DIVU = 3'b101;
    localparam REM  = 3'b110;
    localparam REMU = 3'b111;

    localparam IDLE   = 2'b00;
    localparam CALC   = 2'b01;
    localparam FINISH = 2'b10;

    reg [1:0]  state;
    reg [5:0]  count;
    reg [31:0] Q;           
    reg [31:0] R;           
    reg [31:0] divisor_abs; 
    
    reg negate_q, negate_r, div_by_zero, overflow;
    reg [2:0] op_type;
    reg [31:0] orig_dividend;

    wire [32:0] shift_R = {R[30:0], Q[31]};
    wire [32:0] diff    = shift_R - {1'b0, divisor_abs};

    assign busy = (state == CALC);
    assign done = (state == FINISH);

    // COMBINATIONAL OUTPUT: Instantly valid during FINISH state
    wire [31:0] final_q = div_by_zero ? 32'hFFFFFFFF : (overflow ? 32'h80000000 : (negate_q ? (~Q + 1) : Q));
    wire [31:0] final_r = div_by_zero ? orig_dividend  : (overflow ? 32'b0 : (negate_r ? (~R + 1) : R));
    assign result = (op_type == DIV || op_type == DIVU) ? final_q : final_r;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state         <= IDLE;
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
                    if (start) begin
                        state   <= CALC;
                        count   <= 6'd32;
                        op_type <= funct3;
                        orig_dividend <= operand_a;
                        div_by_zero <= (operand_b == 32'b0);
                        overflow    <= (operand_a == 32'h80000000) && (operand_b == 32'hFFFFFFFF) && (funct3 == DIV || funct3 == REM);

                        if (funct3 == DIV || funct3 == REM) begin
                            negate_q <= operand_a[31] ^ operand_b[31];
                            negate_r <= operand_a[31]; 
                            Q           <= operand_a[31] ? (~operand_a + 1) : operand_a;
                            divisor_abs <= operand_b[31] ? (~operand_b + 1) : operand_b;
                        end else begin
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
                            R <= shift_R[31:0];
                            Q <= {Q[30:0], 1'b0};
                        end else begin      
                            R <= diff[31:0];
                            Q <= {Q[30:0], 1'b1};
                        end
                        count <= count - 1;
                    end else state <= FINISH;
                end
                FINISH: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
