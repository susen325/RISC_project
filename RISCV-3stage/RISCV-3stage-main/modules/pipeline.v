// ----------------------------------------------------------------------------
// Pipeline Module
// ----------------------------------------------------------------------------
`include "IF_ID.v"
`include "execute.v"
`include "memory.v"
`include "wb.v"

module pipe
#(
    parameter [31:0]            RESET = 32'h0000_0000
)
(
    input                       clk,
    input                       reset,
    input                       stall,
    output                      exception,  
    output [31:0]               pc_out,

    output      [31: 0]         inst_mem_address,
    input                       inst_mem_is_valid,
    input       [31: 0]         inst_mem_read_data,
    output                      inst_mem_is_ready,

    output      [31: 0]         dmem_read_address,
    output                      dmem_read_ready,
    input       [31: 0]         dmem_read_data_temp,
    input                       dmem_read_valid,
    output      [31: 0]         dmem_write_address,
    output                      dmem_write_ready,
    output      [31: 0]         dmem_write_data,
    output      [ 3: 0]         dmem_write_byte,
    input                       dmem_write_valid,
    output      [31: 0]         next_pc_pipe,
    output      [31: 0]         inst_fetch_pc_pipe
);
    
    wire      [31: 0] dmem_read_data;
    wire        [1:0] dmem_read_offset;
    wire              dmem_read_valid_checker;
    
    reg       [31: 0] immediate;
    wire              immediate_sel;
    wire       [ 4: 0] src1_select;
    wire       [ 4: 0] src2_select;
    wire       [ 4: 0] dest_reg_sel;
    wire       [ 2: 0] alu_operation;
    wire              arithsubtype;
    wire              mem_write;
    wire              mem_to_reg;
    wire              illegal_inst;

    wire       [31: 0] execute_immediate;
    wire              alu;
    wire              lui;
    wire              jal;
    wire              jalr;
    wire              branch;
    reg               stall_read;
    wire      [31: 0] instruction;
    wire      [31: 0] reg_rdata2 ;
    wire      [31: 0] reg_rdata1;
    reg       [31: 0] regs [31: 1];

    wire        [31: 0] pc;
    // FIXED: Replaced the generic wire with the new 1-cycle delayed register!
    reg         [31: 0] if_id_pc; 
    reg         [31: 0] fetch_pc;  

    wire    wb_stall_first;
    wire    wb_stall_second;
    wire    wb_stall;        
    wire    m_ext;     
    wire    mandist_w;     
    wire    math_stall;     
    
    wire         [31: 0] next_pc;
    wire        [31: 0] write_address;
    wire                branch_taken;
    wire                branch_stall;
    wire        [31:0]  alu_operand1;
    wire        [31:0]  alu_operand2;

    wire                wb_alu_to_reg;
    wire        [31: 0] wb_result;
    wire        [ 2: 0] wb_alu_operation;
    wire                wb_mem_write;
    wire                wb_mem_to_reg;
    wire        [ 4: 0] wb_dest_reg_sel;
    wire                wb_branch;
    wire                wb_branch_nxt;
    wire        [31: 0] wb_write_address;
    wire        [ 1: 0] wb_read_address;
    wire        [ 3: 0] wb_write_byte;
    wire        [31: 0] wb_write_data;
    wire        [31: 0] wb_read_data;

assign dmem_write_address       = wb_write_address;     
assign dmem_read_address        = alu_operand1 + execute_immediate; 
assign dmem_read_offset         = dmem_read_address[1:0];
assign dmem_read_ready          = mem_to_reg;   
assign dmem_write_ready         = wb_mem_write;     
assign dmem_write_data          = wb_write_data;    
assign dmem_write_byte          = wb_write_byte;    
assign dmem_read_data           = dmem_read_data_temp;      
assign dmem_read_valid_checker  = 1'b1;

// ---------------------------------------------------------
// HARDWARE HAZARD DETECTION UNIT (HDU)
// ---------------------------------------------------------
wire [4:0] fetch_rs1 = inst_mem_read_data[19:15];
wire [4:0] fetch_rs2 = inst_mem_read_data[24:20];

