`timescale 1ns/1ps

module rs_alu #(
    parameter [3:0] MY_TAG = 4'd1
)(
    input  wire        clk,
    input  wire        reset,
    
    // --- Issue Stage ---
    input  wire        issue_we,
    input  wire [6:0]  issue_opcode,
    input  wire [2:0]  issue_funct3,
    input  wire [31:0] issue_vj,       
    input  wire [3:0]  issue_qj,       
    input  wire [31:0] issue_vk,       
    input  wire [3:0]  issue_qk,       
    input  wire [31:0] issue_imm,     
    input  wire [3:0]  issue_rob_tag,  
    input  wire [31:0] issue_pc,       // Need PC for branch calculations
    output wire        rs_busy,

    // --- CDB Snooping ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    
    // --- Pipeline Flush ---
    input  wire        pipeline_flush,

    // --- Arbiter Handshake ---
    output wire        alu_req,
    input  wire        alu_grant,
    output wire [3:0]  alu_tag,          
    output wire [31:0] alu_value,        
    output wire        alu_mispredict    // Tells the ROB we guessed wrong!
);

    reg busy;
    reg [31:0] vj, vk, imm, pc;
    reg [3:0]  qj, qk;
    reg [6:0]  opcode;
    reg [2:0]  funct3;
    reg [3:0]  my_rob_tag;
    
    reg is_calculating;
    reg is_waiting_for_bus;
    reg [31:0] result;
    reg        mispredicted;

    assign rs_busy = busy;
    assign alu_req = is_waiting_for_bus;
    assign alu_tag = my_rob_tag;
    assign alu_value = result;
    assign alu_mispredict = mispredicted;

    always @(posedge clk or negedge reset) begin
        if (!reset || pipeline_flush) begin
            busy <= 1'b0;
            is_calculating <= 1'b0;
            is_waiting_for_bus <= 1'b0;
            qj <= 4'b0; qk <= 4'b0;
        end else begin
            
            // 1. CLEARING THE STATION
            if (alu_grant && is_waiting_for_bus) begin
                busy <= 1'b0;
                is_waiting_for_bus <= 1'b0;
            end 
            
            // 2. ISSUING NEW INSTRUCTION
            else if (issue_we && !busy) begin
                busy <= 1'b1;
                opcode <= issue_opcode;
                funct3 <= issue_funct3;
                imm <= issue_imm;
                pc <= issue_pc;
                my_rob_tag <= issue_rob_tag;
                
                // CDB Bypass
                if (cdb_valid && issue_qj != 0 && issue_qj == cdb_tag) begin
                    vj <= cdb_value; qj <= 4'd0;
                end else begin vj <= issue_vj; qj <= issue_qj; end

                if (cdb_valid && issue_qk != 0 && issue_qk == cdb_tag) begin
                    vk <= cdb_value; qk <= 4'd0;
                end else begin vk <= issue_vk; qk <= issue_qk; end
            end 
            
            // 3. SNOOPING THE CDB
            else if (busy && !is_calculating && !is_waiting_for_bus) begin
                if (qj != 4'd0 && cdb_valid && qj == cdb_tag) begin vj <= cdb_value; qj <= 4'd0; end
                if (qk != 4'd0 && cdb_valid && qk == cdb_tag) begin vk <= cdb_value; qk <= 4'd0; end
                
                // 4. READY TO EXECUTE!
                if (qj == 0 && qk == 0) is_calculating <= 1'b1;
            end
            
            // 5. THE ACTUAL MATH & BRANCH LOGIC
            else if (is_calculating) begin
                is_calculating <= 1'b0;
                is_waiting_for_bus <= 1'b1;
                mispredicted <= 1'b0; // Default to correct prediction
                
                // Standard I-Type Math (e.g., ADDI)
                if (opcode == 7'b0010011) begin
                    result <= vj + imm;
                end 
                // Standard R-Type Math (e.g., ADD, SUB)
                else if (opcode == 7'b0110011) begin
                    result <= vj + vk; // Expanded ALU logic goes here (SUB, AND, OR)
                end
                // Branch Logic (B-Type)
                else if (opcode == 7'b1100011) begin
                    if (funct3 == 3'b000) begin // BEQ
                        if (vj == vk) begin 
                            mispredicted <= 1'b1; // Trigger ROB flush!
                            result <= pc + imm;   // The correct address to jump to
                        end
                    end
                end
            end
        end
    end

endmodule
