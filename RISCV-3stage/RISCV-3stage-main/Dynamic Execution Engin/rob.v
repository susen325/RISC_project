`timescale 1ns/1ps

module rob #(
    parameter ENTRIES = 8 // The number of instructions the queue can hold
)(
    input  wire        clk,
    input  wire        reset,

    // --- 1. ISSUE STAGE (Adding to the back of the line) ---
    input  wire        issue_we,         // Fetch stage says: "Add new instruction!"
    input  wire        issue_is_store,   // Is this a memory write (sw)?
    input  wire        issue_is_branch,  // Is this a branch instruction?
    input  wire [4:0]  issue_dest_reg,   // Which register are we writing to? (0 if store/branch)
    output wire [3:0]  issue_tag,        // The "Ticket Number" we assign it
    output wire        rob_full,         // Tells Fetch to stall if the line is too long

    // --- 2. EXECUTE STAGE (Snooping the CDB for finished math) ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    input  wire [31:0] cdb_store_addr,   // Memory needs the calculated address
    input  wire        cdb_branch_mispredicted, // Did the ALU find out our guess was wrong?

    // --- 3. COMMIT STAGE (Retiring the oldest instruction to physical hardware) ---
    // For Math (Register File)
    output reg         commit_reg_we,
    output reg  [4:0]  commit_reg_rd,
    output reg  [31:0] commit_reg_data,
    
    // For Memory (Data RAM)
    output reg         commit_mem_we,
    output reg  [31:0] commit_mem_addr,
    output reg  [31:0] commit_mem_data,

    // For Branches (Pipeline Flush)
    output reg         pipeline_flush,
    output reg  [31:0] recovery_pc
);

    // ==========================================
    // THE PHYSICAL QUEUE (The Ticket Rail)
    // ==========================================
    reg        valid          [0:ENTRIES-1]; 
    reg        ready          [0:ENTRIES-1]; 
    reg        is_store       [0:ENTRIES-1]; 
    reg        is_branch      [0:ENTRIES-1];
    reg        mispredicted   [0:ENTRIES-1];
    reg [4:0]  dest_reg       [0:ENTRIES-1]; 
    reg [31:0] value          [0:ENTRIES-1]; // Final math answer or branch recovery PC
    reg [31:0] store_addr     [0:ENTRIES-1]; 

    // ==========================================
    // THE POINTERS (Head and Tail)
    // ==========================================
    reg [2:0] head; 
    reg [2:0] tail; 
    reg [3:0] count; 

    // Assign outputs for the Issue stage
    assign rob_full  = (count == ENTRIES);
    assign issue_tag = tail + 4'd1; // 1-indexed Tag (Tag 0 means "Not in ROB")

    // ==========================================
    // MAIN CONTROL BLOCK
    // ==========================================
    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            head  <= 3'b0;
            tail  <= 3'b0;
            count <= 4'b0;
            commit_reg_we  <= 1'b0;
            commit_mem_we  <= 1'b0;
            pipeline_flush <= 1'b0;
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
                ready[i] <= 1'b0;
            end
        end else begin
            
            // Default: Turn off commit and flush signals every clock cycle
            commit_reg_we  <= 1'b0;
            commit_mem_we  <= 1'b0;
            pipeline_flush <= 1'b0;

            // -------------------------------------------------------------
            // 1. COMMIT LOGIC (Always check the Head of the line)
            // -------------------------------------------------------------
            if (valid[head] && ready[head]) begin
                
                if (is_branch[head] && mispredicted[head]) begin
                    // BRANCH RECOVERY: Flush the pipeline!
                    pipeline_flush <= 1'b1;
                    recovery_pc    <= value[head]; // The ALU stored the correct PC here
                    
                    // Clear the entire ROB immediately
                    head  <= 3'b0;
                    tail  <= 3'b0;
                    count <= 4'b0;
                    for (i = 0; i < ENTRIES; i = i + 1) begin
                        valid[i] <= 1'b0;
                    end
                end
                else begin
                    // STANDARD COMMIT: Math or Memory
                    if (is_store[head]) begin
                        commit_mem_we   <= 1'b1;
                        commit_mem_addr <= store_addr[head];
                        commit_mem_data <= value[head];
                    end else if (dest_reg[head] != 5'd0) begin // Don't write to x0
                        commit_reg_we   <= 1'b1;
                        commit_reg_rd   <= dest_reg[head];
                        commit_reg_data <= value[head];
                    end
                    
                    // Throw the ticket away and move the Head pointer
                    valid[head] <= 1'b0;
                    head <= head + 1;
                    count <= count - 1;
                end
            end

            // -------------------------------------------------------------
            // 2. ISSUE LOGIC (Add to the Tail of the line)
            // -------------------------------------------------------------
            if (issue_we && !rob_full && !pipeline_flush) begin
                valid[tail]        <= 1'b1;
                ready[tail]        <= 1'b0; 
                is_store[tail]     <= issue_is_store;
                is_branch[tail]    <= issue_is_branch;
                dest_reg[tail]     <= issue_dest_reg;
                mispredicted[tail] <= 1'b0;
                
                tail <= tail + 1;
                
                // Keep count accurate if issuing and committing simultaneously
                if (!(valid[head] && ready[head])) begin
                    count <= count + 1; 
                end
            end

            // -------------------------------------------------------------
            // 3. CDB SNOOPING (Cross tickets off when math finishes)
            // -------------------------------------------------------------
            if (cdb_valid && cdb_tag != 4'd0 && !pipeline_flush) begin
                ready[cdb_tag - 1] <= 1'b1;
                value[cdb_tag - 1] <= cdb_value;
                
                if (is_store[cdb_tag - 1]) begin
                    store_addr[cdb_tag - 1] <= cdb_store_addr;
                end
                if (is_branch[cdb_tag - 1]) begin
                    mispredicted[cdb_tag - 1] <= cdb_branch_mispredicted;
                end
            end

        end
    end

endmodule
