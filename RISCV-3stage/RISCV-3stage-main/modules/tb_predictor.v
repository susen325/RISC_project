`timescale 1ns/1ps

module tb_predictor();
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

    // --- Performance Tracking Variables ---
    integer total_branches = 0;
    integer correct_preds = 0;
    integer accuracy = 0;

    initial begin
        $display("==================================================");
        $display("   STARTING PIPELINE & PREDICTOR TORTURE TEST");
        $display("==================================================");
        reset = 1;
        #10;
        reset = 0; 
        #10;
        reset = 1;
        
        #1500; // Let the nested loops run
        
        $display("==================================================");
        $display("TEST COMPLETE. FINAL METRICS:");
        $display("Total Branch Evaluations : %0d", total_branches);
        $display("Successful Predictions   : %0d", correct_preds);
        $display("Final Hardware Accuracy  : %0d%%", accuracy);
        
        // Dead code check: x1 should NOT be 99!
        if (uut.regs[1] == 32'd99) begin
            $display("CRITICAL FAILURE: Pipeline Flush failed. Ghost instruction executed.");
        end else begin
            $display("PIPELINE FLUSH: Passed. (Dead code successfully skipped)");
        end
        $display("==================================================");
        $finish;
    end

    // --- The Live Performance Monitor ---
    always @(posedge clk) begin
        // Tap directly into the execute stage's evaluation signals
        if (uut.execute.bht_update_en) begin
            total_branches = total_branches + 1;
            
            if (uut.execute.mispredicted_o) begin
                accuracy = (correct_preds * 100) / total_branches;
                $display("[%0t ns] ❌ MISPREDICT on PC %h | Routing to %h | Accuracy: %0d%%", 
                         $time, uut.execute.pc, uut.execute.next_pc, accuracy);
            end else begin
                correct_preds = correct_preds + 1;
                accuracy = (correct_preds * 100) / total_branches;
                $display("[%0t ns] ✅ SUCCESS on PC %h    | 0-Cycle Stall!   | Accuracy: %0d%%", 
                         $time, uut.execute.pc, accuracy);
            end
        end
    end

endmodule