`timescale 1ns/1ps

module rob #(
    parameter ENTRIES = 8 // We will hold up to 8 instructions in the queue
)(
    input  wire        clk,
    input  wire        reset,

    // --- 1. ISSUE STAGE (Adding to the back of the line) ---
    input  wire        issue_we,         // Fetch stage says: "Add new instruction!"
    input  wire        issue_is_store,   // Is this a memory write (sw)?
    input  wire [4:0]  issue_dest_reg,   // Which register are we writing to? (0 if store)
    output wire [3:0]  issue_tag,        // The "Ticket Number" we assign it
    output wire        rob_full,         // Tells Fetch to stall if the line is too long

    // --- 2. EXECUTE STAGE (Snooping the CDB for finished math) ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    
    // Memory specifically needs to know the calculated address
    input  wire [31:0] cdb_store_addr,   

    // --- 3. COMMIT STAGE (Retiring the oldest instruction to physical hardware) ---
    // For Math (Register File)
    output reg         commit_reg_we,
    output reg  [4:0]  commit_reg_rd,
    output reg  [31:0] commit_reg_data,
    
    // For Memory (Data RAM)
    output reg         commit_mem_we,
    output reg  [31:0] commit_mem_addr,
    output reg  [31:0] commit_mem_data
);

    // ==========================================
    // THE PHYSICAL QUEUE (The Ticket Rail)
    // ==========================================
    reg        valid      [0:ENTRIES-1]; // Is this slot actually holding an instruction?
    reg        ready      [0:ENTRIES-1]; // Has the math finished executing?
    reg        is_store   [0:ENTRIES-1]; // Is it an ALU math or a Store Memory?
    reg [4:0]  dest_reg   [0:ENTRIES-1]; // Destination register (for Math)
    reg [31:0] value      [0:ENTRIES-1]; // The final calculated answer
    reg [31:0] store_addr [0:ENTRIES-1]; // The RAM address (for Memory)

    // ==========================================
    // THE POINTERS (Head and Tail)
    // ==========================================
    reg [2:0] head; // Points to the oldest instruction (Next to Commit)
    reg [2:0] tail; // Points to the newest empty slot (Next to Issue)
    reg [3:0] count; // How many instructions are currently in the queue?

    // Assign outputs for the Issue stage
    assign rob_full  = (count == ENTRIES);
    
    // We add 1 to the tail to create a 1-indexed Tag (Tag 0 means "Not in ROB")
    assign issue_tag = tail + 4'd1; 

    // ==========================================
    // MAIN CONTROL BLOCK
    // ==========================================
    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            head  <= 3'b0;
            tail  <= 3'b0;
            count <= 4'b0;
            commit_reg_we <= 1'b0;
            commit_mem_we <= 1'b0;
            for (i = 0; i < ENTRIES; i = i + 1) begin
                valid[i] <= 1'b0;
                ready[i] <= 1'b0;
            end
        end else begin
            
            // Default: Turn off commit signals every clock cycle
            commit_reg_we <= 1'b0;
            commit_mem_we <= 1'b0;

            // -------------------------------------------------------------
            // 1. COMMIT LOGIC (Always check the Head of the line)
            // -------------------------------------------------------------
            if (valid[head] && ready[head]) begin
                
                // If it is a Store, tell RAM to write!
                if (is_store[head]) begin
                    commit_mem_we   <= 1'b1;
                    commit_mem_addr <= store_addr[head];
                    commit_mem_data <= value[head];
                end 
                // If it is Math, tell the Register File to write!
                else begin
                    commit_reg_we   <= 1'b1;
                    commit_reg_rd   <= dest_reg[head];
                    commit_reg_data <= value[head];
                end
                
                // Throw the ticket away and move the Head pointer
                valid[head] <= 1'b0;
                head <= head + 1;
                count <= count - 1; // Decrease queue size
            end

            // -------------------------------------------------------------
            // 2. ISSUE LOGIC (Add to the Tail of the line)
            // -------------------------------------------------------------
            // NOTE: We only issue if we aren't simultaneously committing to keep the count simple,
            // or we adjust the count based on (issue - commit).
            if (issue_we && !rob_full) begin
                valid[tail]    <= 1'b1;
                ready[tail]    <= 1'b0; // Math isn't done yet!
                is_store[tail] <= issue_is_store;
                dest_reg[tail] <= issue_dest_reg;
                
                tail <= tail + 1;
                
                // If we are issuing AND committing on the same cycle, the count stays the same!
                if (!(valid[head] && ready[head])) begin
                    count <= count + 1; 
                end
            end

            // -------------------------------------------------------------
            // 3. CDB SNOOPING (Cross tickets off the list when math finishes)
            // -------------------------------------------------------------
            if (cdb_valid && cdb_tag != 4'd0) begin
                // Convert Tag back to array index (Tag - 1)
                ready[cdb_tag - 1] <= 1'b1;
                value[cdb_tag - 1] <= cdb_value;
                
                // If it was a memory instruction, save the address too!
                if (is_store[cdb_tag - 1]) begin
                    store_addr[cdb_tag - 1] <= cdb_store_addr;
                end
            end

        end
    end

endmodule
