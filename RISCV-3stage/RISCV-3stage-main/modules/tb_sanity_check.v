`timescale 1ns/1ps

module tb_sanity_check();
    reg clk;
    reg reset;

    // --- Memory Interfaces ---
    wire [31:0] pc_out;
    wire [31:0] inst_mem_address;
    wire [31:0] inst_mem_read_data;
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_read_data;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        dmem_write_ready;
    wire        dmem_read_ready;

    instr_mem IMEM (
        .clk(clk), 
        .pc(inst_mem_address), 
        .instr(inst_mem_read_data)
    );
    
    data_mem DMEM (
        .clk(clk),
        .re(dmem_read_ready),
        .raddr(dmem_read_address),
        .rdata(dmem_read_data),
        .we(dmem_write_ready),
        .waddr(dmem_write_address),
        .wdata(dmem_write_data),
        .wstrb(dmem_write_byte)
    );
    
    pipe uut (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .inst_mem_address(inst_mem_address),
        .inst_mem_is_valid(1'b1),
        .inst_mem_read_data(inst_mem_read_data),
        .dmem_read_address(dmem_read_address),
        .dmem_read_ready(dmem_read_ready),
        .dmem_read_data_temp(dmem_read_data),
        .dmem_read_valid(1'b1),
        .dmem_write_address(dmem_write_address),
        .dmem_write_ready(dmem_write_ready),
        .dmem_write_data(dmem_write_data),
        .dmem_write_byte(dmem_write_byte),
        .dmem_write_valid(1'b1),
        .pc_out(pc_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    integer errors = 0;

    initial begin
        $display("==================================================");
        $display("   STARTING FULL PIPELINE SANITY CHECK");
        $display("==================================================");
        reset = 1;
        #10;
        reset = 0; 
        #10;
        reset = 1;
        
        // Wait for CPU to reach the JAL halt instruction (PC = 0x38)
        // Wait for the JAL halt instruction to reach the EXECUTE stage
        // (This prevents the testbench from tripping on a fetched misprediction!)
        wait(uut.execute.pc == 32'h0000_0038);
        #50; // Give Writeback stage time to flush final results into registers // Give Writeback stage time to flush final results into registers
        
        $display("\n--- PHASE 1: Basic ALU & Memory ---");
        check_reg(1, 32'd10, "ADDI 1");
        check_reg(2, 32'd20, "ADDI 2");
        check_reg(3, 32'd30, "ADD");
        check_reg(4, 32'd30, "SW/LW Memory Interface");

        $display("\n--- PHASE 2: RV32M Extension ---");
        check_reg(5, 32'd200, "MUL (10 * 20)");
        check_reg(6, 32'd20,  "DIV (200 / 10)");

        $display("\n--- PHASE 3: Custom Accelerator ---");
        check_reg(7, 32'h0005000A, "LW Coord A");
        check_reg(8, 32'h00020006, "LW Coord B");
        check_reg(9, 32'd7,        "MANDIST (|5-2| + |10-6|)");

        $display("\n--- PHASE 4: Predictor Loop ---");
        check_reg(10, 32'd5, "Loop Target Limit");
        check_reg(11, 32'd5, "Loop Exit Counter");

        $display("\n==================================================");
        if (errors == 0) begin
            $display("   [  ALL SYSTEMS GO! 0 ERRORS DETECTED  ]");
        end else begin
            $display("   [  HARDWARE FAULT: %0d ERRORS DETECTED  ]", errors);
        end
        $display("==================================================");
        $finish;
    end

    // Helper task to cleanly check and log register values
    task check_reg;
        input integer reg_num;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (uut.regs[reg_num] !== expected) begin
                $display("FAIL | %s -> Expected: %0d (0x%h) | Actual: %0d (0x%h)", 
                         test_name, expected, expected, uut.regs[reg_num], uut.regs[reg_num]);
                errors = errors + 1;
            end else begin
                $display("PASS | %s -> Verified: %0d", test_name, expected);
            end
        end
    endtask

endmodule