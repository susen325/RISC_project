`timescale 1ns/1ps

module alu(
    input [2:0] aluCntrl,
    input useF7,
    input inv,
    input loadStore,
    input [31:0] srcA,
    input [31:0] srcB,
    output reg [31:0] aluResult,
    output reg branchFlag
);

    reg zero;
    wire [2:0] aluCntrlint;
    wire [4:0] srcBlwr;

    assign srcBlwr = srcB[4:0];
    assign aluCntrlint = loadStore ? 3'b000 : aluCntrl;

    always @(*)
    begin
        // Default values to prevent unintended latches
        zero = 1'b0;
        branchFlag = 1'b0;
        aluResult = 32'b0;

        case (aluCntrlint)
            3'b000: // ADD / SUB
            begin
                if (useF7) begin
                    aluResult = ($signed(srcA) - $signed(srcB));
                    zero = ~(|aluResult);
                    branchFlag = inv ? ~zero : zero;
                end
                else begin
                    aluResult = ($signed(srcA) + $signed(srcB));
                end
            end

            3'b001: // SLL (Shift Left Logical)
                aluResult = srcA << srcBlwr;

            3'b010: // SLT (Set Less Than Signed)
            begin
                aluResult = ($signed(srcA) < $signed(srcB)) ? 32'd1 : 32'd0;
                branchFlag = inv ? ~aluResult[0] : aluResult[0];
            end

            3'b011: // SLTU (Set Less Than Unsigned)
            begin
                aluResult = (srcA < srcB) ? 32'd1 : 32'd0;
                branchFlag = inv ? ~aluResult[0] : aluResult[0];
            end

            3'b100: // XOR
                aluResult = srcA ^ srcB;

            3'b101: // SRL / SRA (Shift Right Logical / Arithmetic)
            begin
                if (useF7)
                    aluResult = $signed(srcA) >>> srcBlwr;
                else
                    aluResult = srcA >> srcBlwr;
            end

            3'b110: // OR
                aluResult = srcA | srcB;

            3'b111: // AND
                aluResult = srcA & srcB;

            default:
            begin
                aluResult = 32'b0;
                branchFlag = 1'b0;
            end
        endcase
    end

endmodule
