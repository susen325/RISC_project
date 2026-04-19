`timescale 1ns/1ps

module tb_pipe_dynamic;

    reg clk;
    reg reset;

    // Interface to Instruction Memory
    wire [31:0] inst_mem_address;
    reg         inst_mem_is_valid;
    reg  [31:0] inst_mem_read_data;

    // Simulated Instruction Memory (ROM)
    reg [31:0] imem [0:15];

    // Instantiate the Dynamic Pipeline
    pipe_dynamic DUT (
        .clk(clk),
        .reset(reset),
        .inst_mem_address(inst_mem_address),
        .inst_mem_is_valid(inst_mem_is_valid),
        .inst_mem_read_data(inst_mem_read_data)
    );

    // 10ns Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instruction Memory Read Logic
    always @(*) begin
        // Convert byte address to word index
        inst_mem_read_data = imem[inst_mem_address >> 2];
        inst_mem_is_valid  = 1'b1;
    end

    // Test Sequence
    initial begin
        $display("=================================================");
        $display("   TOMASULO PIPELINE INTEGRATION TEST            ");
        $display("=================================================");

        // 1. Load the Hex File
        $readmemh("imem_dynamic.hex", imem);

        // 2. Pre-load the Register File with dummy values!
        // (Using Verilog hierarchical paths to peek inside the DUT)
        DUT.regs[1] = 32'd10;  // x1 = 10
        DUT.regs[2] = 32'd20;  // x2 = 20
        DUT.regs[5] = 32'd5;   // x5 = 5
        DUT.regs[7] = 32'd100; // x7 = 100
        DUT.regs[8] = 32'd200; // x8 = 200

        // 3. Reset the processor
        reset = 0;
        #15;
        reset = 1;

        // 4. Let it run for 10 clock cycles
        #100;
        
        $display("=================================================");
        $display(" FINAL REGISTER STATE:");
        $display(" x3 (Should be 30):  %0d", DUT.regs[3]);
        $display(" x4 (Should be 25):  %0d", DUT.regs[4]);
        $display(" x6 (Should be 300): %0d", DUT.regs[6]);
        $display("=================================================");
        $finish;
    end

    // Snoop the Common Data Bus (CDB) to see Out-of-Order execution happen!
    always @(posedge clk) begin
        if (DUT.DYN_EX.cdb_valid) begin
            $display("[Time %0t] CDB BROADCAST -> Tag: %0d | Value: %0d | Dest Reg: x%0d", 
                     $time, DUT.DYN_EX.cdb_tag, DUT.DYN_EX.cdb_value, DUT.DYN_EX.wb_rd);
        end
    end

endmodule