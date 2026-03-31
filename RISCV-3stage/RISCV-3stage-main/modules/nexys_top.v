`timescale 1ns / 1ps

module nexys_top (
    input  wire        clk_100MHz, // 100 MHz clock from Nexys A7
    input  wire        btnC,       // Center button for Reset
    output wire [15:0] led         // 16 LEDs above the switches
);

    // Synchronize the reset button (active high button to active low reset)
    reg reset_n;
    always @(posedge clk_100MHz) begin
        reset_n <= ~btnC; 
    end

    // Processor wires
    wire [31:0] inst_mem_address;
    wire [31:0] inst_mem_read_data;
    wire [31:0] dmem_read_address;
    wire [31:0] dmem_read_data;
    wire [31:0] dmem_write_address;
    wire [31:0] dmem_write_data;
    wire [3:0]  dmem_write_byte;
    wire        dmem_write_ready;
    wire        dmem_read_ready;

    // Instantiate your processor pipeline
    pipe CPU (
        .clk                    (clk_100MHz),
        .reset                  (reset_n),
        .stall                  (1'b0),
        .exception              (),
        .pc_out                 (),
        
        .inst_mem_address       (inst_mem_address),
        .inst_mem_is_valid      (1'b1),
        .inst_mem_read_data     (inst_mem_read_data),
        .inst_mem_is_ready      (),
        
        .dmem_read_address      (dmem_read_address),
        .dmem_read_ready        (dmem_read_ready),
        .dmem_read_data_temp    (dmem_read_data),
        .dmem_read_valid        (1'b1),
        
        .dmem_write_address     (dmem_write_address),
        .dmem_write_ready       (dmem_write_ready),
        .dmem_write_data        (dmem_write_data),
        .dmem_write_byte        (dmem_write_byte),
        .dmem_write_valid       (1'b1)
    );

    // Instantiate Instruction Memory
    instr_mem IMEM (
        .clk    (clk_100MHz),
        .pc     (inst_mem_address),
        .instr  (inst_mem_read_data)
    );

    // Instantiate Data Memory
    data_mem DMEM (
        .clk    (clk_100MHz),
        .re     (dmem_read_ready),
        .raddr  (dmem_read_address),
        .rdata  (dmem_read_data),
        .we     (dmem_write_ready),
        .waddr  (dmem_write_address),
        .wdata  (dmem_write_data),
        .wstrb  (dmem_write_byte)
    );

    // --- LED Output Logic ---
    // Latch the lowest 16 bits of whatever the CPU writes to memory
    reg [15:0] led_reg;
    always @(posedge clk_100MHz or negedge reset_n) begin
        if (!reset_n)
            led_reg <= 16'b0;
        else if (dmem_write_ready) 
            led_reg <= dmem_write_data[15:0];
    end

    assign led = led_reg;

endmodule