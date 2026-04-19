`timescale 1ns/1ps

module rs_slot #(
    parameter [3:0] MY_TAG = 4'd1 // Every RS gets a unique ID tag (e.g., RS_ALU1 = 1, RS_ALU2 = 2)
)(
    input  wire        clk,
    input  wire        reset,
    
    // --- PORT 1: Issue Stage (Receiving a new instruction) ---
    input  wire        issue_we,      // Is the Issue stage putting an instruction here?
    input  wire [2:0]  issue_op,      // What math to do (e.g., funct3: ADD, SUB, etc.)
    input  wire [31:0] issue_vj,      // Operand 1 actual data (if ready)
    input  wire [3:0]  issue_qj,      // Operand 1 tag (if waiting)
    input  wire [31:0] issue_vk,      // Operand 2 actual data (if ready)
    input  wire [3:0]  issue_qk,      // Operand 2 tag (if waiting)
    
    output wire        rs_busy,       // Tells the Issue stage: "I am full, don't give me stuff!"

    // --- PORT 2: The CDB (Snooping for missing data) ---
    input  wire        cdb_valid,     // Did an ALU just broadcast an answer?
    input  wire [3:0]  cdb_tag,       // Who broadcasted it?
    input  wire [31:0] cdb_value,     // What is the math result?

    // --- PORT 3: To the ALU (Firing the instruction) ---
    output wire        ready_to_exec, // Tells ALU: "My data is ready, do the math!"
    output wire [2:0]  exec_op,       // Math operation to do
    output wire [31:0] exec_vj,       // Operand 1 final data
    output wire [31:0] exec_vk,       // Operand 2 final data
    input  wire        exec_ack       // ALU tells RS: "I took your data, you can clear yourself now."
);

    // Internal Registers for the Waiting Room
    reg        busy;
    reg [2:0]  op;
    reg [31:0] vj, vk;
    reg [3:0]  qj, qk;

    // Output assignments
    assign rs_busy = busy;
    assign exec_op = op;
    assign exec_vj = vj;
    assign exec_vk = vk;
    
    // An instruction is READY if it is busy, and BOTH waiting tags are 0 (meaning we have the actual data)
    assign ready_to_exec = busy && (qj == 4'd0) && (qk == 4'd0);

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            busy <= 1'b0;
            op   <= 3'b0;
            vj   <= 32'b0; vk <= 32'b0;
            qj   <= 4'b0;  qk <= 4'b0;
        end else begin
            
            // 1. If the ALU took our instruction this cycle, clear the station
            if (exec_ack) begin
                busy <= 1'b0;
            end 
            
            // 2. If the Issue stage is giving us a new instruction, store it
            else if (issue_we) begin
                busy <= 1'b1;
                op   <= issue_op;
                vj   <= issue_vj; vk <= issue_vk;
                
                // --- CDB Bypass Check During Issue ---
                // If we are issuing exactly as the CDB is broadcasting what we need, 
                // grab the value instantly instead of waiting a cycle!
                if (cdb_valid && issue_qj != 0 && issue_qj == cdb_tag) begin
                    vj <= cdb_value;
                    qj <= 4'd0;
                end else begin
                    qj <= issue_qj;
                end

                if (cdb_valid && issue_qk != 0 && issue_qk == cdb_tag) begin
                    vk <= cdb_value;
                    qk <= 4'd0;
                end else begin
                    qk <= issue_qk;
                end
            end 
            
            // 3. Normal CDB Snooping (while waiting)
            else if (busy && cdb_valid) begin
                // If Operand 1 is waiting for this tag, grab the data and clear the tag!
                if (qj != 4'd0 && qj == cdb_tag) begin
                    vj <= cdb_value;
                    qj <= 4'd0;
                end
                // If Operand 2 is waiting for this tag, grab the data and clear the tag!
                if (qk != 4'd0 && qk == cdb_tag) begin
                    vk <= cdb_value;
                    qk <= 4'd0;
                end
            end
            
        end
    end

endmodule