`timescale 1ns/1ps

module cdb_arbiter (
    input  wire        clk,
    input  wire        reset,
    
    // --- Requests from Reservation Stations ---
    input  wire        mem_req,
    input  wire [3:0]  mem_tag,
    input  wire [31:0] mem_value,
    input  wire [31:0] mem_store_addr,
    
    input  wire        alu_req,
    input  wire [3:0]  alu_tag,
    input  wire [31:0] alu_value,
    input  wire        alu_mispredicted,
    
    input  wire        mul_req,
    input  wire [3:0]  mul_tag,
    input  wire [31:0] mul_value,

    input  wire        div_req,
    input  wire [3:0]  div_tag,
    input  wire [31:0] div_value,

    // --- Grants back to Stations ---
    output reg         mem_grant,
    output reg         alu_grant,
    output reg         mul_grant,
    output reg         div_grant,
    
    // --- The Official Common Data Bus (CDB) Outputs ---
    output reg         cdb_valid,
    output reg  [3:0]  cdb_tag,
    output reg  [31:0] cdb_value,
    output reg  [31:0] cdb_store_addr,
    output reg         cdb_branch_mispredicted
);

    always @(*) begin
        // Default everything to zero
        mem_grant = 1'b0; alu_grant = 1'b0; 
        mul_grant = 1'b0; div_grant = 1'b0;
        
        cdb_valid = 1'b0; cdb_tag = 4'd0; 
        cdb_value = 32'b0; cdb_store_addr = 32'b0;
        cdb_branch_mispredicted = 1'b0;

        // PRIORITY ENCODER
        if (mem_req) begin
            mem_grant = 1'b1;
            cdb_valid = 1'b1;
            cdb_tag   = mem_tag;
            cdb_value = mem_value;
            cdb_store_addr = mem_store_addr;
        end 
        else if (alu_req) begin
            alu_grant = 1'b1;
            cdb_valid = 1'b1;
            cdb_tag   = alu_tag;
            cdb_value = alu_value;
            cdb_branch_mispredicted = alu_mispredicted;
        end 
        else if (mul_req) begin
            mul_grant = 1'b1;
            cdb_valid = 1'b1;
            cdb_tag   = mul_tag;
            cdb_value = mul_value;
        end
        else if (div_req) begin
            div_grant = 1'b1;
            cdb_valid = 1'b1;
            cdb_tag   = div_tag;
            cdb_value = div_value;
        end
    end
endmodule
