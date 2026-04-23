`timescale 1ns/1ps

module rs_mem #(
    parameter [3:0] MY_TAG = 4'd4 
)(
    input  wire        clk,
    input  wire        reset,
    
    // --- 1. Issue Stage ---
    input  wire        issue_we,
    input  wire        issue_is_store,
    input  wire [31:0] issue_vj,       
    input  wire [3:0]  issue_qj,       
    input  wire [31:0] issue_vk,       
    input  wire [3:0]  issue_qk,       
    input  wire [31:0] issue_imm,      
    input  wire [3:0]  issue_rob_tag,  
    output wire        rs_busy,

    // --- 2. CDB Snooping ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    
    // --- 3. Pipeline Flush ---
    input  wire        pipeline_flush,

    // --- 4. Direct RAM Interface ---
    output reg         mem_re,
    output reg  [31:0] mem_raddr,
    input  wire [31:0] mem_rdata,

    // --- 5. Arbiter Handshake ---
    output wire        mem_req,
    input  wire        mem_grant,
    output wire [3:0]  mem_tag,          
    output wire [31:0] mem_value,        
    output wire [3:0]  mem_rob_tag,      
    output wire [31:0] mem_store_addr,
    
    // --- 6. Memory Barrier (Load-Store Hazard Fix) ---
    input  wire        commit_mem_we 
);

    // Internal State
    reg busy;
    reg is_store;
    reg [31:0] vj, vk;
    reg [3:0]  qj, qk;
    reg [31:0] imm;
    reg [3:0]  my_rob_tag;
    reg [3:0]  pending_stores; // THE MEMORY BARRIER COUNTER
    
    // Execution State Tracking
    reg is_calculating;
    reg is_waiting_for_ram1; // Wait for BRAM Address
    reg is_waiting_for_ram2; // Wait for BRAM Data
    reg is_waiting_for_bus;
    
    wire [31:0] calc_addr = vj + imm;
    reg [31:0] loaded_data;

    assign rs_busy = busy;
    assign mem_req = is_waiting_for_bus;
    assign mem_tag = MY_TAG;
    assign mem_rob_tag = my_rob_tag;
    
    assign mem_value = is_store ? vk : loaded_data;
    assign mem_store_addr = calc_addr;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            busy <= 1'b0;
            is_calculating <= 1'b0;
            is_waiting_for_ram1 <= 1'b0;
            is_waiting_for_ram2 <= 1'b0;
            is_waiting_for_bus <= 1'b0;
            mem_re <= 1'b0;
            qj <= 4'b0; qk <= 4'b0;
            pending_stores <= 4'b0;
        end else if (pipeline_flush) begin
            busy <= 1'b0;
            is_calculating <= 1'b0;
            is_waiting_for_ram1 <= 1'b0;
            is_waiting_for_ram2 <= 1'b0;
            is_waiting_for_bus <= 1'b0;
            mem_re <= 1'b0;
            pending_stores <= 4'b0;
        end else begin
            
            // --- THE MEMORY BARRIER TRACKER ---
            case ({issue_we && issue_is_store, commit_mem_we})
                2'b10: pending_stores <= pending_stores + 1; // Store Issued
                2'b01: pending_stores <= pending_stores - 1; // Store Committed
                default: pending_stores <= pending_stores;
            endcase
            
            mem_re <= 1'b0; // Default turn off RAM read
            
            // 1. CLEARING THE STATION
            if (mem_grant && is_waiting_for_bus) begin
                busy <= 1'b0;
                is_waiting_for_bus <= 1'b0;
            end 
            
            // 2. ISSUING NEW INSTRUCTION
            else if (issue_we && !busy) begin
                busy <= 1'b1;
                is_store <= issue_is_store;
                imm <= issue_imm;
                my_rob_tag <= issue_rob_tag;
                
                if (cdb_valid && issue_qj != 0 && issue_qj == cdb_tag) begin
                    vj <= cdb_value; qj <= 4'd0;
                end else begin vj <= issue_vj; qj <= issue_qj; end

                if (cdb_valid && issue_qk != 0 && issue_qk == cdb_tag) begin
                    vk <= cdb_value; qk <= 4'd0;
                end else begin vk <= issue_vk; qk <= issue_qk; end
            end 
            
            // 3. SNOOPING THE CDB
            else if (busy && !is_calculating && !is_waiting_for_ram1 && !is_waiting_for_ram2 && !is_waiting_for_bus) begin
                if (qj != 4'd0 && cdb_valid && qj == cdb_tag) begin vj <= cdb_value; qj <= 4'd0; end
                if (qk != 4'd0 && cdb_valid && qk == cdb_tag) begin vk <= cdb_value; qk <= 4'd0; end
                
                // 4. READY TO EXECUTE!
                // THE FIX: Loads MUST wait for all pending stores to finish!
                if (qj == 0 && (!is_store || qk == 0)) begin
                    if (is_store || pending_stores == 0) begin
                        is_calculating <= 1'b1;
                    end
                end
            end
            
            // 5. EXECUTING THE MEMORY OP
            else if (is_calculating) begin
                if (is_store) begin
                    is_calculating <= 1'b0;
                    is_waiting_for_bus <= 1'b1;
                end else begin
                    mem_re <= 1'b1;
                    mem_raddr <= calc_addr;
                    is_calculating <= 1'b0;
                    is_waiting_for_ram1 <= 1'b1;
                end
            end
            
            // 6. WAITING FOR RAM (Cycle 1: RAM is registering the address)
            else if (is_waiting_for_ram1) begin
                is_waiting_for_ram1 <= 1'b0;
                is_waiting_for_ram2 <= 1'b1;
            end
            
            // 7. WAITING FOR RAM (Cycle 2: RAM has presented the data)
            else if (is_waiting_for_ram2) begin
                loaded_data <= mem_rdata;
                is_waiting_for_ram2 <= 1'b0;
                is_waiting_for_bus <= 1'b1;
            end
        end
    end

endmodule