`timescale 1ns/1ps

module mainpipeline(
    input clk,
    input rst,
    input usePredict,
    input [31:0] imemRdata,
    output [31:0] imemAddr,
    input [31:0] dmemRdata,
    output [31:0] dmemWdata,
    output [2:0] dmemSize,
    output dmemWen,
    output [31:0] dmemAddr
);

    // Localparams for MUX selection
    localparam RS1_SEL = 2'b0;
    localparam PC_SEL  = 2'b1;
    
    localparam ALU_SRC = 2'b00;
    localparam MEM_SRC = 2'b01;
    localparam PC_SRC  = 2'b10;

    // FETCH STAGE Signals
    reg [31:0] pcF;
    wire [31:0] pcFplus4;
    reg [31:0] pcF_, pcFsv, pcFplus4sv, instrFsv;
    wire bPredictTakenF;
    reg bPredictTakenFsv;
    wire [31:0] btbTargetF;

    // DECODE STAGE Signals
    wire [31:0] instrD;
    wire [31:0] rs1D, rs2D;
    wire [4:0] rdD, r1AddrD, r2AddrD;
    reg [4:0] rdDsv, r1AddrDsv, r2AddrDsv;
    reg [31:0] rs1Dsv, rs2Dsv;
    wire [31:0] pcD, pcDplus4;
    reg [31:0] pcDsv, pcDplus4sv;
    wire [31:0] immExtD;
    reg [31:0] immExtDsv;

    wire regWriteD, memWriteD, branchD, jumpD, aluSrcBD, invD, loadStoreD;
    reg regWriteDsv, memWriteDsv, branchDsv, jumpDsv, aluSrcBDsv, invDsv, loadStoreDsv;
    wire [1:0] aluSrcAD;
    reg [1:0] aluSrcADsv;
    wire pcTargetSrcD;
    reg pcTargetSrcDsv;
    wire [1:0] regSrcD;
    reg [1:0] regSrcDsv;
    wire [2:0] aluCntrlD;
    reg [2:0] aluCntrlDsv;
    wire useF7D;
    reg useF7Dsv;
    wire [2:0] immCntrlD;
    wire bPredictTakenD;
    reg bPredictTakenDsv;

    // EXECUTE STAGE Signals
    reg [31:0] srcAE;
    wire [31:0] srcBE;
    wire [31:0] aluResultE;
    reg [31:0] aluResultEsv;
    wire [31:0] pcE, immExtE, pcTargetE, pcEplus4;
    reg [31:0] pcEplus4sv;
    wire branchFlagE, pcSelE;
    wire [31:0] pcPlusImm;

    wire regWriteE, memWriteE, branchE, jumpE, aluSrcBE, invE, loadStoreE;
    reg regWriteEsv, memWriteEsv;
    wire [31:0] rs1E, rs2E;
    reg [31:0] rs1hzE, rs2hzE;
    wire [4:0] rdE, r1AddrE, r2AddrE;
    reg [31:0] rs2Esv;
    reg [4:0] rdEsv;
    wire [2:0] aluCntrlE;
    wire [2:0] loadStoreSizeE;
    reg [2:0] loadStoreSizeEsv;
    wire useF7E;
    wire [1:0] aluSrcAE;
    wire pcTargetSrcE;
    wire [1:0] regSrcE;
    reg [1:0] regSrcEsv;
    wire [1:0] fwdAE;
    wire [1:0] fwdBE;
    wire btbUpdateE;
    wire bPredictTakenE;
    wire [31:0] btbTargetE;
    wire wrongBranchE;

    // MEMORY STAGE Signals
    wire [31:0] aluResultM;
    reg [31:0] aluResultMsv;
    wire [31:0] writeDataM;
    wire [4:0] rdM;
    reg [4:0] rdMsv;
    wire [31:0] pcMplus4;
    reg [31:0] pcMplus4sv;
    reg [31:0] dmemRdataMsv;
    wire regWriteM;
    reg regWriteMsv;
    wire memWriteM;
    wire [1:0] regSrcM;
    reg [1:0] regSrcMsv;

    // WRITEBACK STAGE Signals
    wire [4:0] rdW;
    wire [31:0] pcWplus4;
    wire [31:0] aluResultW;
    wire [31:0] dmemRdataW;
    reg [31:0] resultW;
    wire [1:0] regSrcW;
    wire regWriteW;

    // HAZARD SIGNALS
    wire stallF, stallD, flushE, flushD;

    // --- FETCH STAGE Logic ---
    always @(*) 
    begin
        if (usePredict) 
        begin
            case ({wrongBranchE, bPredictTakenF})
                2'b10, 2'b11: pcF_ = pcTargetE;
                2'b01:        pcF_ = btbTargetF;
                default:      pcF_ = pcFplus4;
            endcase
        end 
        else 
        begin
            pcF_ = pcSelE ? pcTargetE : pcFplus4;
        end
    end
    
    assign pcFplus4 = pcF + 4;
    assign imemAddr = pcF;

    // --- DECODE STAGE Logic ---
    assign instrD = instrFsv;
    assign pcD = pcFsv;
    assign pcDplus4 = pcFplus4sv;
    assign rdD = instrD[11:7];
    assign r1AddrD = instrD[19:15];
    assign r2AddrD = instrD[24:20];
    assign bPredictTakenD = bPredictTakenFsv;

    // --- EXECUTE STAGE Logic ---
    assign rs1E = rs1Dsv;
    assign rs2E = rs2Dsv;
    assign pcE = pcDsv;
    assign pcEplus4 = pcDplus4sv;
    assign rdE = rdDsv;
    assign r1AddrE = r1AddrDsv;
    assign r2AddrE = r2AddrDsv;
    assign immExtE = immExtDsv;
    assign branchE = branchDsv;
    assign jumpE = jumpDsv;
    assign regWriteE = regWriteDsv;
    assign loadStoreE = loadStoreDsv;
    assign loadStoreSizeE = aluCntrlE;
    assign memWriteE = memWriteDsv;
    assign aluSrcBE = aluSrcBDsv;
    assign aluSrcAE = aluSrcADsv;
    assign regSrcE = regSrcDsv;
    assign invE = invDsv;
    assign aluCntrlE = aluCntrlDsv;
    assign useF7E = useF7Dsv;
    assign pcTargetSrcE = pcTargetSrcDsv;
    assign bPredictTakenE = bPredictTakenDsv;

    // Hazard Muxes
    always @(*) 
    begin
        case (fwdAE)
            2'b00:   rs1hzE = rs1E;
            2'b10:   rs1hzE = aluResultM;
            2'b01:   rs1hzE = resultW;
            default: rs1hzE = rs1E;
        endcase
    end

    always @(*) 
    begin
        case (fwdBE)
            2'b00:   rs2hzE = rs2E;
            2'b10:   rs2hzE = aluResultM;
            2'b01:   rs2hzE = resultW;
            default: rs2hzE = rs2E;
        endcase
    end

    always @(*) 
    begin
        case(aluSrcAE)
            RS1_SEL: srcAE = rs1hzE;
            PC_SEL:  srcAE = pcE;
            default: srcAE = 0;
        endcase
    end

    assign srcBE = aluSrcBE ? immExtE : rs2hzE;
    assign pcPlusImm = immExtE + pcE;
    assign btbTargetE = pcPlusImm;

    assign pcTargetE = (~pcSelE & bPredictTakenE & usePredict) ? pcEplus4 : (pcTargetSrcE ? aluResultE : pcPlusImm);
    assign pcSelE = (branchE & branchFlagE) ^ jumpE;
    assign btbUpdateE = (~pcTargetSrcE) & (branchE | jumpE);
    assign wrongBranchE = pcSelE ^ bPredictTakenE;

    // --- MEMORY STAGE Logic ---
    assign memWriteM = memWriteEsv;
    assign aluResultM = aluResultEsv;
    assign rdM = rdEsv;
    assign writeDataM = rs2Esv;
    assign regWriteM = regWriteEsv;
    assign dmemWen = memWriteM;
    assign pcMplus4 = pcEplus4sv;
    assign dmemAddr = aluResultM;
    assign dmemWdata = writeDataM;
    assign regSrcM = regSrcEsv;
    assign dmemSize = loadStoreSizeEsv;

    // --- WRITEBACK STAGE Logic ---
    assign rdW = rdMsv;
    assign regSrcW = regSrcMsv;
    assign pcWplus4 = pcMplus4sv;
    assign dmemRdataW = dmemRdataMsv;
    assign aluResultW = aluResultMsv;
    assign regWriteW = regWriteMsv;

    always @(*) 
    begin
        case (regSrcW)
            ALU_SRC: resultW = aluResultW;
            MEM_SRC: resultW = dmemRdataW;
            PC_SRC:  resultW = pcWplus4;
            default: resultW = 0;
        endcase
    end

    // --- Module Instantiations ---
    controlUnit cntrlU(
        .op(instrD[6:2]),
        .funct3(instrD[14:12]),
        .funct7_6(instrD[30]),
        .regWrite(regWriteD),
        .memWrite(memWriteD),
        .branch(branchD),
        .jump(jumpD),
        .aluCntrl(aluCntrlD),
        .useF7(useF7D),
        .immCntrl(immCntrlD),
        .aluSrcB(aluSrcBD),
        .aluSrcA(aluSrcAD),
        .pcTargetSrc(pcTargetSrcD),
        .regSrc(regSrcD),
        .inv(invD),
        .loadStore(loadStoreD)
    );

    immediate extImm(
        .immSrc(instrD[31:7]),
        .immCntrl(immCntrlD),
        .immExt(immExtD)
    );

    registerFile regF(
        .writeData(resultW),
        .addr1(instrD[19:15]),
        .addr2(instrD[24:20]),
        .writeAddr(rdW),
        .writeEn(regWriteW),
        .clk(clk),
        .reg1(rs1D),
        .reg2(rs2D)
    );

    alu alu_inst (
        .aluCntrl(aluCntrlE),
        .useF7(useF7E),
        .inv(invE),
        .loadStore(loadStoreE),
        .srcA(srcAE),
        .srcB(srcBE),
        .aluResult(aluResultE),
        .branchFlag(branchFlagE)
    );

    hazardUnit hzrdUnit (
        .fwdAE(fwdAE),
        .fwdBE(fwdBE),
        .r1AddrE(r1AddrE),
        .r2AddrE(r2AddrE),
        .rdM(rdM),
        .rdW(rdW),
        .regWriteM(regWriteM),
        .regWriteW(regWriteW),
        .stallD(stallD),
        .stallF(stallF),
        .flushE(flushE),
        .flushD(flushD),
        .r1AddrD(r1AddrD),
        .r2AddrD(r2AddrD),
        .rdE(rdE),
        .regSrcE0(regSrcE[0]),
        .wrongBranchE(wrongBranchE),
        .pcSelE(pcSelE),
        .usePredict(usePredict)
    );

    dynamic2bit bPredictor(
        .clk(clk),
        .rst(rst),
        .fetchPc(pcF),
        .fetchHit(bPredictTakenF),
        .fetchTarget(btbTargetF),
        .exPc(pcE),
        .exTaken(pcSelE),
        .exBranch(btbUpdateE),
        .exTarget(btbTargetE)
    );

    // --- Sequential Logic (Pipeline Registers) ---
    always @(posedge clk) 
    begin
        if (rst) 
        begin
            pcF <= 0;
            pcFsv <= 0;
            pcFplus4sv <= 0;
            instrFsv <= 0;
            bPredictTakenFsv <= 0;
            rs1Dsv <= 0;
            rs2Dsv <= 0;
            r1AddrDsv <= 0;
            r2AddrDsv <= 0;
            rdDsv <= 0;
            pcDplus4sv <= 0;
            pcDsv <= 0;
            immExtDsv <= 0;
            aluCntrlDsv <= 0;
            useF7Dsv <= 0;
            invDsv <= 0;
            regWriteDsv <= 0;
            loadStoreDsv <= 0;
            memWriteDsv <= 0;
            branchDsv <= 0;
            jumpDsv <= 0;
            aluSrcBDsv <= 0;
            aluSrcADsv <= 0;
            pcTargetSrcDsv <= 0;
            regSrcDsv <= 0;
            bPredictTakenDsv <= 0;
            aluResultEsv <= 0;
            rs2Esv <= 0;
            rdEsv <= 0;
            pcEplus4sv <= 0;
            regWriteEsv <= 0;
            regSrcEsv <= 0;
            memWriteEsv <= 0;
            loadStoreSizeEsv <= 0;
            dmemRdataMsv <= 0;
            rdMsv <= 0;
            pcMplus4sv <= 0;
            regWriteMsv <= 0;
            aluResultMsv <= 0;
            regSrcMsv <= 0;
        end 
        else 
        begin
            // Fetch Stage Pipeline
            if (!stallF) 
            begin
                pcF <= pcF_;
            end
            
            // Decode Stage Pipeline
            if (!stallD) 
            begin
                pcFsv <= pcF;
                pcFplus4sv <= pcFplus4;
                instrFsv <= imemRdata;
                bPredictTakenFsv <= bPredictTakenF;
            end
            
            if (flushD) 
            begin
                pcFsv <= 0;
                pcFplus4sv <= 0;
                instrFsv <= 0;
                bPredictTakenFsv <= 0;
            end

            // Execute Stage Pipeline
            if (flushE) 
            begin
                rs1Dsv <= 0; rs2Dsv <= 0; r1AddrDsv <= 0; r2AddrDsv <= 0;
                rdDsv <= 0; pcDplus4sv <= 0; pcDsv <= 0; immExtDsv <= 0;
                aluCntrlDsv <= 0; useF7Dsv <= 0; invDsv <= 0; regWriteDsv <= 0;
                memWriteDsv <= 0; branchDsv <= 0; jumpDsv <= 0; aluSrcBDsv <= 0;
                aluSrcADsv <= 0; pcTargetSrcDsv <= 0; loadStoreDsv <= 0;
                regSrcDsv <= 0; bPredictTakenDsv <= 0;
            end 
            else 
            begin
                rs1Dsv <= rs1D; rs2Dsv <= rs2D; r1AddrDsv <= r1AddrD; r2AddrDsv <= r2AddrD;
                rdDsv <= rdD; pcDplus4sv <= pcDplus4; pcDsv <= pcD; immExtDsv <= immExtD;
                aluCntrlDsv <= aluCntrlD; useF7Dsv <= useF7D; invDsv <= invD;
                regWriteDsv <= regWriteD; memWriteDsv <= memWriteD; branchDsv <= branchD;
                jumpDsv <= jumpD; aluSrcBDsv <= aluSrcBD; aluSrcADsv <= aluSrcAD;
                pcTargetSrcDsv <= pcTargetSrcD; loadStoreDsv <= loadStoreD;
                regSrcDsv <= regSrcD; bPredictTakenDsv <= bPredictTakenD;
            end

            // Memory Stage Pipeline
            aluResultEsv <= aluResultE;
            rs2Esv <= rs2hzE;
            rdEsv <= rdE;
            pcEplus4sv <= pcEplus4;
            regWriteEsv <= regWriteE;
            regSrcEsv <= regSrcE;
            memWriteEsv <= memWriteE;
            loadStoreSizeEsv <= loadStoreSizeE;

            // Writeback Stage Pipeline
            dmemRdataMsv <= dmemRdata;
            rdMsv <= rdM;
            pcMplus4sv <= pcMplus4;
            regWriteMsv <= regWriteM;
            aluResultMsv <= aluResultM;
            regSrcMsv <= regSrcM;
        end
    end

endmodule
