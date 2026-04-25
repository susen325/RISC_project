`timescale 1ns / 1ps

module top_core (
    input  wire clk,
    input  wire reset,
    output wire [15:0] demo_led_output,
    output wire [31:0] commit_instr
);

    // Global Control Wires
    wire        pipeline_flush;
    wire [31:0] recovery_pc;
    wire        pipeline_stall;
    wire        commit_mem_we; // Declared once here so RS_MEM and ROB can both use it

    // =========================================================
    // 1. PROGRAM COUNTER (PC) & FETCH
    // =========================================================
    reg [31:0] pc_reg;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            pc_reg <= 32'b0;
        end else if (pipeline_flush) begin
            pc_reg <= recovery_pc;
        end else if (!pipeline_stall) begin
            pc_reg <= pc_reg + 32'd4;
        end
    end

    wire [31:0] fetch_pc = pc_reg;
    wire [31:0] fetch_instr;

    instr_mem IMEM (.clk(clk), .pc(fetch_pc), .instr(fetch_instr));

    // =========================================================
    // 2. DECODE BARRIER
    // =========================================================
    wire [31:0] decode_pc, decode_instr;
    wire [4:0]  rs1, rs2, rd;
    wire [6:0]  opcode, funct7;
    wire [2:0]  funct3;

    IF_ID_dynamic DECODE_REG (
        .clk(clk), .reset(reset), .fetch_pc(fetch_pc), .fetch_instr(fetch_instr),
        .pipeline_stall(pipeline_stall), .decode_pc(decode_pc), .decode_instr(decode_instr),
        .rs1(rs1), .rs2(rs2), .rd(rd), .opcode(opcode), .funct3(funct3), .funct7(funct7)
    );

    // =========================================================
    // 3. REGISTER FILE, RAT, AND VALUE CACHE
    // =========================================================
    reg [31:0] reg_file [0:31];
    reg [3:0]  rat      [0:31];
    
    // THE FIX: Cache values that have finished but not yet committed!
    reg [31:0] tag_value [1:15];
    reg        tag_ready [1:15];

    // Read Operands for Dispatch
    wire [3:0] qj_rat = (rs1 == 0) ? 4'b0 : rat[rs1];
    wire [3:0] qk_rat = (rs2 == 0) ? 4'b0 : rat[rs2];

    // If the RAT points to a tag, AND that tag is already ready in the cache, grab the value!
    wire [31:0] vj_raw = (rs1 == 0) ? 32'b0 : 
                         (qj_rat != 0 && tag_ready[qj_rat]) ? tag_value[qj_rat] : reg_file[rs1];
    wire [31:0] vk_raw = (rs2 == 0) ? 32'b0 : 
                         (qk_rat != 0 && tag_ready[qk_rat]) ? tag_value[qk_rat] : reg_file[rs2];

    // If we grabbed the value from the cache, we don't need to wait on the bus anymore!
    wire [3:0]  qj_raw = (qj_rat != 0 && tag_ready[qj_rat]) ? 4'b0 : qj_rat;
    wire [3:0]  qk_raw = (qk_rat != 0 && tag_ready[qk_rat]) ? 4'b0 : qk_rat;

    // Register File & System Update Logic
    // (This block handles the cache AND the commits perfectly)
    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                reg_file[i] <= 32'b0;
                rat[i] <= 4'b0;
            end
            for (i = 1; i < 16; i = i + 1) begin
                tag_ready[i] <= 1'b0;
                tag_value[i] <= 32'b0;
            end
        end else begin
            // 1. Cache finished math from the bus
            if (cdb_valid && cdb_tag != 0) begin
                tag_ready[cdb_tag] <= 1'b1;
                tag_value[cdb_tag] <= cdb_value;
            end

            // 2. Clear cache flag when a tag ticket is recycled
            if (valid_issue) begin
                tag_ready[issue_tag] <= 1'b0;
            end

            // 3. Update RAT on issue
            if (valid_issue && rd != 0 && !issue_is_store && !issue_is_branch) begin
                rat[rd] <= issue_tag;
            end

            // 4. Physical Commit
            if (commit_reg_we && commit_reg_rd != 0) begin
                reg_file[commit_reg_rd] <= commit_reg_data;
                // BUG FIX: Only clear the RAT if it still points to the exact tag that just committed!
                if (rat[commit_reg_rd] == commit_rob_tag) rat[commit_reg_rd] <= 4'b0;
            end

            // 5. Branch Recovery
            if (pipeline_flush) begin
                for (i = 0; i < 32; i = i + 1) rat[i] <= 4'b0;
                for (i = 1; i < 16; i = i + 1) tag_ready[i] <= 1'b0;
            end
        end
    end

    // =========================================================
    // 4. THE DISPATCHER (dynamic_execute.v)
    // =========================================================
    wire issue_alu_we, issue_mul_we, issue_div_we, issue_mem_we;
    wire [31:0] issue_imm;
    wire issue_is_store, issue_is_branch;
    wire rs_alu_busy, rs_mem_busy;
    wire rob_full;
    wire [3:0] issue_tag;

    dynamic_execute DISPATCHER (
        .clk(clk), .reset(reset),
        .decode_instr(decode_instr), .rs1(rs1), .rs2(rs2), .rd(rd),
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .pipeline_flush(pipeline_flush), .rob_full(rob_full),
        .rob_tag_assigned(issue_tag), // The ticket from the ROB
        .rs_alu_busy(rs_alu_busy), .rs_mul_busy(rs_mul_busy), .rs_div_busy(rs_div_busy), .rs_mem_busy(rs_mem_busy),
        .issue_alu_we(issue_alu_we), .issue_mul_we(issue_mul_we), .issue_div_we(issue_div_we), .issue_mem_we(issue_mem_we),
        .issue_imm(issue_imm), .issue_is_store(issue_is_store), .issue_is_branch(issue_is_branch),
        .pipeline_stall(pipeline_stall)
    );

    // =========================================================
    // 5. RESERVATION STATIONS
    // =========================================================
    wire cdb_valid;
    wire [3:0] cdb_tag;
    wire [31:0] cdb_value, cdb_store_addr;
    wire cdb_branch_mispredicted;

    // ALU Request Signals
    wire alu_req, alu_grant, alu_mispredict;
    wire [3:0] alu_tag;
    wire [31:0] alu_value;

    rs_alu #(.MY_TAG(4'd1)) RS_ALU (
        .clk(clk), .reset(reset), .pipeline_flush(pipeline_flush),
        .issue_we(issue_alu_we), .issue_opcode(opcode), .issue_funct3(funct3),
        .issue_vj(vj_raw), .issue_qj(qj_raw), .issue_vk(vk_raw), .issue_qk(qk_raw),
        .issue_imm(issue_imm), .issue_rob_tag(issue_tag), .issue_pc(decode_pc),
        .rs_busy(rs_alu_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .alu_req(alu_req), .alu_grant(alu_grant), .alu_tag(alu_tag), 
        .alu_value(alu_value), .alu_mispredict(alu_mispredict)
    );

    // MEM Request Signals
    wire mem_req, mem_grant, mem_re;
    wire [3:0] mem_tag, mem_rob_tag;
    wire [31:0] mem_value, mem_store_addr_calc, mem_raddr, mem_rdata;

    rs_mem #(.MY_TAG(4'd4)) RS_MEM (
        .clk(clk), .reset(reset), .pipeline_flush(pipeline_flush),
        .issue_we(issue_mem_we), .issue_is_store(issue_is_store),
        .issue_vj(vj_raw), .issue_qj(qj_raw), .issue_vk(vk_raw), .issue_qk(qk_raw),
        .issue_imm(issue_imm), .issue_rob_tag(issue_tag),
        .rs_busy(rs_mem_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .mem_re(mem_re), .mem_raddr(mem_raddr), .mem_rdata(mem_rdata),
        .mem_req(mem_req), .mem_grant(mem_grant), .mem_tag(mem_tag),
        .mem_value(mem_value), .mem_rob_tag(mem_rob_tag), .mem_store_addr(mem_store_addr_calc),
        .commit_mem_we(commit_mem_we) 
    );
    
    // =========================================================
    // 5b. RESERVATION STATION: MULTIPLIER
    // =========================================================
    wire mul_req, mul_grant;
    wire [3:0] mul_tag;
    wire [31:0] mul_value;
    wire rs_mul_busy;

    rs_mul #(.MY_TAG(4'd2)) RS_MUL (
        .clk(clk), .reset(reset), .pipeline_flush(pipeline_flush),
        .issue_we(issue_mul_we),
        .issue_vj(vj_raw), .issue_qj(qj_raw), .issue_vk(vk_raw), .issue_qk(qk_raw),
        .issue_rob_tag(issue_tag),
        .rs_busy(rs_mul_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .mul_req(mul_req), .mul_grant(mul_grant), .mul_tag(mul_tag), .mul_value(mul_value)
    );
   
   // =========================================================
    // 5c. RESERVATION STATION: DIVIDER
    // =========================================================
    wire div_req, div_grant;
    wire [3:0] div_tag;
    wire [31:0] div_value;
    wire rs_div_busy;

    rs_div #(.MY_TAG(4'd3)) RS_DIV (
        .clk(clk), .reset(reset), .pipeline_flush(pipeline_flush),
        .issue_we(issue_div_we),
        .issue_vj(vj_raw), .issue_qj(qj_raw), .issue_vk(vk_raw), .issue_qk(qk_raw),
        .issue_rob_tag(issue_tag),
        .rs_busy(rs_div_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .div_req(div_req), .div_grant(div_grant), .div_tag(div_tag), .div_value(div_value)
    );

    // =========================================================
    // 6. COMMON DATA BUS ARBITER
    // =========================================================
    cdb_arbiter ARBITER (
        .clk(clk), .reset(reset),
        .mem_req(mem_req), .mem_tag(mem_rob_tag), .mem_value(mem_value), .mem_store_addr(mem_store_addr_calc),
        .alu_req(alu_req), .alu_tag(alu_tag), .alu_value(alu_value), .alu_mispredicted(alu_mispredict),
        .mul_req(mul_req), .mul_tag(mul_tag), .mul_value(mul_value), 
        .div_req(div_req), .div_tag(div_tag), .div_value(div_value), 
        .mem_grant(mem_grant), .alu_grant(alu_grant), .mul_grant(mul_grant), .div_grant(div_grant), 
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .cdb_store_addr(cdb_store_addr), .cdb_branch_mispredicted(cdb_branch_mispredicted)
    );

    // =========================================================
    // 7. THE REORDER BUFFER (ROB) & PHYSICAL COMMITS
    // =========================================================
    wire commit_reg_we; // The duplicate commit_mem_we was safely removed from here
    wire [4:0] commit_reg_rd;
    wire [31:0] commit_reg_data, commit_mem_addr, commit_mem_data;
    wire [3:0] commit_rob_tag; 
    wire valid_issue = (issue_alu_we || issue_mul_we || issue_div_we || issue_mem_we);

    rob #( .ENTRIES(8) ) ROB_UNIT (
        .clk(clk), .reset(reset),
        .issue_we(valid_issue),
        .issue_is_store(issue_is_store), .issue_is_branch(issue_is_branch),.issue_instr(decode_instr),
        .issue_dest_reg(rd), .issue_tag(issue_tag), .rob_full(rob_full),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .cdb_store_addr(cdb_store_addr), .cdb_branch_mispredicted(cdb_branch_mispredicted),
        .commit_reg_we(commit_reg_we), .commit_reg_rd(commit_reg_rd), .commit_reg_data(commit_reg_data),
        .commit_instr(commit_instr),
        .commit_mem_we(commit_mem_we), .commit_mem_addr(commit_mem_addr), .commit_mem_data(commit_mem_data),
        .pipeline_flush(pipeline_flush), .recovery_pc(recovery_pc),
        .commit_tag(commit_rob_tag) 
    );

    // =========================================================
    // 8. DATA MEMORY (BRAM)
    // =========================================================
    data_mem DMEM (
        .clk(clk),
        .re(mem_re), .raddr(mem_raddr), .rdata(mem_rdata),
        .we(commit_mem_we), .waddr(commit_mem_addr), .wdata(commit_mem_data), .wstrb(4'b1111) 
    );

    // =========================================================
    // 9. FPGA LED DEMO OUTPUT
    // =========================================================
    reg [15:0] led_reg;
    always @(posedge clk or negedge reset) begin
        if (!reset) led_reg <= 16'b0;
        else if (commit_reg_we && commit_reg_rd == 5'd4) led_reg <= commit_reg_data[15:0];
    end
    assign demo_led_output = led_reg;

endmodule
