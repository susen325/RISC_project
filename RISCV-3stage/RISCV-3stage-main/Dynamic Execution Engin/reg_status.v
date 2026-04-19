`timescale 1ns/1ps

module reg_status (
    input  wire        clk,
    input  wire        reset,
    
    // --- PORT 1: Issue Stage (Looking up registers) ---
    input  wire [4:0]  rs1_addr,      // E.g., read x2
    input  wire [4:0]  rs2_addr,      // E.g., read x3
    output wire        rs1_busy,      // Is x2 waiting for math? (1 = yes, 0 = no)
    output wire [3:0]  rs1_tag,       // If yes, who is calculating it?
    output wire        rs2_busy,      // Is x3 waiting for math?
    output wire [3:0]  rs2_tag,       // If yes, who is calculating it?

    // --- PORT 2: Issue Stage (Renaming a destination register) ---
    input  wire        issue_we,      // Are we issuing an instruction that writes to a reg?
    input  wire [4:0]  rd_addr,       // The register we will eventually write to (e.g., x1)
    input  wire [3:0]  rd_tag,        // The tag of the Reservation Station we are putting this in
    
    // --- PORT 3: CDB (Listening for finished math to clear the busy bits) ---
    input  wire        cdb_valid,     // Did someone just broadcast an answer?
    input  wire [3:0]  cdb_tag        // Who broadcasted it?
);

    // The actual memory array: 32 registers.
    // Each register needs 1 Busy bit, and 4 Tag bits.
    reg busy_array [0:31];
    reg [3:0] tag_array [0:31];

    integer i;

    // 1. Combinational Reads (Instantly tell the Issue stage the status)
    assign rs1_busy = busy_array[rs1_addr];
    assign rs1_tag  = tag_array[rs1_addr];
    assign rs2_busy = busy_array[rs2_addr];
    assign rs2_tag  = tag_array[rs2_addr];

    // 2. Synchronous Writes & CDB Updates
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            // On reset, clear all busy bits (Register File has the real data)
            for (i = 0; i < 32; i = i + 1) begin
                busy_array[i] <= 1'b0;
                tag_array[i]  <= 4'b0;
            end
        end else begin
            
            // --- CDB BROADCAST LOGIC ---
            // If the CDB broadcasts a tag, check all 32 registers. 
            // If any register is waiting for this tag, mark it as NOT busy anymore!
            if (cdb_valid) begin
                for (i = 0; i < 32; i = i + 1) begin
                    if (busy_array[i] && (tag_array[i] == cdb_tag)) begin
                        busy_array[i] <= 1'b0; 
                    end
                end
            end
            
            // --- ISSUE LOGIC ---
            // If a new instruction is issuing, mark its destination register as busy,
            // and write down the tag of the Reservation Station calculating it.
            // (Note: Register 0 in RISC-V is hardwired to 0, so never mark it busy!)
            if (issue_we && rd_addr != 5'd0) begin
                busy_array[rd_addr] <= 1'b1;
                tag_array[rd_addr]  <= rd_tag;
            end
            
        end
    end

endmodule