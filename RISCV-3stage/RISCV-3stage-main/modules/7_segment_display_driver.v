`timescale 1ns / 1ps

module sev_seg_driver (
    input  wire        clk,          // 100 MHz clock
    input  wire        reset,        // Active Low reset
    input  wire [31:0] display_data, // The 32-bit number from the CPU
    output reg  [7:0]  an,           // Anode (Digit selector, Active Low)
    output reg  [6:0]  seg           // Cathode (Segment selector, Active Low)
);

    // 20-bit counter to slow down the 100MHz clock to a ~95Hz refresh rate
    reg [19:0] refresh_counter;
    wire [2:0] active_digit = refresh_counter[19:17]; // Top 3 bits select the digit (0-7)

    always @(posedge clk or negedge reset) begin
        if (!reset) refresh_counter <= 0;
        else        refresh_counter <= refresh_counter + 1;
    end

    // 1. ANODE MULTIPLEXER (Selects which of the 8 digits is currently ON)
    always @(*) begin
        case(active_digit)
            3'b000: an = 8'b11111110; // Digit 0 (Rightmost)
            3'b001: an = 8'b11111101; // Digit 1
            3'b010: an = 8'b11111011; // Digit 2
            3'b011: an = 8'b11110111; // Digit 3
            3'b100: an = 8'b11101111; // Digit 4
            3'b101: an = 8'b11011111; // Digit 5
            3'b110: an = 8'b10111111; // Digit 6
            3'b111: an = 8'b01111111; // Digit 7 (Leftmost)
            default: an = 8'b11111111;
        endcase
    end

    // 2. DATA MULTIPLEXER (Selects the 4-bit nibble for the current digit)
    reg [3:0] current_nibble;
    always @(*) begin
        case(active_digit)
            3'b000: current_nibble = display_data[3:0];
            3'b001: current_nibble = display_data[7:4];
            3'b010: current_nibble = display_data[11:8];
            3'b011: current_nibble = display_data[15:12];
            3'b100: current_nibble = display_data[19:16];
            3'b101: current_nibble = display_data[23:20];
            3'b110: current_nibble = display_data[27:24];
            3'b111: current_nibble = display_data[31:28];
            default: current_nibble = 4'b0000;
        endcase
    end

    // 3. HEX TO 7-SEGMENT DECODER (Active LOW for Nexys A7)
    always @(*) begin
        case(current_nibble)
            //                GFEDCBA
            4'h0: seg = 7'b1000000; 
            4'h1: seg = 7'b1111001; 
            4'h2: seg = 7'b0100100; 
            4'h3: seg = 7'b0110000; 
            4'h4: seg = 7'b0011001; 
            4'h5: seg = 7'b0010010; 
            4'h6: seg = 7'b0000010; 
            4'h7: seg = 7'b1111000; 
            4'h8: seg = 7'b0000000; 
            4'h9: seg = 7'b0010000; 
            4'hA: seg = 7'b0001000; 
            4'hB: seg = 7'b0000011; 
            4'hC: seg = 7'b1000110; 
            4'hD: seg = 7'b0100001; 
            4'hE: seg = 7'b0000110; 
            4'hF: seg = 7'b0001110; 
            default: seg = 7'b1111111;
        endcase
    end
endmodule