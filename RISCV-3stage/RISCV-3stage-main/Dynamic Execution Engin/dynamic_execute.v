`timescale 1ns/1ps

module dynamic_execute (
    input  wire        clk,
    input  wire        reset,
    
    // --- 1. Instruction Inputs (From IF_ID_dynamic) ---
    input  wire [31:0] decode_instr,
    input  wire [4:0]  rs1,
    input  wire [4:0]  rs2,
    input  wire [4:0]  rd,
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    
    // --- 2. Pipeline Flush (From ROB Misprediction) ---
    input  wire        pipeline_flush,
    
    // --- 3. ROB & RAT Interface ---
    input  wire        rob_full,
    input  wire [3:0]  rob_tag_assigned, // The ticket number the ROB is giving us this cycle
    
    // --- 4. Reservation Station Status (Stall Signals) ---
    input  wire        rs_alu_busy,
    input  wire        rs_mul_busy,
    input  wire        rs_div_busy,
    input  wire        rs_mem_busy,

    // --- 5. Dispatch Outputs (The Issue Signals) ---
    output reg         issue_alu_we,
    output reg         issue_mul_we,
    output reg         issue_div_we,
    output reg         issue_mem_we,
    
    // Instruction Data passed to Reservation Stations
    output reg  [31:0] issue_imm,
    output reg         issue_is_store,
    output reg         issue_is_branch,
    
    // --- 6. To Fetch Stage ---
    output wire        pipeline_stall // Tells IF_ID to stop fetching!
);

    // ==========================================
    // STEP 1: DECODING
    // ==========================================
    wire is_r_type = (opcode == 7'b0110011);
    wire is_i_type = (opcode == 7'b0010011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_store  = (opcode == 7'b0100011);
    wire is_branch = (opcode == 7'b1100011);
    wire is_jump   = (opcode == 7'b1101111) || (opcode == 7'b1100111);
    
    // RV32M Extension Logic
    wire is_m_ext  = is_r_type && (funct7 == 7'b0000001);
    wire is_mul    = is_m_ext && (funct3[2] == 1'b0);
    wire is_div    = is_m_ext && (funct3[2] == 1'b1);
    
    // Standard ALU Operations (Math, Logic, Branches, Jumps)
    wire is_alu    = (is_r_type && !is_m_ext) || is_i_type || is_branch || is_jump;
    wire valid_inst = (is_alu || is_mul || is_div || is_load || is_store);

    // Immediate Generation (Sign Extended)
    wire [31:0] imm_i = {{20{decode_instr[31]}}, decode_instr[31:20]};
    wire [31:0] imm_s = {{20{decode_instr[31]}}, decode_instr[31:25], decode_instr[11:7]};
    wire [31:0] imm_b = {{20{decode_instr[31]}}, decode_instr[7], decode_instr[30:25], decode_instr[11:8], 1'b0};
    
    wire [31:0] final_imm = is_store  ? imm_s :
                            is_branch ? imm_b : imm_i;

    // ==========================================
    // STEP 2: STALL LOGIC
    // ==========================================
    // We stall if we NEED a specific station and it is full, OR if the ROB queue is full.
    assign pipeline_stall = valid_inst && (
                            (is_alu && rs_alu_busy) ||
                            (is_mul && rs_mul_busy) ||
                            (is_div && rs_div_busy) ||
                            ((is_load || is_store) && rs_mem_busy) ||
                            rob_full );

    // ==========================================
    // STEP 3 & 4: ISSUE LOGIC
    // ==========================================
    always @(*) begin
        // Default everything to zero
        issue_alu_we = 1'b0;
        issue_mul_we = 1'b0;
        issue_div_we = 1'b0;
        issue_mem_we = 1'b0;
        issue_imm    = final_imm;
        issue_is_store  = is_store;
        issue_is_branch = is_branch;

        // Only issue if the pipeline is NOT stalling, NOT flushing, and NOT resetting
        if (!pipeline_stall && !pipeline_flush && !reset && valid_inst) begin
            if (is_alu)             issue_alu_we = 1'b1;
            else if (is_mul)        issue_mul_we = 1'b1;
            else if (is_div)        issue_div_we = 1'b1;
            else if (is_load || is_store) issue_mem_we = 1'b1;
        end
    end

endmodule
