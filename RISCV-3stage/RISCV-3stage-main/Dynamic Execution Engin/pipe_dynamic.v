`timescale 1ns/1ps

// ----------------------------------------------------------------------------
// Tomasulo Dynamic Pipeline (ALU Test Version)
// ----------------------------------------------------------------------------
`include "IF_ID.v"
// `include "dynamic_execute.v" // Assuming this is compiled in Vivado

module pipe_dynamic (
    input                       clk,
    input                       reset,
    
    // Interface to Instruction Memory
    output      [31: 0]         inst_mem_address,
    input                       inst_mem_is_valid,
    input       [31: 0]         inst_mem_read_data
);

    // ----------------------------------------------------------------------------
    // 1. Fetch & PC Logic (Simplified for ALU testing - No Branches)
    // ----------------------------------------------------------------------------
    reg  [31:0] fetch_pc;
    wire        dynamic_stall; // Comes from the Reservation Stations!
    
    always @(posedge clk or negedge reset) begin
        if (!reset)
            fetch_pc <= 32'b0;
        else if (!dynamic_stall) // Only fetch next instruction if RS is not full
            fetch_pc <= fetch_pc + 4;
    end
    
    assign inst_mem_address = fetch_pc;

    // ----------------------------------------------------------------------------
    // 2. Instruction Decode (IF/ID)
    // ----------------------------------------------------------------------------
    wire [31:0] instruction;
    wire [4:0]  src1_select, src2_select, dest_reg_sel;
    wire [2:0]  alu_operation;
    wire        illegal_inst;

    IF_ID IF_ID_stage (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),          
        .exception(),
        .inst_mem_is_valid(inst_mem_is_valid),
        .inst_mem_read_data(inst_mem_read_data),
        
        .stall_read_i(dynamic_stall), // Freeze Decode if Dynamic Engine is full
        .inst_fetch_pc(fetch_pc),
        .instruction_i(instruction),
        
        // We only care about these decode wires for the ALU test
        .src1_select_w(src1_select),
        .src2_select_w(src2_select),
        .dest_reg_sel_w(dest_reg_sel),
        .alu_operation_w(alu_operation),
        .instruction_o(instruction),
        .illegal_inst_w(illegal_inst)
    );

    // ----------------------------------------------------------------------------
    // 3. The Register File (Now driven by the CDB!)
    // ----------------------------------------------------------------------------
    reg  [31: 0] regs [31: 1];
    wire [31: 0] reg_rdata1 = (src1_select == 5'd0) ? 32'b0 : regs[src1_select];
    wire [31: 0] reg_rdata2 = (src2_select == 5'd0) ? 32'b0 : regs[src2_select];

    wire        cdb_we;
    wire [4:0]  cdb_rd;
    wire [31:0] cdb_data;

    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 1; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end
        // Writeback happens the INSTANT the CDB broadcasts!
        else if (cdb_we && cdb_rd != 5'd0) begin
            regs[cdb_rd] <= cdb_data;
        end
    end

    // ----------------------------------------------------------------------------
    // 4. THE DYNAMIC EXECUTE ENGINE
    // ----------------------------------------------------------------------------
    // We only issue an instruction if it's a valid arithmetic instruction
    wire is_arith = (instruction[6:0] == 7'b0110011 || instruction[6:0] == 7'b0010011);
    wire issue_enable = is_arith && !dynamic_stall && !illegal_inst;

    dynamic_execute DYN_EX (
        .clk(clk),
        .reset(reset),
        
        // Issuing to the Reservation Stations
        .issue_we(issue_enable),     
        .issue_op(alu_operation),      
        .issue_rs1(src1_select),     
        .issue_rs2(src2_select),     
        .issue_rd(dest_reg_sel),      
        .reg_data1(reg_rdata1),     
        .reg_data2(reg_rdata2),     
        
        // Stall feedback to Fetch/Decode
        .pipeline_stall(dynamic_stall), 
        
        // Writeback outputs directly to Register File
        .wb_we(cdb_we),          
        .wb_rd(cdb_rd),          
        .wb_data(cdb_data)         
    );

endmodule