wire load_use_hazard = mem_to_reg && (dest_reg_sel != 5'd0) &&
                       ((dest_reg_sel == fetch_rs1) || (dest_reg_sel == fetch_rs2));

wire flush_ex = branch_taken | load_use_hazard;
reg  flush_id;

always @(posedge clk or negedge reset) begin
    if (!reset) flush_id <= 1'b0;
    else flush_id <= branch_taken;
end

// ---------------------------------------------------------
// GLOBAL PIPELINE FREEZE & SKID BUFFER
// ---------------------------------------------------------
wire    pipe_freeze = stall_read || math_stall || load_use_hazard;

reg [31:0] saved_instr;
reg        is_saved;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        is_saved <= 1'b0;
        saved_instr <= 32'h0;
    end else if (pipe_freeze && !is_saved) begin
        saved_instr <= inst_mem_read_data; 
        is_saved <= 1'b1;
    end else if (!pipe_freeze) begin
        is_saved <= 1'b0;
    end
end
wire [31:0] safe_inst_mem_read_data = is_saved ? saved_instr : inst_mem_read_data;

// ---------------------------------------------------------
// FIXED: THE NEW IF/ID PC REGISTER
// ---------------------------------------------------------
// This delays the PC by exactly 1 clock cycle to match the BRAM.
// If the pipeline freezes, it holds its breath so the instruction doesn't lose its address.
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        if_id_pc <= RESET;
    end else if (!pipe_freeze) begin
        if_id_pc <= fetch_pc; 
    end
end

// ---------------------------------------------------------
// STAGES INSTANTIATION
// ---------------------------------------------------------

IF_ID IF_ID_stage (
    .clk            (clk),
    .reset          (reset),
    .stall          (stall),
    .exception      (exception),
    .inst_mem_is_valid  (inst_mem_is_valid),
    .inst_mem_read_data (safe_inst_mem_read_data), 
    .stall_read_i   (pipe_freeze), 
    
    // FIXED: Passed the safe, delayed PC into the Decode Stage
    .inst_fetch_pc  (if_id_pc),
    
    .instruction_i  (instruction),
    .wb_stall       (wb_stall),
    .wb_alu_to_reg  (wb_alu_to_reg),
    .wb_mem_to_reg  (wb_mem_to_reg),
    .wb_dest_reg_sel(wb_dest_reg_sel),
    .wb_result      (wb_result),
    .wb_read_data   (wb_read_data),
    .inst_mem_offset(inst_mem_address[1:0]),
    .flush_ex       (flush_ex), 
    .flush_id       (flush_id),
    
    .execute_immediate_w (execute_immediate),
    .immediate_sel_w        (immediate_sel),
    .alu_w          (alu),
    .lui_w          (lui),
    .jal_w          (jal),
    .jalr_w         (jalr),
    .branch_w       (branch),
    .mem_write_w    (mem_write),
    .mem_to_reg_w   (mem_to_reg),
    .arithsubtype_w         (arithsubtype),
    .pc_w           (pc), // <-- This is the wire that now carries the safe PC into Execute!
    .src1_select_w  (src1_select),
    .src2_select_w  (src2_select),
    .dest_reg_sel_w         (dest_reg_sel),
    .alu_operation_w        (alu_operation),
    .illegal_inst_w         (illegal_inst),
    .instruction_o  (instruction),
    .m_ext_w        (m_ext),
    .mandist_w         (mandist_w)            
);

assign reg_rdata1 =
    (src1_select == 5'd0) ? 32'b0 :
    (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src1_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result) : regs[src1_select];

assign reg_rdata2 =
    (src2_select == 5'd0) ? 32'b0 :
    (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src2_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result) : regs[src2_select];

integer i;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        for (i = 1; i < 32; i = i + 1)
            regs[i] <= 32'b0;
    end
    else if (wb_alu_to_reg && !stall_read && !wb_stall && wb_dest_reg_sel != 5'd0) begin
        regs[wb_dest_reg_sel] <= wb_mem_to_reg ? wb_read_data : wb_result;
    end
end

always @(posedge clk or negedge reset) begin
    if (!reset) stall_read <= 1'b1;
    else stall_read <= stall; 
end

execute execute (
    .clk          (clk),
    .reset        (reset),
    .reg_rdata1   (reg_rdata1),
    .reg_rdata2   (reg_rdata2),
    .execute_imm  (execute_immediate),
    .pc           (pc), // FIXED: Execute now correctly receives the safely synced PC
    .fetch_pc     (fetch_pc),
    .immediate_sel(immediate_sel),
    .mem_write    (mem_write),
    .jal          (jal),
    .jalr         (jalr),
    .lui          (lui),
    .alu          (alu),
    .branch       (branch),
    .arithsubtype (arithsubtype),
    .mem_to_reg   (mem_to_reg),
    .stall_read   (stall_read),
    .m_ext_i      (m_ext),
    .mandist_i    (mandist_w),         
    .dest_reg_sel (dest_reg_sel),
    .alu_op       (alu_operation),
    .dmem_raddr   (dmem_read_offset),
    .wb_branch_i      (wb_branch),
    .wb_branch_nxt_i  (wb_branch_nxt),
    .alu_operand1   (alu_operand1),
    .alu_operand2   (alu_operand2),
    .write_address  (write_address),
    .branch_stall   (branch_stall),
    .math_stall_o   (math_stall),   
    .next_pc        (next_pc),
    .branch_taken   (branch_taken),
    .wb_result           (wb_result),
    .wb_mem_write        (wb_mem_write),
    .wb_alu_to_reg       (wb_alu_to_reg),
    .wb_dest_reg_sel     (wb_dest_reg_sel),
    .wb_branch           (wb_branch),
    .wb_branch_nxt       (wb_branch_nxt),
    .wb_mem_to_reg       (wb_mem_to_reg),
    .wb_read_address     (wb_read_address),
    .mem_alu_operation   (wb_alu_operation)
);

assign next_pc_pipe = next_pc;

// ---------------------------------------------------------
// FIXED PC UPDATE LOGIC
// ---------------------------------------------------------
always @(posedge clk or negedge reset) begin
    if (!reset)
        fetch_pc <= RESET;
    else if (!pipe_freeze)
        fetch_pc <= branch_stall ? fetch_pc : next_pc; 
end

wb wb_stage (
   .clk(clk),
   .reset(reset),
   .stall_read_i       (stall_read), 
   .fetch_pc_i         (fetch_pc),
   .wb_branch_i        (wb_branch),
   .wb_mem_to_reg_i    (wb_mem_to_reg),
   .mem_write_i        (mem_write),
   .write_address_i    (write_address),
   .alu_operand2_i     (alu_operand2),
   .alu_operation_i    (alu_operation),
   .wb_alu_operation_i (wb_alu_operation),
   .wb_read_address_i  (wb_read_address),
   .dmem_read_data_i   (dmem_read_data),
   .dmem_write_valid_i (dmem_write_valid),
   .inst_mem_address_o (inst_mem_address),
   .inst_mem_is_ready_o(inst_mem_is_ready),
   .wb_stall_o         (wb_stall),
   .wb_write_address_o (wb_write_address),
   .wb_write_data_o    (wb_write_data),
   .wb_write_byte_o    (wb_write_byte),
   .wb_read_data_o     (wb_read_data),
   
   // FIXED: Disconnected this! The WB stage should NEVER output the PC!
   .inst_fetch_pc_o    (), 
   
   .wb_stall_first_o   (wb_stall_first),
   .wb_stall_second_o  (wb_stall_second)
);

// We now pipe the safely delayed PC outwards instead of the old WB-routed wire.
assign inst_fetch_pc_pipe = if_id_pc; 
assign pc_out = fetch_pc;

endmodule// ----------------------------------------------------------------------------
// Pipeline Module
// ----------------------------------------------------------------------------
`include "IF_ID.v"
`include "execute.v"
`include "memory.v"
`include "wb.v"

module pipe
#(
    parameter [31:0]            RESET = 32'h0000_0000
)
(
    input                       clk,
    input                       reset,
    input                       stall,
    output                      exception,  
    output [31:0]               pc_out,

    output      [31: 0]         inst_mem_address,
    input                       inst_mem_is_valid,
    input       [31: 0]         inst_mem_read_data,
    output                      inst_mem_is_ready,

    output      [31: 0]         dmem_read_address,
    output                      dmem_read_ready,
    input       [31: 0]         dmem_read_data_temp,
    input                       dmem_read_valid,
    output      [31: 0]         dmem_write_address,
    output                      dmem_write_ready,
    output      [31: 0]         dmem_write_data,
    output      [ 3: 0]         dmem_write_byte,
    input                       dmem_write_valid,
    output      [31: 0]         next_pc_pipe,
    output      [31: 0]         inst_fetch_pc_pipe
);
    
    wire      [31: 0] dmem_read_data;
    wire        [1:0] dmem_read_offset;
    wire              dmem_read_valid_checker;
    
    reg       [31: 0] immediate;
    wire              immediate_sel;
    wire       [ 4: 0] src1_select;
    wire       [ 4: 0] src2_select;
    wire       [ 4: 0] dest_reg_sel;
    wire       [ 2: 0] alu_operation;
    wire              arithsubtype;
    wire              mem_write;
    wire              mem_to_reg;
    wire              illegal_inst;

    wire       [31: 0] execute_immediate;
    wire              alu;
    wire              lui;
    wire              jal;
    wire              jalr;
    wire              branch;
    reg               stall_read;
    wire      [31: 0] instruction;
    wire      [31: 0] reg_rdata2 ;
    wire      [31: 0] reg_rdata1;
    reg       [31: 0] regs [31: 1];

    wire        [31: 0] pc;
    wire        [31: 0] inst_fetch_pc;
    reg         [31: 0] fetch_pc ;  

    wire    wb_stall_first;
    wire    wb_stall_second;
    wire    wb_stall;        
    wire    m_ext;     
    wire    mandist_w;       // NEW: Wire to connect IF_ID to EX     
    wire    math_stall;     
    
    // Instant combinational freeze for the front-end!
    wire    pipe_freeze = stall_read || math_stall;

    // --- NEW: THE SKID BUFFER ---
    // Catches the instruction falling out of IMEM when a stall hits!
    reg [31:0] saved_instr;
    reg        is_saved;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            is_saved <= 1'b0;
            saved_instr <= 32'h0;
        end else if (pipe_freeze && !is_saved) begin
            saved_instr <= inst_mem_read_data; // Catch it!
            is_saved <= 1'b1;
        end else if (!pipe_freeze) begin
            is_saved <= 1'b0;
        end
    end
    wire [31:0] safe_inst_mem_read_data = is_saved ? saved_instr : inst_mem_read_data;
    // ----------------------------
         
    wire         [31: 0] next_pc;
    wire        [31: 0] write_address;
    wire                branch_taken;
    wire                branch_stall;
    wire        [31:0]  alu_operand1;
    wire        [31:0]  alu_operand2;

    wire                wb_alu_to_reg;
    wire        [31: 0] wb_result;
    wire        [ 2: 0] wb_alu_operation;
    wire                wb_mem_write;
    wire                wb_mem_to_reg;
    wire        [ 4: 0] wb_dest_reg_sel;
    wire                wb_branch;
    wire                wb_branch_nxt;
    wire        [31: 0] wb_write_address;
    wire        [ 1: 0] wb_read_address;
    wire        [ 3: 0] wb_write_byte;
    wire        [31: 0] wb_write_data;
    wire        [31: 0] wb_read_data;

assign dmem_write_address       = wb_write_address;     
assign dmem_read_address        = alu_operand1 + execute_immediate; 
assign dmem_read_offset         = dmem_read_address[1:0];
assign dmem_read_ready          = mem_to_reg;   
assign dmem_write_ready         = wb_mem_write;     
assign dmem_write_data          = wb_write_data;    
assign dmem_write_byte          = wb_write_byte;    
assign dmem_read_data           = dmem_read_data_temp;      
assign dmem_read_valid_checker  = 1'b1;

IF_ID IF_ID_stage (
    .clk            (clk),
    .reset          (reset),
    .stall          (stall),
    .exception      (exception),
    .inst_mem_is_valid  (inst_mem_is_valid),
    
    // Pass the safe Skid Buffer data instead of raw memory!
    .inst_mem_read_data (safe_inst_mem_read_data), 

    .stall_read_i   (pipe_freeze), 
    .inst_fetch_pc  (inst_fetch_pc),
    .instruction_i  (instruction),
    .wb_stall       (wb_stall),
    .wb_alu_to_reg  (wb_alu_to_reg),
    .wb_mem_to_reg  (wb_mem_to_reg),
    .wb_dest_reg_sel(wb_dest_reg_sel),
    .wb_result      (wb_result),
    .wb_read_data   (wb_read_data),
    .inst_mem_offset(inst_mem_address[1:0]),
    .execute_immediate_w (execute_immediate),
    .immediate_sel_w    (immediate_sel),
    .alu_w          (alu),
    .lui_w          (lui),
    .jal_w          (jal),
    .jalr_w         (jalr),
    .branch_w       (branch),
    .mem_write_w    (mem_write),
    .mem_to_reg_w   (mem_to_reg),
    .arithsubtype_w     (arithsubtype),
    .pc_w           (pc),
    .src1_select_w  (src1_select),
    .src2_select_w  (src2_select),
    .dest_reg_sel_w     (dest_reg_sel),
    .alu_operation_w    (alu_operation),
    .illegal_inst_w     (illegal_inst),
    .instruction_o  (instruction),
    .m_ext_w        (m_ext),
    .mandist_w         (mandist_w)      // NEW: Connect output to wire            
);

assign reg_rdata1 =
    (src1_select == 5'd0) ? 32'b0 :
    (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src1_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result) : regs[src1_select];

assign reg_rdata2 =
    (src2_select == 5'd0) ? 32'b0 :
    (!wb_stall && wb_alu_to_reg && (wb_dest_reg_sel == src2_select))
        ? (wb_mem_to_reg ? wb_read_data : wb_result) : regs[src2_select];

integer i;
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        for (i = 1; i < 32; i = i + 1)
            regs[i] <= 32'b0;
    end
    else if (wb_alu_to_reg && !stall_read && !wb_stall && wb_dest_reg_sel != 5'd0) begin
        regs[wb_dest_reg_sel] <= wb_mem_to_reg ? wb_read_data : wb_result;
    end
end

always @(posedge clk or negedge reset) begin
    if (!reset) stall_read <= 1'b1;
    else stall_read <= stall; 
end

execute execute (
    .clk          (clk),
    .reset        (reset),
    .reg_rdata1   (reg_rdata1),
    .reg_rdata2   (reg_rdata2),
    .execute_imm  (execute_immediate),
    .pc           (pc),
    .fetch_pc     (fetch_pc),
    .immediate_sel(immediate_sel),
    .mem_write    (mem_write),
    .jal          (jal),
    .jalr         (jalr),
    .lui          (lui),
    .alu          (alu),
    .branch       (branch),
    .arithsubtype (arithsubtype),
    .mem_to_reg   (mem_to_reg),
    .stall_read   (stall_read),
    .m_ext_i      (m_ext),
    .mandist_i    (mandist_w),     // NEW: Connect wire to input          
    .dest_reg_sel (dest_reg_sel),
    .alu_op       (alu_operation),
    .dmem_raddr   (dmem_read_offset),
    .wb_branch_i      (wb_branch),
    .wb_branch_nxt_i  (wb_branch_nxt),
    .alu_operand1   (alu_operand1),
    .alu_operand2   (alu_operand2),
    .write_address  (write_address),
    .branch_stall   (branch_stall),
    .math_stall_o   (math_stall),   
    .next_pc        (next_pc),
    .branch_taken   (branch_taken),
    .wb_result           (wb_result),
    .wb_mem_write        (wb_mem_write),
    .wb_alu_to_reg       (wb_alu_to_reg),
    .wb_dest_reg_sel     (wb_dest_reg_sel),
    .wb_branch           (wb_branch),
    .wb_branch_nxt       (wb_branch_nxt),
    .wb_mem_to_reg       (wb_mem_to_reg),
    .wb_read_address     (wb_read_address),
    .mem_alu_operation   (wb_alu_operation)
);

assign next_pc_pipe = next_pc;

always @(posedge clk or negedge reset) begin
    if (!reset)
        fetch_pc <= RESET;
    else if (!pipe_freeze)
        fetch_pc <= branch_stall ? fetch_pc + 4 : next_pc;
end

wb wb_stage (
   .clk(clk),
   .reset(reset),
   .stall_read_i       (stall_read), 
   .fetch_pc_i         (fetch_pc),
   .wb_branch_i        (wb_branch),
   .wb_mem_to_reg_i    (wb_mem_to_reg),
   .mem_write_i        (mem_write),
   .write_address_i    (write_address),
   .alu_operand2_i     (alu_operand2),
   .alu_operation_i    (alu_operation),
   .wb_alu_operation_i (wb_alu_operation),
   .wb_read_address_i  (wb_read_address),
   .dmem_read_data_i   (dmem_read_data),
   .dmem_write_valid_i (dmem_write_valid),
   .inst_mem_address_o (inst_mem_address),
   .inst_mem_is_ready_o(inst_mem_is_ready),
   .wb_stall_o         (wb_stall),
   .wb_write_address_o (wb_write_address),
   .wb_write_data_o    (wb_write_data),
   .wb_write_byte_o    (wb_write_byte),
   .wb_read_data_o     (wb_read_data),
   .inst_fetch_pc_o    (inst_fetch_pc),
   .wb_stall_first_o   (wb_stall_first),
   .wb_stall_second_o  (wb_stall_second)
);
assign inst_fetch_pc_pipe = inst_fetch_pc;
assign pc_out = fetch_pc;

endmodule
