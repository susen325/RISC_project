`timescale 1ns/1ps

module btb (
    input clk,
    input reset,
    
    // --- READ PORT (Fetch Stage) ---
    input  [31:0] fetch_pc,
    output        predict_taken,
    output [31:0] predict_target,

    // --- WRITE PORT (Execute Stage) ---
    input         update_en,
    input  [31:0] update_pc,
    input         actual_taken,
    input  [31:0] actual_target
);

    reg [1:0]  bht_table [0:63]; // 2-bit counter
    reg [31:0] btb_table [0:63]; // Cached target addresses
    reg        valid_table [0:63]; // Is the target valid?

    wire [5:0] fetch_idx  = fetch_pc[7:2];
    wire [5:0] update_idx = update_pc[7:2];

    // Predict taken ONLY if the 2-bit counter says yes AND we have a valid target cached
    assign predict_taken  = bht_table[fetch_idx][1] && valid_table[fetch_idx];
    assign predict_target = btb_table[fetch_idx];

    integer i;
    // CHANGED: Use negedge and !reset to match the CPU's active-low architecture
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 64; i = i + 1) begin
                bht_table[i]   <= 2'b01; // Initialize to Weakly Not Taken
                btb_table[i]   <= 32'h0;
                valid_table[i] <= 1'b0;
            end
        end else if (update_en) begin
            // ... rest of the update logic stays exactly the same
            valid_table[update_idx] <= 1'b1;
            if (actual_taken) btb_table[update_idx] <= actual_target; // Cache the target

            // 2-Bit Saturating Counter Logic
            case (bht_table[update_idx])
                2'b00: bht_table[update_idx] <= actual_taken ? 2'b01 : 2'b00; // Strongly Not Taken
                2'b01: bht_table[update_idx] <= actual_taken ? 2'b10 : 2'b00; // Weakly Not Taken
                2'b10: bht_table[update_idx] <= actual_taken ? 2'b11 : 2'b01; // Weakly Taken
                2'b11: bht_table[update_idx] <= actual_taken ? 2'b11 : 2'b10; // Strongly Taken
            endcase
        end
    end
endmodule