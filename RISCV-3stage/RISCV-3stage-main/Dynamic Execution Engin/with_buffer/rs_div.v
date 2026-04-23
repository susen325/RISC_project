`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 06:07:35 PM
// Design Name: 
// Module Name: rs_div
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
`timescale 1ns/1ps

module rs_div #(parameter MY_TAG = 4'd3) (
    input  wire        clk,
    input  wire        reset,
    input  wire        pipeline_flush,

    // --- Dispatcher Issue Interface ---
    input  wire        issue_we,
    input  wire [31:0] issue_vj,
    input  wire [3:0]  issue_qj,
    input  wire [31:0] issue_vk,
    input  wire [3:0]  issue_qk,
    input  wire [3:0]  issue_rob_tag,
    output wire        rs_busy,

    // --- CDB Snooping Interface ---
    input  wire        cdb_valid,
    input  wire [3:0]  cdb_tag,
    input  wire [31:0] cdb_value,

    // --- Arbiter Broadcast Interface ---
    output reg         div_req,
    input  wire        div_grant,
    output reg  [3:0]  div_tag,
    output reg  [31:0] div_value
);

    // State Machine
    localparam IDLE = 0, WAIT_OP = 1, CALC = 2, DONE = 3;
    reg [1:0] state;

    // Reservation Station Waiting Room Registers
    reg [31:0] vj, vk;
    reg [3:0]  qj, qk;
    reg [3:0]  rob_tag;
    reg [4:0]  counter; // 32-cycle countdown timer

    assign rs_busy = (state != IDLE);

    always @(posedge clk or negedge reset) begin
        if (!reset || pipeline_flush) begin
            state   <= IDLE;
            div_req <= 1'b0;
            counter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    div_req <= 1'b0;
                    if (issue_we) begin
                        vj <= issue_vj; vk <= issue_vk;
                        qj <= issue_qj; qk <= issue_qk;
                        rob_tag <= issue_rob_tag;
                        
                        // If no hazards, jump straight to calculation!
                        if (issue_qj == 0 && issue_qk == 0) begin
                            state <= CALC;
                            counter <= 5'd31; // 32 cycles
                        end else begin
                            state <= WAIT_OP;
                        end
                    end
                end

                WAIT_OP: begin
                    // Eavesdrop on the Common Data Bus
                    if (cdb_valid) begin
                        if (qj != 0 && qj == cdb_tag) begin
                            vj <= cdb_value;
                            qj <= 4'b0;
                        end
                        if (qk != 0 && qk == cdb_tag) begin
                            vk <= cdb_value;
                            qk <= 4'b0;
                        end
                    end
                    // Did we just get the last piece of missing data?
                    if ((qj == 0 || (cdb_valid && qj == cdb_tag)) && 
                        (qk == 0 || (cdb_valid && qk == cdb_tag))) begin
                        state <= CALC;
                        counter <= 5'd31;
                    end
                end

                CALC: begin
                    if (counter == 0) begin
                        // RISC-V Spec: Safe Division By Zero
                        if (vk == 32'b0) begin
                            div_value <= 32'hFFFFFFFF; 
                        end else begin
                            div_value <= vj / vk; // Do the actual division
                        end
                        
                        div_tag   <= rob_tag;
                        div_req   <= 1'b1;    // Raise hand for Arbiter
                        state     <= DONE;
                    end else begin
                        counter <= counter - 1; // Count down
                    end
                end

                DONE: begin
                    if (div_grant) begin
                        div_req <= 1'b0;
                        state   <= IDLE; // Answer sent, back to sleep!
                    end
                end
            endcase
        end
    end
endmodule
