`timescale 1ns / 1ps

module fpga_top (
    input  wire        clk_100mhz,  // Physical 100MHz clock pin from your board
    input  wire        reset_btn,   // Physical reset button on your board
    output wire [7:0] led          // 16 physical LEDs on your board
);

    // -------------------------------------------------------------------------
    // 1. CLOCK DIVIDER (Crucial for FPGA timing)
    // -------------------------------------------------------------------------
    reg [23:0] clk_div;
    wire slow_clk;
    
    always @(posedge clk_100mhz) begin
        clk_div <= clk_div + 1;
    end
    
    // Dividing the clock down. If you get timing errors later, change this 
    // to clk_div[4] or higher to make the clock even slower!
    assign slow_clk = clk_div[2]; 

    // -------------------------------------------------------------------------
    // 2. PROCESSOR INSTANTIATION
    // -------------------------------------------------------------------------
    wire [7:0] final_processor_result;
    wire [31:0] dummy_commit_instr; // Just to connect the unused output

    // This calls your actual top_core.v file
    top_core my_tomasulo_processor (
        .clk             (slow_clk),
        .reset           (reset_btn),
        .demo_led_output (final_processor_result),
        .commit_instr    (dummy_commit_instr)
    );

    // -------------------------------------------------------------------------
    // 3. WIRING TO THE REAL WORLD
    // -------------------------------------------------------------------------
    // Connect the answer from your processor directly to the board's LEDs
    assign led = final_processor_result[7:0];

endmodule
