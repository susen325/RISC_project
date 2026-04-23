`timescale 1ns/1ps

module rs_mul #(parameter MY_TAG = 4'd2) (
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
    output reg         mul_req,
    input  wire        mul_grant,
    output reg  [3:0]  mul_tag,
    output reg  [31:0] mul_value
);

    // State Machine
    localparam IDLE = 0, WAIT_OP = 1, CALC = 2, DONE = 3;
    reg [1:0] state;

    reg [31:0] vj, vk;
    reg [3:0]  qj, qk;
    reg [3:0]  rob_tag;
    reg [4:0]  counter;

    assign rs_busy = (state != IDLE);

    always @(posedge clk or negedge reset) begin
        if (!reset || pipeline_flush) begin
            state   <= IDLE;
            mul_req <= 1'b0;
            counter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    mul_req <= 1'b0;
                    if (issue_we) begin
                        rob_tag <= issue_rob_tag;
                        
                        // 🚀 THE FIX: Issue-Stage Forwarding!
                        // Check the CDB *while* we are being issued. 
                        // If the missing data is on the bus RIGHT NOW, grab it!
                        if (issue_qj != 0 && cdb_valid && issue_qj == cdb_tag) begin
                            vj <= cdb_value;
                            qj <= 4'b0;
                        end else begin
                            vj <= issue_vj;
                            qj <= issue_qj;
                        end
                        
                        if (issue_qk != 0 && cdb_valid && issue_qk == cdb_tag) begin
                            vk <= cdb_value;
                            qk <= 4'b0;
                        end else begin
                            vk <= issue_vk;
                            qk <= issue_qk;
                        end
                        
                        // If we have no missing data (or we just grabbed it off the bus), start calculating!
                        if ((issue_qj == 0 || (cdb_valid && issue_qj == cdb_tag)) && 
                            (issue_qk == 0 || (cdb_valid && issue_qk == cdb_tag))) begin
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
                        mul_value <= vj * vk;
                        mul_tag   <= rob_tag;
                        mul_req   <= 1'b1;
                        state     <= DONE;
                    end else begin
                        counter <= counter - 1;
                    end
                end

                DONE: begin
                    if (mul_grant) begin
                        mul_req <= 1'b0;
                        state   <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule