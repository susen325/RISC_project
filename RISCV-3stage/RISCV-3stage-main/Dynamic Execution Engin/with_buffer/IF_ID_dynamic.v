`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2026 03:33:15 PM
// Design Name: 
// Module Name: IF_ID_dynamic
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ps

module IF_ID_dynamic (
    input  wire        clk,
    input  wire        reset,
    
    // --- 1. Inputs from Fetch Stage & BRAM ---
    input  wire [31:0] fetch_pc,
    input  wire [31:0] fetch_instr,
    
    // --- 2. The Stall Condition (From ROB / RS) ---
    input  wire        pipeline_stall, // High if ROB or ANY Reservation Station is full
    
    // --- 3. Outputs to the Dispatcher ---
    output reg  [31:0] decode_pc,
    output reg  [31:0] decode_instr,
    
    // Pre-decoded standard RISC-V fields for the Dispatcher
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7
);

    // Synchronous Pipeline Register (The "Barrier" between Fetch and Decode)
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            decode_pc    <= 32'b0;
            decode_instr <= 32'h00000013; // Standard RISC-V NOP (addi x0, x0, 0)
        end else if (!pipeline_stall) begin
            decode_pc    <= fetch_pc;
            decode_instr <= fetch_instr;
        end
        // If pipeline_stall is HIGH, we hold the current instruction and PC perfectly still!
    end

    // Continuous assignment to automatically slice the instruction for the Dispatcher
    assign opcode = decode_instr[6:0];
    assign rd     = decode_instr[11:7];
    assign funct3 = decode_instr[14:12];
    assign rs1    = decode_instr[19:15];
    assign rs2    = decode_instr[24:20];
    assign funct7 = decode_instr[31:25];

endmodule
