`timescale 1ns/1ps

module controlUnit (
    input [4:0] op,
    input [2:0] funct3,
    input funct7_6,
    output reg regWrite,
    output reg memWrite,
    output reg branch,
    output reg jump,
    output reg [2:0] aluCntrl,
    output reg [2:0] immCntrl,
    output reg [1:0] aluSrcA,
    output wire aluSrcB,
    output reg inv,
    output reg useF7,
    output reg [1:0] regSrc,
    output wire pcTargetSrc,
    output reg loadStore
);

    // Opcode Parameters
    parameter [4:0] OPCODE_RTYPE      = 5'b01100;
    parameter [4:0] OPCODE_IARTHTYPE  = 5'b00100;
    parameter [4:0] OPCODE_LOADTYPE   = 5'b00000;
    parameter [4:0] OPCODE_STYPE      = 5'b01000;
    parameter [4:0] OPCODE_BTYPE      = 5'b11000;
    parameter [4:0] OPCODE_AUIPC      = 5'b00101;
    parameter [4:0] OPCODE_LUI        = 5'b01101;
    parameter [4:0] OPCODE_JAL        = 5'b11011;
    parameter [4:0] OPCODE_JALR       = 5'b11001;

    // Immediate Type Parameters
    parameter [2:0] IMM_TYPE_DEFAULT  = 3'b000;
    parameter [2:0] IMM_TYPE_SHAMT    = 3'b001;
    parameter [2:0] IMM_TYPE_I        = 3'b010;
    parameter [2:0] IMM_TYPE_S        = 3'b011;
    parameter [2:0] IMM_TYPE_B        = 3'b100;
    parameter [2:0] IMM_TYPE_U        = 3'b101;
    parameter [2:0] IMM_TYPE_J        = 3'b110;

    // Source Selection Parameters
    parameter [1:0] ALU_SRC           = 2'b00;
    parameter [1:0] MEM_SRC           = 2'b01;
    parameter [1:0] PC_SRC            = 2'b10;

    parameter [1:0] RS1               = 2'b00;
    parameter [1:0] ZERO              = 2'b11;
    parameter [1:0] PC                = 2'b01;

    // Continuous Assignments
    assign aluSrcB = (~branch) & (|immCntrl);
    assign pcTargetSrc = ((jump) & (!op[1])) & (~branch);

    // Combinational Logic Block
    always @(*)
    begin
        // Default assignments to avoid latches
        regSrc = ALU_SRC;
        useF7 = 0;
        loadStore = 0;
        regWrite = 0;
        memWrite = 0;
        branch = 0;
        jump = 0;
        aluCntrl = 3'b0;
        immCntrl = IMM_TYPE_DEFAULT;
        inv = 0;
        aluSrcA = RS1;

        case (op)
            OPCODE_RTYPE, OPCODE_IARTHTYPE:
            begin
                aluCntrl = funct3;
                useF7 = op[3] ? funct7_6 : ((funct3[0]) && (funct3[2]) && (~funct3[1]) && funct7_6);
                inv = 0;
                regWrite = 1;
                memWrite = 0;
                branch = 0;
                jump = 0;
                immCntrl = op[3] ? IMM_TYPE_DEFAULT : ((~funct3[1] & funct3[0]) ? IMM_TYPE_SHAMT : IMM_TYPE_I);
                regSrc = ALU_SRC;
                aluSrcA = RS1;
            end

            OPCODE_STYPE:
            begin
                aluCntrl = funct3;
                loadStore = 1;
                inv = 0;
                useF7 = 0;
                regWrite = 0;
                memWrite = 1;
                branch = 0;
                jump = 0;
                immCntrl = IMM_TYPE_S;
                aluSrcA = RS1;
            end

            OPCODE_BTYPE:
            begin
                aluCntrl = {1'b0, funct3[2:1]};
                useF7 = ~(|funct3[2:1]);
                regWrite = 0;
                memWrite = 0;
                branch = 1;
                jump = 0;
                immCntrl = IMM_TYPE_B;
                inv = funct3[0];
                aluSrcA = RS1;
            end

            OPCODE_LOADTYPE:
            begin
                aluCntrl = funct3;
                loadStore = 1;
                regWrite = 1;
                memWrite = 0;
                branch = 0;
                jump = 0;
                immCntrl = IMM_TYPE_I;
                inv = 0;
                regSrc = MEM_SRC;
                aluSrcA = RS1;
            end

            OPCODE_LUI:
            begin
                aluCntrl = 3'b0;
                regWrite = 1;
                memWrite = 0;
                branch = 0;
                jump = 0;
                immCntrl = IMM_TYPE_U;
                inv = 0;
                regSrc = ALU_SRC;
                aluSrcA = ZERO;
            end

            OPCODE_AUIPC:
            begin
                aluCntrl = 3'b0;
                regWrite = 1;
                memWrite = 0;
                branch = 0;
                jump = 0;
                immCntrl = IMM_TYPE_U;
                inv = 0;
                regSrc = ALU_SRC;
                aluSrcA = PC;
            end

            OPCODE_JAL, OPCODE_JALR:
            begin
                aluCntrl = 3'b0;
                regWrite = 1;
                memWrite = 0;
                branch = 0;
                jump = 1;
                immCntrl = op[1] ? IMM_TYPE_J : IMM_TYPE_I;
                inv = 0;
                regSrc = PC_SRC;
                aluSrcA = RS1;
            end

            default:
            begin
                // Values already set by defaults above
            end
        endcase
    end

endmodule
