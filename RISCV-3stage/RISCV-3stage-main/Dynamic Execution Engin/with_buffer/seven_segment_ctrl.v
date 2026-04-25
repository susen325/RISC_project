`timescale 1ns / 1ps

module seven_segment_ctrl (
    input  wire        fast_clk, 
    input  wire        reset,
    input  wire [19:0] bcd_in,   // NOW EXPECTS 20-BIT BCD
    output reg  [6:0]  seg,      
    output reg  [7:0]  an        
);

    reg [2:0] digit_select; // 3-bit counter to cycle 0 through 4
    reg [3:0] bcd_val;      

    // 1. Cycle through the digits rapidly
    always @(posedge fast_clk or negedge reset) begin
        if (!reset) digit_select <= 3'b000;
        else if (digit_select == 3'd4) digit_select <= 3'b000; // Reset after 5th digit
        else digit_select <= digit_select + 1;
    end

    // 2. Select the correct BCD digit and turn on the correct Anode
    always @(*) begin
        an = 8'b11111111; // Default: Turn OFF all 8 digits
        bcd_val = 4'b0000;
        
        case (digit_select)
            3'd0: begin an[0] = 1'b0; bcd_val = bcd_in[3:0];   end // Ones
            3'd1: begin an[1] = 1'b0; bcd_val = bcd_in[7:4];   end // Tens
            3'd2: begin an[2] = 1'b0; bcd_val = bcd_in[11:8];  end // Hundreds
            3'd3: begin an[3] = 1'b0; bcd_val = bcd_in[15:12]; end // Thousands
            3'd4: begin an[4] = 1'b0; bcd_val = bcd_in[19:16]; end // Ten-Thousands
        endcase
    end

    // 3. Decimal to 7-Segment Decoder
    always @(*) begin
        case (bcd_val)
            4'h0: seg = 7'b1000000; // 0
            4'h1: seg = 7'b1111001; // 1
            4'h2: seg = 7'b0100100; // 2
            4'h3: seg = 7'b0110000; // 3
            4'h4: seg = 7'b0011001; // 4
            4'h5: seg = 7'b0010010; // 5
            4'h6: seg = 7'b0000010; // 6
            4'h7: seg = 7'b1111000; // 7
            4'h8: seg = 7'b0000000; // 8
            4'h9: seg = 7'b0010000; // 9
            default: seg = 7'b1111111; // Blank
        endcase
    end
endmodule