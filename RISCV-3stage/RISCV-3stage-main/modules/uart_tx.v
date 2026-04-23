`timescale 1ns / 1ps

module uart_tx #(
    // 100,000,000 Hz / 115200 Baud = 868 clock cycles per bit
    parameter CLKS_PER_BIT = 868 
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_en,      // Trigger from the Trace Buffer
    input  wire [7:0] tx_data,    // The 8-bit chunk to send
    output reg        tx_pin,     // The physical wire to the PC
    output reg        tx_busy     // Tells the Trace Buffer to wait
);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  state;
    reg [12:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  saved_data;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            state     <= IDLE;
            tx_pin    <= 1'b1; // UART idle state is HIGH
            tx_busy   <= 1'b0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_pin  <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_en) begin
                        saved_data <= tx_data; // Latch the data
                        tx_busy    <= 1'b1;    // Lock the transmitter
                        state      <= START;
                    end
                end

                START: begin
                    tx_pin <= 1'b0; // Pull low for Start Bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx_pin <= saved_data[bit_index]; // Send LSB first
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    tx_pin <= 1'b1; // Pull high for Stop Bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= IDLE; // Done! Ready for next byte.
                    end
                end
            endcase
        end
    end
endmodule
