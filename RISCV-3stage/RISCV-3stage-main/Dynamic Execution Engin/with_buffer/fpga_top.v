`timescale 1ns / 1ps

module fpga_top (
    input  wire        clk_100mhz,  // Physical 100MHz clock pin from your board
    input  wire        reset_btn,   // Physical reset button on your board
    output wire [15:0] led          // 16 physical LEDs on your board
);

    // -------------------------------------------------------------------------
    // 1. CLOCK DIVIDER (Slowing it down so your Tomasulo logic doesn't crash)
    // -------------------------------------------------------------------------
    reg [23:0] clk_div;
    wire slow_clk;
    
    always @(posedge clk_100mhz) begin
        clk_div <= clk_div + 1;
    end
    
    // Grabbing the 3rd bit divides the clock down so the FPGA can handle it
    // (If you want to see the LEDs change with your own eyes, use clk_div[23])
    assign slow_clk = clk_div[2]; 

    // -------------------------------------------------------------------------
    // 2. THE PROCESSOR INSTANTIATION
    // -------------------------------------------------------------------------
    wire [31:0] final_processor_result;

    // Instantiate your actual processor core here
    top_core my_tomasulo_processor (
        .clk     (slow_clk),
        .reset   (reset_btn),
        
        // You will need to add this output port to your top_core.v file!
        .debug_out (final_processor_result) 
    );

    // -------------------------------------------------------------------------
    // 3. WIRING TO THE REAL WORLD
    // -------------------------------------------------------------------------
    // Connect the lower 16 bits of your processor's answer to the physical LEDs
    assign led = final_processor_result[15:0];

endmodule
