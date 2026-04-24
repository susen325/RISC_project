`timescale 1ns / 1ps

module trace_buffer (
    input  wire        clk,
    input  wire        reset,
    
    // CPU Interface
    input  wire        trace_we,      // High when CPU writes to 0x80000040
    input  wire [31:0] trace_data,    // The data the CPU is writing
    
    // UART TX Interface
    input  wire        tx_busy,       // From your uart_tx module
    output reg         tx_en,         // Tells uart_tx to send a byte
    output reg  [7:0]  tx_byte        // The 8-bit slice being sent
);

    // 64-word BRAM (256 bytes) - Holds up to 64 coordinates
    reg [31:0] bram [0:63];
    reg [5:0]  write_ptr;
    reg [5:0]  dump_ptr;
    reg [5:0]  max_ptr;
    reg [1:0]  byte_idx; 

    // FSM States
    localparam IDLE       = 3'd0;
    localparam DUMP_WAIT  = 3'd1;
    localparam DUMP_PULSE = 3'd2;
    localparam DUMP_ACK   = 3'd3;
    localparam DUMP_NEXT  = 3'd4;

    reg [2:0] state;

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            write_ptr <= 0;
            dump_ptr  <= 0;
            tx_en     <= 0;
            state     <= IDLE;
        end else begin
            tx_en <= 0; // Default off so we only pulse it for 1 cycle

            case (state)
                IDLE: begin
                    if (trace_we) begin
                        bram[write_ptr] <= trace_data;
                        if (trace_data == 32'hFFFFFFFF) begin
                            // EOF marker detected! Lock the buffer and start UART dump
                            max_ptr  <= write_ptr;
                            dump_ptr <= 0;
                            byte_idx <= 0;
                            state    <= DUMP_WAIT;
                        end else begin
                            write_ptr <= write_ptr + 1; // Move to next RAM slot
                        end
                    end
                end

                DUMP_WAIT: begin
                    if (!tx_busy) state <= DUMP_PULSE; // Wait for UART to be free
                end

                DUMP_PULSE: begin
                    tx_en <= 1; // Trigger UART send
                    // Slice the 32-bit word into 8-bit chunks (Sending MSB first)
                    case (byte_idx)
                        2'd0: tx_byte <= bram[dump_ptr][31:24];
                        2'd1: tx_byte <= bram[dump_ptr][23:16];
                        2'd2: tx_byte <= bram[dump_ptr][15:8];
                        2'd3: tx_byte <= bram[dump_ptr][7:0];
                    endcase
                    state <= DUMP_ACK;
                end

                DUMP_ACK: begin
                    if (tx_busy) state <= DUMP_NEXT; // Wait for UART to acknowledge
                end

                DUMP_NEXT: begin
                    if (!tx_busy) begin // Wait for UART to finish sending the byte
                        if (byte_idx == 3) begin
                            byte_idx <= 0;
                            if (dump_ptr == max_ptr) begin
                                // Finished dumping! Reset for the next A* run
                                write_ptr <= 0;
                                state     <= IDLE;
                            end else begin
                                dump_ptr <= dump_ptr + 1; // Move to next 32-bit word
                                state    <= DUMP_WAIT;
                            end
                        end else begin
                            byte_idx <= byte_idx + 1; // Move to next byte in current word
                            state    <= DUMP_WAIT;
                        end
                    end
                end
            endcase
        end
    end
endmodule
