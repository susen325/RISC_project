`timescale 1ns/1ps

module IF_ID
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input                   clk,
    input                   reset,
    input                   stall,
    output reg              exception,

    // Instruction memory interface
    input                   inst_mem_is_valid,
    input  [31:0]           inst_mem_read_data,

    // Signals previously read from pipe
    input                   stall_read_i,
    input  [31:0]           inst_fetch_pc,
    input  [31:0]           instruction_i,

    // WB-stage signals (passed in)
    input                   wb_stall,
    input                   wb_alu_to_reg,
    input                   wb_mem_to_reg,
    input  [4:0]            wb_dest_reg_sel,
    input  [31:0]           wb_result,
    input  [31:0]           wb_read_data,
    input                   flush_i,

    // Instruction memory address info
    input  [1:0]            inst_mem_offset,
    
    // To EX (Pipeline Register Outputs)
    output [31:0] execute_immediate_w,
    output        immediate_sel_w,
    output        alu_w,
    output        lui_w,
    output        jal_w,
    output        jalr_w,
    output        branch_w,
    output        mem_write_w,
    output        mem_to_reg_w,
    output        arithsubtype_w,
    output [31:0] pc_w,
    output [4:0]  src1_select_w,
    output [4:0]  src2_select_w,
    output [4:0]  dest_reg_sel_w,
    output [2:0]  alu_operation_w,
    output        illegal_inst_w,
    output [31:0] instruction_o,
    output        m_ext_w,        
    output        mandist_w      
);

// ============================================================================
// THE NUCLEAR FIX: Opcodes safely hardcoded directly into the module
// ============================================================================
`ifndef OPCODES_DEF
`define OPCODES_DEF
`define OPCODE      6:0
`define FUNC3       14:12
`define FUNCT7      31:25
`define SUBTYPE     30
`define RD          11:7
`define RS1         19:15
`define RS2         24:20
`endif

localparam  [31: 0] NOP     = 32'h0000_0013;

localparam  [ 6: 0] LUI     = 7'b0110111,
                    JAL     = 7'b1101111,
                    JALR    = 7'b1100111,
                    BRANCH  = 7'b1100011,
                    LOAD    = 7'b0000011,
                    STORE   = 7'b0100011,
                    ARITHI  = 7'b0010011,
                    ARITHR  = 7'b0110011,
                    CUSTOM0 = 7'b0001011;

localparam  [ 6: 0] M_EXT   = 7'b0000001;

localparam  [ 2: 0] BEQ     = 3'b000,
                    BNE     = 3'b001,
                    BLT     = 3'b100,
                    BGE     = 3'b101,
                    BLTU    = 3'b110,
                    BGEU    = 3'b111;

localparam  [ 2: 0] LB      = 3'b000,
                    LH      = 3'b001,
                    LW      = 3'b010,
                    LBU     = 3'b100,
                    LHU     = 3'b101;

localparam  [ 2: 0] SB      = 3'b000,
                    SH      = 3'b001,
                    SW      = 3'b010;
                    
localparam  [ 2: 0] ADD     = 3'b000,
                    SLL     = 3'b001,
                    SLT     = 3'b010,
                    SLTU    = 3'b011,
                    XOR     = 3'b100,
                    SR      = 3'b101,
                    OR      = 3'b110,
                    AND     = 3'b111;

localparam  [ 2: 0] MUL     = 3'b000,
                    MULH    = 3'b001,
                    MULHSU  = 3'b010,
                    MULHU   = 3'b011,
                    DIV     = 3'b100,
                    DIVU    = 3'b101,
                    REM     = 3'b110,
                    REMU    = 3'b111;

localparam  [ 2: 0] MANDIST_F3 = 3'b000;
// ============================================================================

reg  [31:0] immediate;
reg         illegal_inst;

assign instruction_o = stall_read_i ? NOP : inst_mem_read_data;

always @(posedge clk or negedge reset) begin
    if (!reset)
        exception <= 1'b0;
    else if (illegal_inst || inst_mem_offset != 2'b00)
        exception <= 1'b1;
    else
        exception <= 1'b0;
end

always @(*) begin
    immediate    = 32'h0;
    illegal_inst = 1'b0;

    case (instruction_i[`OPCODE])
        JALR  : immediate = {{20{instruction_i[31]}}, instruction_i[31:20]};
        BRANCH: immediate = {{20{instruction_i[31]}}, instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
        LOAD  : immediate = {{20{instruction_i[31]}}, instruction_i[31:20]};
        STORE : immediate = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
        ARITHI: immediate =
                 (instruction_i[`FUNC3] == SLL ||
                  instruction_i[`FUNC3] == SR)
                 ? {27'b0, instruction_i[24:20]}
                 : {{20{instruction_i[31]}}, instruction_i[31:20]};
        ARITHR, CUSTOM0: immediate = 32'h0; 
        LUI   : immediate = {instruction_i[31:12], 12'b0};
        JAL   : immediate = {{12{instruction_i[31]}}, instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
        default: illegal_inst = 1'b1;
    endcase
end

wire m_ext_inst = (instruction_i[`OPCODE] == ARITHR) && 
                  (instruction_i[`FUNCT7] == M_EXT);
                  
wire mandist_inst = (instruction_i[`OPCODE] == CUSTOM0);

id_ex_reg u_id_ex (
    .clk            (clk),
    .reset          (reset),
    .stall_n        (stall_read_i),
    .flush          (flush_i),

    .immediate_i    (immediate),
    .immediate_sel_i(
        (instruction_i[`OPCODE] == JALR)  || (instruction_i[`OPCODE] == LOAD)  ||
        (instruction_i[`OPCODE] == ARITHI)
    ),
    .alu_i          (
        (instruction_i[`OPCODE] == ARITHI) || 
        (instruction_i[`OPCODE] == ARITHR) ||
        (instruction_i[`OPCODE] == CUSTOM0) 
    ),
    .lui_i          (instruction_i[`OPCODE] == LUI),
    .jal_i          (instruction_i[`OPCODE] == JAL),
    .jalr_i         (instruction_i[`OPCODE] == JALR),
    .branch_i       (instruction_i[`OPCODE] == BRANCH),
    .mem_write_i    (instruction_i[`OPCODE] == STORE),
    .mem_to_reg_i   (instruction_i[`OPCODE] == LOAD),
    .arithsubtype_i (
        instruction_i[`SUBTYPE] &&
        !(instruction_i[`OPCODE] == ARITHI &&
          instruction_i[`FUNC3] == ADD)
    ),
    .pc_i           (inst_fetch_pc),
    .src1_sel_i     (instruction_i[`RS1]),
    .src2_sel_i     (instruction_i[`RS2]),
    .dest_reg_sel_i (instruction_i[`RD]),
    .alu_op_i       (instruction_i[`FUNC3]),
    .illegal_inst_i (illegal_inst),
    .m_ext_i        (m_ext_inst),         
    .mandist_i      (mandist_inst),       

    .execute_immediate_o (execute_immediate_w),
    .immediate_sel_o     (immediate_sel_w),
    .alu_o               (alu_w),
    .lui_o               (lui_w),
    .jal_o               (jal_w),
    .jalr_o              (jalr_w),
    .branch_o            (branch_w),
    .mem_write_o         (mem_write_w),
    .mem_to_reg_o        (mem_to_reg_w),
    .arithsubtype_o      (arithsubtype_w),
    .pc_o                (pc_w),
    .src1_sel_o          (src1_select_w),
    .src2_sel_o          (src2_select_w),
    .dest_reg_sel_o      (dest_reg_sel_w),
    .alu_op_o            (alu_operation_w),
    .illegal_inst_o      (illegal_inst_w),
    .m_ext_o             (m_ext_w),             
    .mandist_o           (mandist_w)            
);
endmodule

module id_ex_reg (
    input         clk,
    input         reset,
    input         stall_n,
    input         flush, 

    input  [31:0] immediate_i,
    input         immediate_sel_i,
    input         alu_i,
    input         lui_i,
    input         jal_i,
    input         jalr_i,
    input         branch_i,
    input         mem_write_i,
    input         mem_to_reg_i,
    input         arithsubtype_i,
    input  [31:0] pc_i,
    input  [4:0]  src1_sel_i,
    input  [4:0]  src2_sel_i,
    input  [4:0]  dest_reg_sel_i,
    input  [2:0]  alu_op_i,
    input         illegal_inst_i,
    input         m_ext_i,             
    input         mandist_i,           

    output reg [31:0] execute_immediate_o,
    output reg        immediate_sel_o,
    output reg        alu_o,
    output reg        lui_o,
    output reg        jal_o,
    output reg        jalr_o,
    output reg        branch_o,
    output reg        mem_write_o,
    output reg        mem_to_reg_o,
    output reg        arithsubtype_o,
    output reg [31:0] pc_o,
    output reg [4:0]  src1_sel_o,
    output reg [4:0]  src2_sel_o,
    output reg [4:0]  dest_reg_sel_o,
    output reg [2:0]  alu_op_o,
    output reg        illegal_inst_o,
    output reg        m_ext_o,               
    output reg        mandist_o
);

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        execute_immediate_o <= 32'h0;
        immediate_sel_o     <= 1'b0;
        alu_o               <= 1'b0;
        lui_o               <= 1'b0;
        jal_o               <= 1'b0;
        jalr_o              <= 1'b0;
        branch_o            <= 1'b0;
        mem_write_o         <= 1'b0;
        mem_to_reg_o        <= 1'b0;
        arithsubtype_o      <= 1'b0;
        pc_o                <= 32'h0;
        src1_sel_o          <= 5'h0;
        src2_sel_o          <= 5'h0;
        dest_reg_sel_o      <= 5'h0;
        alu_op_o            <= 3'h0;
        illegal_inst_o      <= 1'b0;
        m_ext_o             <= 1'b0;       
        mandist_o           <= 1'b0;   
    end
    else if (flush) begin 
        execute_immediate_o <= 32'h0;
        immediate_sel_o     <= 1'b0;
        alu_o               <= 1'b0;
        lui_o               <= 1'b0;
        jal_o               <= 1'b0;
        jalr_o              <= 1'b0;
        branch_o            <= 1'b0; 
        mem_write_o         <= 1'b0; 
        mem_to_reg_o        <= 1'b0;
        arithsubtype_o      <= 1'b0;
        pc_o                <= 32'h0;
        src1_sel_o          <= 5'h0;
        src2_sel_o          <= 5'h0;
        dest_reg_sel_o      <= 5'h0;
        alu_op_o            <= 3'h0;
        illegal_inst_o      <= 1'b0;
        m_ext_o             <= 1'b0;       
        mandist_o           <= 1'b0;  
    end
    else if (!stall_n) begin
        execute_immediate_o <= immediate_i;
        immediate_sel_o     <= immediate_sel_i;
        alu_o               <= alu_i;
        lui_o               <= lui_i;
        jal_o               <= jal_i;
        jalr_o              <= jalr_i;
        branch_o            <= branch_i;
        mem_write_o         <= mem_write_i;
        mem_to_reg_o        <= mem_to_reg_i;
        arithsubtype_o      <= arithsubtype_i;
        pc_o                <= pc_i;
        src1_sel_o          <= src1_sel_i;
        src2_sel_o          <= src2_sel_i;
        dest_reg_sel_o      <= dest_reg_sel_i;
        alu_op_o            <= alu_op_i;
        illegal_inst_o      <= illegal_inst_i;
        m_ext_o             <= m_ext_i;    
        mandist_o           <= mandist_i; 
    end
end

endmodule
