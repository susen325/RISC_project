`timescale 1ns/1ps

module rs_mem #(
    parameter [3:0] MY_TAG = 4'd4 // Unique ID for the Memory Unit
)(
    input  wire        clk,
    input  wire        reset,
    
    // --- 1. Issue Stage (From Dispatcher) ---
    input  wire        issue_we,
    input  wire        issue_is_store,
    input  wire [31:0] issue_vj,       // Base Address Register Value
    input  wire [3:0]  issue_qj,       // Base Address Register Tag
    input  wire [31:0] issue_vk,       // Data to Store (for SW)
    input  wire [3:0]  issue_qk,       // Data to Store Tag
    input  wire [31:0] issue_imm,      // The offset immediate
    input  wire [3:0]  issue_rob_tag,  // The Ticket Number from the ROB
    output wire        rs_busy,

    // --- 2. CDB Snooping (Watching for missing operands) ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,
    
    // --- 3. Pipeline Flush (Branch Misprediction) ---
    input  wire        pipeline_flush,

    // --- 4. Direct RAM Interface (For Loads ONLY) ---
    output reg         mem_re,
    output reg  [31:0] mem_raddr,
    input  wire [31:0] mem_rdata,

    // --- 5. Arbiter Handshake (Broadcasting to CDB and ROB) ---
    output wire        mem_req,
    input  wire        mem_grant,
    output wire [3:0]  mem_tag,          
    output wire [31:0] mem_value,        // Data (Loaded data OR Store data)
    output wire [3:0]  mem_rob_tag,      
    output wire [31:0] mem_store_addr    // The calculated RAM address
);

    // Internal State
    reg busy;
    reg is_store;
    reg [31:0] vj, vk;
    reg [3:0]  qj, qk;
    reg [31:0] imm;
    reg [3:0]  my_rob_tag;
    
    // Execution State Tracking
    reg is_calculating;
    reg is_waiting_for_ram;
    reg is_waiting_for_bus;
    
    // The calculated address (Base + Offset)
    wire [31:0] calc_addr = vj + imm;
    
    // Hold the loaded data from RAM
    reg [31:0] loaded_data;

    assign rs_busy = busy;
    assign mem_req = is_waiting_for_bus;
    assign mem_tag = MY_TAG;
    assign mem_rob_tag = my_rob_tag;
    
    // If Store: Broadcast the data to save. If Load: Broadcast the RAM data.
    assign mem_value = is_store ? vk : loaded_data;
    assign mem_store_addr = calc_addr;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            busy <= 1'b0;
            is_calculating <= 1'b0;
            is_waiting_for_ram <= 1'b0;
            is_waiting_for_bus <= 1'b0;
            mem_re <= 1'b0;
            qj <= 4'b0; qk <= 4'b0;
        end else if (pipeline_flush) begin
            // Immediately clear the station if the branch predictor guessed wrong
            busy <= 1'b0;
            is_calculating <= 1'b0;
            is_waiting_for_ram <= 1'b0;
            is_waiting_for_bus <= 1'b0;
            mem_re <= 1'b0;
        end else begin
            
            // Default turn off RAM read
            mem_re <= 1'b0;
            
            // 1. CLEARING THE STATION (Instruction Finished)
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
                
                // CDB Bypass check: Grab data instantly if it's on the bus this exact cycle
                if (cdb_valid && issue_qj != 0 && issue_qj == cdb_tag) begin
                    vj <= cdb_value; qj <= 4'd0;
                end else begin
                    vj <= issue_vj; qj <= issue_qj;
                end

                if (cdb_valid && issue_qk != 0 && issue_qk == cdb_tag) begin
                    vk <= cdb_value; qk <= 4'd0;
                end else begin
                    vk <= issue_vk; qk <= issue_qk;
                end
            end 
            
            // 3. SNOOPING THE CDB (Waiting for operands)
            else if (busy && !is_calculating && !is_waiting_for_ram && !is_waiting_for_bus) begin
                if (qj != 4'd0 && cdb_valid && qj == cdb_tag) begin
                    vj <= cdb_value; qj <= 4'd0;
                end
                if (qk != 4'd0 && cdb_valid && qk == cdb_tag) begin
                    vk <= cdb_value; qk <= 4'd0;
                end
                
                // 4. READY TO EXECUTE!
                // Loads only need Base Address (qj). Stores need Base (qj) AND Data (qk).
                if (qj == 0 && (!is_store || qk == 0)) begin
                    is_calculating <= 1'b1;
                end
            end
            
            // 5. EXECUTING THE MEMORY OP
            else if (is_calculating) begin
                if (is_store) begin
                    // Store is easy! Address calculated, data ready. Go straight to bus.
                    is_calculating <= 1'b0;
                    is_waiting_for_bus <= 1'b1;
                end else begin
                    // Load requires triggering your BRAM read port
                    mem_re <= 1'b1;
                    mem_raddr <= calc_addr;
                    is_calculating <= 1'b0;
                    is_waiting_for_ram <= 1'b1;
                end
            end
            
            // 6. WAITING FOR RAM (Loads only)
            else if (is_waiting_for_ram) begin
                // BRAM takes 1 cycle. The data is now ready.
                loaded_data <= mem_rdata;
                is_waiting_for_ram <= 1'b0;
                is_waiting_for_bus <= 1'b1;
            end
        end
    end

endmodule
