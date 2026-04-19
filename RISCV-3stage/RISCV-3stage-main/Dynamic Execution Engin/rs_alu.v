`timescale 1ns/1ps

module rs_alu (
    input  wire        clk,
    input  wire        reset,
    
    // --- PORT 1: Issue Stage (Receiving a new instruction) ---
    input  wire        issue_we,
    input  wire [2:0]  issue_op,
    input  wire [31:0] issue_vj,
    input  wire [3:0]  issue_qj,
    input  wire [31:0] issue_vk,
    input  wire [3:0]  issue_qk,
    
    // Tells the pipeline to stall if both slots are full!
    output wire        rs_full,       

    // --- PORT 2: The CDB (Snooping for missing data) ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,

    // --- PORT 3: To the actual ALU (Firing the instruction) ---
    output wire        alu_start,
    output wire [2:0]  alu_op,
    output wire [31:0] alu_vj,
    output wire [31:0] alu_vk,
    input  wire        alu_ack      // ALU says "I got it!"
);

    // Wires for Slot 1 (Given Tag ID: 4'd1)
    wire slot1_busy, slot1_ready;
    wire [2:0] slot1_op;
    wire [31:0] slot1_vj, slot1_vk;
    wire slot1_we  = issue_we && !slot1_busy; // Only write if not busy
    wire slot1_ack = alu_ack && slot1_ready;  // Acknowledge if this slot fired

    rs_slot #(.MY_TAG(4'd1)) SLOT_1 (
        .clk(clk), .reset(reset),
        .issue_we(slot1_we), .issue_op(issue_op), 
        .issue_vj(issue_vj), .issue_qj(issue_qj), 
        .issue_vk(issue_vk), .issue_qk(issue_qk),
        .rs_busy(slot1_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .ready_to_exec(slot1_ready), .exec_op(slot1_op), 
        .exec_vj(slot1_vj), .exec_vk(slot1_vk), .exec_ack(slot1_ack)
    );

    // Wires for Slot 2 (Given Tag ID: 4'd2)
    wire slot2_busy, slot2_ready;
    wire [2:0] slot2_op;
    wire [31:0] slot2_vj, slot2_vk;
    // Only write to Slot 2 if Slot 1 is busy!
    wire slot2_we  = issue_we && slot1_busy && !slot2_busy; 
    // Acknowledge Slot 2 ONLY if it fired and Slot 1 didn't fire
    wire slot2_ack = alu_ack && slot2_ready && !slot1_ready; 

    rs_slot #(.MY_TAG(4'd2)) SLOT_2 (
        .clk(clk), .reset(reset),
        .issue_we(slot2_we), .issue_op(issue_op), 
        .issue_vj(issue_vj), .issue_qj(issue_qj), 
        .issue_vk(issue_vk), .issue_qk(issue_qk),
        .rs_busy(slot2_busy),
        .cdb_valid(cdb_valid), .cdb_tag(cdb_tag), .cdb_value(cdb_value),
        .ready_to_exec(slot2_ready), .exec_op(slot2_op), 
        .exec_vj(slot2_vj), .exec_vk(slot2_vk), .exec_ack(slot2_ack)
    );

    // --- ARBITRATION LOGIC (Who gets to use the ALU?) ---
    
    // The whole RS is full only if BOTH slots are taken
    assign rs_full = slot1_busy && slot2_busy;

    // Fire the ALU if either slot is ready
    assign alu_start = slot1_ready || slot2_ready;

    // If both happen to be ready at the exact same time, Slot 1 wins (Priority Mux)
    assign alu_op = slot1_ready ? slot1_op : slot2_op;
    assign alu_vj = slot1_ready ? slot1_vj : slot2_vj;
    assign alu_vk = slot1_ready ? slot1_vk : slot2_vk;

endmodule