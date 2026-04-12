`timescale 1ns/1ps

module hazardUnit(
    output reg [1:0] fwdAE,
    output reg [1:0] fwdBE,
    output wire flushE,
    output wire flushD,
    output wire stallD,
    output wire stallF,
    input [4:0] r1AddrE,
    input [4:0] r2AddrE,
    input [4:0] r1AddrD,
    input [4:0] r2AddrD,
    input [4:0] rdM,
    input [4:0] rdE,
    input [4:0] rdW,
    input regWriteM,
    input regWriteW,
    input regSrcE0,
    input usePredict,
    input pcSelE,       // for testing
    input wrongBranchE
);

    wire r1EqMem, r2EqMem, r1EqW, r2EqW;
    wire lwStall;
    wire bStall;        // for testing

    parameter [1:0] NO_FWD  = 2'b00;
    parameter [1:0] MEM_FWD = 2'b10;
    parameter [1:0] WB_FWD  = 2'b01;

    // Continuous assignments for stall and flush logic
    assign stallD = lwStall;
    assign bStall = usePredict ? wrongBranchE : pcSelE;
    assign flushE = lwStall | bStall;
    assign flushD = bStall;
    assign stallF = lwStall;

    // Hazard detection logic
    assign lwStall = regSrcE0 & ((r1AddrD == rdE) | (r2AddrD == rdE)) & (rdE != 5'b0);

    // Equality checks for forwarding
    assign r1EqMem = (r1AddrE == rdM) && (rdM != 5'b0);
    assign r2EqMem = (r2AddrE == rdM) && (rdM != 5'b0);
    assign r1EqW   = (r1AddrE == rdW) && (rdW != 5'b0);
    assign r2EqW   = (r2AddrE == rdW) && (rdW != 5'b0);

    // Forwarding logic for Operand A
    always @(*)
    begin
        if (r1EqMem && regWriteM)
            fwdAE = MEM_FWD;
        else if (r1EqW && regWriteW)
            fwdAE = WB_FWD;
        else
            fwdAE = NO_FWD;
    end

    // Forwarding logic for Operand B
    always @(*)
    begin
        if (r2EqMem && regWriteM)
            fwdBE = MEM_FWD;
        else if (r2EqW && regWriteW)
            fwdBE = WB_FWD;
        else
            fwdBE = NO_FWD;
    end

endmodule
