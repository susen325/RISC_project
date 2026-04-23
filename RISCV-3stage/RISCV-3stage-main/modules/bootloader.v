`timescale 1ns / 1ps

module bootloader (
    input  wire        clk,
    input  wire        reset,
    input  wire        rx_valid,    // From uart_rx
    input  wire [7:0]  rx_data,     // From uart_rx
    output reg  [31:0] imem_addr,   // Wires to Instruction Memory Address
    output reg  [31:0] imem_data,   // Wires to Instruction Memory Write Data
    output reg         imem_we      // Wires to Instruction Memory Write Enable
);

    reg [1:0] byte_count;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            byte_count <= 0;
            imem_addr  <= 32'h00000000;
            imem_data  <= 32'b0;
            imem_we    <= 0;
        end else begin
            imem_we <= 0; // Default to not writing
            
            if (rx_valid) begin
                // Shift the new 8-bit byte into the 32-bit word
                imem_data <= {rx_data, imem_data[31:8]}; 
                
                if (byte_count == 3) begin
                    // We have 4 bytes! Trigger write and increment address
                    imem_we    <= 1;
                    byte_count <= 0;
                    imem_addr  <= imem_addr + 4; 
                end else begin
                    byte_count <= byte_count + 1;
                end
            end
        end
    end
endmodule
