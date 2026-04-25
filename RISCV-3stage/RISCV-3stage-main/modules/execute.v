`timescale 1ns/1ps

module execute
#(
    parameter [31:0] RESET = 32'h0000_0000
)
(
    input clk,
    input reset,

    input  [31:0] reg_rdata1,
    input  [31:0] reg_rdata2,
    input  [31:0] execute_imm,
    input  [31:0] pc,
    input  [31:0] fetch_pc,
    input         immediate_sel,
    input         mem_write,
    input         jal,
    input         jalr,
    input         lui,
    input         alu,
    input         branch,
    input         arithsubtype,
    input         mem_to_reg,
    input         stall_read,
    input         m_ext_i,    
    input         mandist_i,        

    input         predicted_taken_i, 
    input  [31:0] predicted_target_i,

    input  [4:0]  dest_reg_sel,
    input  [2:0]  alu_op,
    input  [1:0]  dmem_raddr,

    input         wb_branch_i,
    input         wb_branch_nxt_i,

    output [31:0] alu_operand1,
    output [31:0] alu_operand2,
    output [31:0] write_address,
    output        branch_stall,
    output        math_stall_o,      

    output reg [31:0] next_pc,
    output reg        branch_taken,

    output        bht_update_en,     
    output        actual_taken_o,    
    output        mispredicted_o,    

    output [31:0] wb_result,
    output        wb_mem_write,
    output        wb_alu_to_reg,
    output [4:0]  wb_dest_reg_sel,
    output        wb_branch,
    output        wb_branch_nxt,
    output        wb_mem_to_reg,
    output [1:0]  wb_read_address,
    output [2:0]  mem_alu_operation
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

reg  [31:0] ex_result;
wire [32:0] ex_result_subs;
wire [32:0] ex_result_subu;

assign alu_operand1 = reg_rdata1;
assign alu_operand2 = immediate_sel ? execute_imm : reg_rdata2;

assign ex_result_subs = {alu_operand1[31], alu_operand1} - {alu_operand2[31], alu_operand2};
assign ex_result_subu = {1'b0, alu_operand1} - {1'b0, alu_operand2};
assign write_address = alu_operand1 + execute_imm;

// --> NEW: Disable all static branch stalling since we predict!
assign branch_stall  = 1'b0; 

wire [31:0] m_result, d_result;
wire m_busy, m_done, d_busy, d_done;
wire is_mul = m_ext_i && (alu_op[2] == 1'b0);
wire is_div = m_ext_i && (alu_op[2] == 1'b1);
wire m_start = is_mul && !m_busy && !m_done;
wire d_start = is_div && !d_busy && !d_done;
assign math_stall_o = (is_mul && !m_done) || (is_div && !d_done);

wire ctrl_enable = !math_stall_o;
m_unit u_m_unit (
    .clk       (clk),
    .reset     (reset),
    .start     (m_start),
    .funct3    (alu_op),
    .operand_a (alu_operand1),
    .operand_b (alu_operand2),
    .result    (m_result),
    .busy      (m_busy),
    .done      (m_done)
);
d_unit u_d_unit (
    .clk       (clk),
    .reset     (reset),
    .start     (d_start),
    .funct3    (alu_op),
    .operand_a (alu_operand1),
    .operand_b (alu_operand2),
    .result    (d_result),
    .busy      (d_busy),
    .done      (d_done)
);
wire [31:0] mandist_res;
mandist_unit u_mandist (
    .operand_a (alu_operand1),
    .operand_b (alu_operand2),
    .result    (mandist_res)
);
// ----------------------------------------------------------------------------
// BRANCH PREDICTION EVALUATION LOGIC
// ----------------------------------------------------------------------------
reg actual_branch_condition;
wire is_branch_instr = (branch || jal || jalr);
assign bht_update_en  = is_branch_instr && !stall_read;
assign actual_taken_o = actual_branch_condition || jal || jalr;

reg [31:0] next_pc_calc;
assign mispredicted_o = is_branch_instr && (
    (actual_taken_o != predicted_taken_i) || 
    (actual_taken_o && (next_pc_calc != predicted_target_i)) 
);
always @(*) begin
    actual_branch_condition = 1'b0;
    
    // --> FIXED FALLBACK PC: Must be 'pc', not 'fetch_pc'
    next_pc_calc = pc + 4;
    if (jal)  next_pc_calc = pc + execute_imm;
    if (jalr) next_pc_calc = alu_operand1 + execute_imm;
    if (branch) begin
        case (alu_op)
            BEQ:  actual_branch_condition = (ex_result_subs == 0);
            BNE:  actual_branch_condition = (ex_result_subs != 0);
            BLT:  actual_branch_condition = ex_result_subs[32];
            BGE:  actual_branch_condition = !ex_result_subs[32];
            BLTU: actual_branch_condition = ex_result_subu[32];
            BGEU: actual_branch_condition = !ex_result_subu[32];
            default: actual_branch_condition = 1'b0;
        endcase
        if (actual_branch_condition) next_pc_calc = pc + execute_imm;
    end

    if (mispredicted_o) begin
        next_pc = next_pc_calc;
    end else begin
        next_pc = fetch_pc + 4;
    end
    
    branch_taken = mispredicted_o;
end

always @(*) begin
    case (1'b1)
        mem_write: ex_result = alu_operand2;
        jal, jalr: ex_result = pc + 4;
        lui:       ex_result = execute_imm;
        alu: begin
            if (mandist_i) begin
                ex_result = mandist_res;
            end else if (m_ext_i) begin
                ex_result = is_div ? d_result : m_result;
            end else begin
                case (alu_op)
                    ADD : ex_result = arithsubtype ? alu_operand1 - alu_operand2 : alu_operand1 + alu_operand2;
                    SLL : ex_result = alu_operand1 << alu_operand2[4:0];
                    SLT : ex_result = ex_result_subs[32];
                    SLTU: ex_result = ex_result_subu[32];
                    XOR : ex_result = alu_operand1 ^ alu_operand2;
                    SR  : ex_result = arithsubtype ? $signed(alu_operand1) >>> alu_operand2[4:0] : alu_operand1 >> alu_operand2[4:0]; 
                    OR  : ex_result = alu_operand1 | alu_operand2;
                    AND : ex_result = alu_operand1 & alu_operand2;
                    default: ex_result = 'hx;
                endcase
            end
        end
        default: ex_result = 'hx;
    endcase
end

ex_mem_wb_reg u_ex_mem_wb (
    .clk            (clk),
    .reset_n        (reset),
    .stall_n        (stall_read), 

    .ex_result      (ex_result),

    .mem_write      (mem_write && ctrl_enable),
    .alu_to_reg     ((alu | lui | jal | jalr | mem_to_reg) && ctrl_enable),
    .dest_reg_sel   (ctrl_enable ? dest_reg_sel : 5'h0),
    .branch_taken   (branch_taken && ctrl_enable),
    .mem_to_reg     (mem_to_reg && ctrl_enable),
    .read_address   (dmem_raddr),
    .alu_operation  (alu_op),

    .ex_mem_result        (wb_result),
    .ex_mem_mem_write     (wb_mem_write),
    .ex_mem_alu_to_reg    (wb_alu_to_reg),
    .ex_mem_dest_reg_sel  (wb_dest_reg_sel),
    .ex_mem_branch        (wb_branch),
    .ex_mem_branch_nxt    (wb_branch_nxt),
    .ex_mem_mem_to_reg    (wb_mem_to_reg),
    .ex_mem_read_address  (wb_read_address),
    .ex_mem_alu_operation (mem_alu_operation)
);

endmodule

module ex_mem_wb_reg (
    input        clk,
    input        reset_n,
    input        stall_n,

    input  [31:0] ex_result,
    input        mem_write,
    input        alu_to_reg,
    input  [4:0]  dest_reg_sel,
    input        branch_taken,
    input        mem_to_reg,
    input  [1:0]  read_address,
    input  [2:0]  alu_operation,

    output reg [31:0] ex_mem_result,
    output reg        ex_mem_mem_write,
    output reg        ex_mem_alu_to_reg,
    output reg [4:0]  ex_mem_dest_reg_sel,
    output reg        ex_mem_branch,
    output reg        ex_mem_branch_nxt,
    output reg        ex_mem_mem_to_reg,
    output reg [1:0]  ex_mem_read_address,
    output reg [2:0]  ex_mem_alu_operation
);
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        ex_mem_result        <= 32'h0;
        ex_mem_mem_write     <= 1'b0;
        ex_mem_alu_to_reg    <= 1'b0;
        ex_mem_dest_reg_sel  <= 5'h0;
        ex_mem_branch        <= 1'b0;
        ex_mem_branch_nxt    <= 1'b0;
        ex_mem_mem_to_reg    <= 1'b0;
        ex_mem_read_address  <= 2'h0;
        ex_mem_alu_operation <= 3'h0;
    end
    else if (!stall_n) begin
        ex_mem_result        <= ex_result;
        ex_mem_mem_write     <= mem_write;
        ex_mem_alu_to_reg    <= alu_to_reg;
        ex_mem_dest_reg_sel  <= dest_reg_sel;
        ex_mem_branch        <= branch_taken;
        ex_mem_branch_nxt    <= ex_mem_branch;
        ex_mem_mem_to_reg    <= mem_to_reg;
        ex_mem_read_address  <= read_address;
        ex_mem_alu_operation <= alu_operation;
    end
end

endmodule
