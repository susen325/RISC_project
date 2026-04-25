`timescale 1ns / 1ps

module core_isolate_tb;
    reg clk;
    reg reset;
    
    wire [31:0] current_pc;
    wire exception;

    // Wires to connect CPU to Memory
    wire [31:0] inst_mem_address, inst_mem_read_data;
    wire inst_mem_is_ready;
    wire [31:0] dmem_raddr, dmem_waddr, dmem_wdata, dmem_rdata;
    wire dmem_re, dmem_we;
    wire [3:0] dmem_wbyte;

    // 1. INSTANTIATE PROCESSOR ONLY
    pipe u_cpu (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .exception(exception),
        .pc_out(current_pc),
        
        .inst_mem_address(inst_mem_address),
        .inst_mem_is_valid(1'b1),
        .inst_mem_read_data(inst_mem_read_data),
        .inst_mem_is_ready(inst_mem_is_ready),

        .dmem_read_address(dmem_raddr),
        .dmem_read_ready(dmem_re),
        .dmem_read_data_temp(dmem_rdata),
        .dmem_read_valid(1'b1),
        
        .dmem_write_address(dmem_waddr),
        .dmem_write_ready(dmem_we),
        .dmem_write_data(dmem_wdata),
        .dmem_write_byte(dmem_wbyte),
        .dmem_write_valid(1'b1)
    );

    // 2. INSTANTIATE MEMORY ONLY
    instr_mem u_imem (
        .clk(clk),
        .pc(inst_mem_address),
        .instr(inst_mem_read_data)
    );

    data_mem u_dmem (
        .clk(clk),
        .re(dmem_re),
        .raddr(dmem_raddr),
        .rdata(dmem_rdata),
        .we(dmem_we),
        .waddr(dmem_waddr),
        .wdata(dmem_wdata),
        .wstrb(dmem_wbyte)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize strictly to 0
        clk = 0;
        reset = 0; // Assert reset (Assuming active-low based on your top file)
        
        // 2. Hold reset for a few clock cycles to let flip-flops catch it
        #20;
        reset = 1; // Release reset
        
        // 3. Let it run for just a few instructions
        #100;
        $finish;
    end
endmodule