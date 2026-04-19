`timescale 1ns/1ps

module dynamic_execute (
    input  wire        clk,
    input  wire        reset,
    
    // --- Incoming Instruction from IF/ID Stage ---
    input  wire        issue_we,     
    input  wire [2:0]  issue_op,      
    input  wire [4:0]  issue_rs1,     
    input  wire [4:0]  issue_rs2,     
    input  wire [4:0]  issue_rd,      
    input  wire [31:0] reg_data1,     
    input  wire [31:0] reg_data2,     
    
    output wire        pipeline_stall, // Tell IF/ID to stop if RS is full
    
    // --- NEW: Outgoing to the Register File ---
    output wire        wb_we,          // Write Enable for RegFile
    output wire [4:0]  wb_rd,          // Destination Register
    output wire [31:0] wb_data         // The actual answer
);

    // ==========================================
    // 1. THE COMMON DATA BUS (CDB) WIRES
    // ==========================================
    wire        cdb_valid;
    wire [3:0]  cdb_tag;
    wire [31:0] cdb_value;

    // ==========================================
    // 1.5 TAG TO DESTINATION REGISTER TRACKER
    // ==========================================
    // We need to remember which 'rd' belongs to which Tag so we can write it back!
    reg [4:0] tag_to_rd [0:15]; 
    
    always @(posedge clk) begin
        // When we issue an instruction, remember its destination register
        if (issue_we) begin
            tag_to_rd[1] <= issue_rd; // Assuming Tag 1 for our simple ALU right now
        end
    end
    
    // Connect the CDB directly to the pipeline's Writeback ports!
    assign wb_we   = cdb_valid;
    assign wb_data = cdb_value;
    assign wb_rd   = tag_to_rd[cdb_tag];

    // ==========================================
    // 2. REGISTER STATUS TABLE (RAT)
    // ==========================================
    wire       rs1_waiting, rs2_waiting;
    wire [3:0] rs1_wait_tag, rs2_wait_tag;

    reg_status RAT (
        .clk(clk), .reset(reset),
        // Looking up our source registers
        .rs1_addr(issue_rs1), .rs2_addr(issue_rs2),
        .rs1_busy(rs1_waiting), .rs1_tag(rs1_wait_tag),
        .rs2_busy(rs2_waiting), .rs2_tag(rs2_wait_tag),
        // Renaming our destination register (Assume RS_ALU always gets Tag 4'd1 or 4'd2)
        // For simplicity right now, we will assign everything to Tag 1.
        .issue_we(issue_we), .rd_addr(issue_rd), .rd_tag(4'd1), 
        // Snooping the CDB
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag)
    );

    // ==========================================
    // 3. PREPARING DATA FOR THE RESERVATION STATION
    // ==========================================
    // If RAT says rs1 is waiting, we send the Tag. Otherwise, we send the real Data.
    wire [31:0] vj_in = rs1_waiting ? 32'b0 : reg_data1;
    wire [3:0]  qj_in = rs1_waiting ? rs1_wait_tag : 4'd0;
    
    wire [31:0] vk_in = rs2_waiting ? 32'b0 : reg_data2;
    wire [3:0]  qk_in = rs2_waiting ? rs2_wait_tag : 4'd0;

    // ==========================================
    // 4. THE RESERVATION STATION (RS_ALU)
    // ==========================================
    wire        alu_start, alu_ack;
    wire [2:0]  alu_op;
    wire [31:0] alu_vj, alu_vk;

    rs_alu RS (
        .clk(clk), .reset(reset),
        .issue_we(issue_we), .issue_op(issue_op),
        .issue_vj(vj_in), .issue_qj(qj_in),
        .issue_vk(vk_in), .issue_qk(qk_in),
        .rs_full(pipeline_stall),
        // Snooping the CDB
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        // Firing to the ALU
        .alu_start(alu_start), .alu_op(alu_op), 
        .alu_vj(alu_vj), .alu_vk(alu_vk), .alu_ack(alu_ack)
    );

    // ==========================================
    // 5. THE EXECUTION UNIT (ALU) & CDB BROADCAST
    // ==========================================
    reg [31:0] alu_result;
    
    // A simple combinational ALU
    always @(*) begin
        case (alu_op)
            3'b000: alu_result = alu_vj + alu_vk; // ADD
            3'b001: alu_result = alu_vj - alu_vk; // SUB
            // ... add other ops here
            default: alu_result = 32'b0;
        endcase
    end

    // The ALU fires instantly, so we acknowledge it instantly
    assign alu_ack = alu_start;

    // BROADCAST ON THE CDB!
    // If the ALU just started and finished this cycle, broadcast the answer to everyone.
    // (Assuming Tag 1 for this simple ALU example)
    assign cdb_valid = alu_start;
    assign cdb_tag   = 4'd1; 
    assign cdb_value = alu_result;

endmodule