`timescale 1ns/1ps

module tb_ultimate_stress();
    reg clk;
    reg reset;

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

    instr_mem IMEM (.clk(clk), .pc(inst_mem_address), .instr(inst_mem_read_data));
    
    data_mem DMEM (
        .clk(clk), .re(dmem_read_ready), .raddr(dmem_read_address), .rdata(dmem_read_data),
        .we(dmem_write_ready), .waddr(dmem_write_address), .wdata(dmem_write_data), .wstrb(dmem_write_byte)
    );
    
    pipe uut (
        .clk(clk), .reset(reset), .stall(1'b0),
        .inst_mem_address(inst_mem_address), .inst_mem_is_valid(1'b1), .inst_mem_read_data(inst_mem_read_data),
        .dmem_read_address(dmem_read_address), .dmem_read_ready(dmem_read_ready),
        .dmem_read_data_temp(dmem_read_data), .dmem_read_valid(1'b1),
        .dmem_write_address(dmem_write_address), .dmem_write_ready(dmem_write_ready),
        .dmem_write_data(dmem_write_data), .dmem_write_byte(dmem_write_byte), .dmem_write_valid(1'b1),
        .pc_out(pc_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    integer errors = 0;

    initial begin
        $display("==================================================");
        $display("   STARTING SILICON BREAKER STRESS TEST");
        $display("==================================================");
        reset = 1; #10; reset = 0; #10; reset = 1;
    end

    // The Verification block
    // ==========================================
    // The Verification block
    // ==========================================
    initial begin
        // Wait for the CPU to reach the JAL trap
        wait(uut.execute.pc == 32'h0000_004C);
        #50; // Let writeback finish
        
        $display("\n--- TEST 1: Data Forwarding Hazards ---");
        check_reg(1, 32'd10, "RAW Back-to-Back (x1)");
        check_reg(2, 32'd20, "RAW Dual Source  (x2)");
        check_reg(3, 32'd10, "RAW Subtraction  (x3)");

        $display("\n--- TEST 2: Math/Branch Collision ---");
        check_reg(5, 32'd10, "DIV Hardware     (x5)");
        check_reg(31, 32'd0, "Branch Flush     (x31 - Dead Code Skipped)");

        $display("\n--- TEST 3: Zero Register Check ---");
        check_reg(6, 32'd10, "Zero Immutability(x6)");

        $display("\n--- TEST 4: HW Accelerator RAW ---");
        check_reg(9, 32'd10, "MANDIST Forwarding (x9)");

        $display("\n--- TEST 5: Predictor Loop ---");
        check_reg(10, 32'd0, "Loop Counter Exit (x10)");
        check_reg(11, 32'd6, "Loop Math Output  (x11)");

        $display("\n==================================================");
        if (errors == 0) begin
            $display("   [ 1000%% CERTIFIED. FLAWLESS SILICON. ]");
        end else begin
            $display("   [ PIPELINE FRACTURED: %0d ERRORS FOUND ]", errors);
        end
        $display("==================================================");
        $finish;
    end

    // ==========================================
    // The Timeout Block (Runs in parallel)
    // ==========================================
    initial begin
        #5000;
        $display("CRITICAL ERROR: Simulation timed out! CPU is stuck.");
        $finish;
    end

    // ==========================================
    // Helper Task
    // ==========================================
    task check_reg;
        input integer reg_num;
        input [31:0] expected;
        input [255:0] test_name;
        begin
            if (uut.regs[reg_num] !== expected) begin
                $display("FAIL | %s -> Expected: %0d | Actual: %0d", test_name, expected, uut.regs[reg_num]);
                errors = errors + 1;
            end else begin
                $display("PASS | %s -> Verified: %0d", test_name, expected);
            end
        end
    endtask
endmodule