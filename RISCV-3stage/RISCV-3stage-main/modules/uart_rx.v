`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 868 
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       uart_rx_pin,
    output reg [7:0]  rx_data,
    output reg        rx_valid       // Goes HIGH for 1 clock cycle when a full 8-bit byte is ready
);

    parameter IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;
    reg [1:0]  state = IDLE;
    reg [13:0] clk_count = 0;
    reg [2:0]  bit_index = 0;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state <= IDLE;
            rx_valid <= 0;
            rx_data <= 0;
        end else begin
            // Default to 0 unless a byte just finished
            rx_valid <= 0; 
            
            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (uart_rx_pin == 0) // Start bit detected!
                        state <= START;
                end
                
                START: begin
                    if (clk_count == (CLKS_PER_BIT / 2)) begin
                        if (uart_rx_pin == 0) begin // Confirm it's still low (not a glitch)
                            clk_count <= 0;
                            state <= DATA;
                        end else state <= IDLE;
                    end else clk_count <= clk_count + 1;
                end
                
                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        rx_data[bit_index] <= uart_rx_pin; // Sample the bit
                        if (bit_index < 7) bit_index <= bit_index + 1;
                        else state <= STOP;
                    end
                end
                
                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        rx_valid <= 1; // Signal that rx_data is ready!
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
