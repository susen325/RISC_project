`timescale 1ns / 1ps

module fpga_top (
    input  wire        clk_100mhz,  
    input  wire        reset_btn,   
    output wire [15:0] led,         // Keep LEDs for heartbeat and raw binary
    output wire [6:0]  seg,         // 7-Segment Cathodes
    output wire [7:0]  an           // 7-Segment Anodes
);

    // -------------------------------------------------------------------------
    // 1. DUAL CLOCK DIVIDER
    // -------------------------------------------------------------------------
    reg [26:0] clk_div;
    wire slow_clk;
    wire fast_clk;
    
    always @(posedge clk_100mhz) begin
        clk_div <= clk_div + 1;
    end
    
    // bit 26 = ~0.74 Hz (1.3 seconds). Perfect for watching the processor.
    assign slow_clk = clk_div[26]; 
    
    // bit 16 = ~1.5 kHz. Perfect for blindingly fast multiplexing.
    assign fast_clk = clk_div[16]; 

    // -------------------------------------------------------------------------
    // 2. PROCESSOR INSTANTIATION
    // -------------------------------------------------------------------------
    wire [15:0] final_processor_result; 
    wire [31:0] dummy_commit_instr; 

    top_core my_tomasulo_processor (
        .clk             (slow_clk),     // Feed the SLOW clock to the brain
        .reset           (reset_btn),
        .demo_led_output (final_processor_result),
        .commit_instr    (dummy_commit_instr)
    );

// -------------------------------------------------------------------------
    // 3. BINARY TO DECIMAL CONVERTER
    // -------------------------------------------------------------------------
    wire [19:0] final_decimal_result; // 5-digit BCD wire

    bin_to_bcd my_converter (
        .bin (final_processor_result), // Take processor's binary answer
        .bcd (final_decimal_result)    // Convert it to decimal
    );

    // -------------------------------------------------------------------------
    // 4. 7-SEGMENT DISPLAY INSTANTIATION
    // -------------------------------------------------------------------------
    seven_segment_ctrl my_display (
        .fast_clk (fast_clk),            
        .reset    (reset_btn),
        .bcd_in   (final_decimal_result), // Feed the decimal to the display!
        .seg      (seg),
        .an       (an)
    );

    // -------------------------------------------------------------------------
    // 5. WIRING TO THE REAL WORLD
    // -------------------------------------------------------------------------
    assign led[15] = slow_clk; // Heartbeat
    assign led[14:0] = final_processor_result[14:0]; // Keep raw binary on LEDs

endmodule

