`timescale 1ns / 1ps

module bin_to_bcd (
    input  wire [15:0] bin,
    output reg  [19:0] bcd
);

    integer i;
    
    always @(*) begin
        bcd = 20'b0; // Initialize to zero
        
        // The Double Dabble Algorithm
        for (i = 15; i >= 0; i = i - 1) begin
            // If any BCD column is 5 or greater, add 3
            if (bcd[3:0]   >= 5) bcd[3:0]   = bcd[3:0]   + 3;
            if (bcd[7:4]   >= 5) bcd[7:4]   = bcd[7:4]   + 3;
            if (bcd[11:8]  >= 5) bcd[11:8]  = bcd[11:8]  + 3;
            if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
            if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
            
            // Shift everything left by 1
            bcd = {bcd[18:0], bin[i]};
        end
    end

endmodule
