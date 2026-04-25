`timescale 1ns / 1ps

module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // 100 MHz board clock
    input  wire reset,      // Active-low reset (CPU_RESET button)
    
    // NEW PHYSICAL PINS FOR PERIPHERALS
    input  wire [15:0] sw,  // 16 slide switches for coordinates
    input  wire btn_c,      // Center button for Enter/Next
    output wire [15:0] led, // 16 LEDs
    output wire [7:0] an,   // 7-segment Anodes
    output wire [6:0] seg   // 7-segment Cathodes
);

    wire exception;
    wire [31:0] current_pc;
    
    // LEDs will just look dimly lit since the PC changes at 100MHz, 
    // but it proves the CPU is running!
    assign led = current_pc[15:0];

    // =========================================================
    // DEBOUNCERS (Cleaning up physical button noise)
    // =========================================================
    wire [15:0] clean_sw;
    wire        clean_btn_c;

    // Generate 16 debouncers for the 16 switches
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : debounce_switches
            debouncer u_deb_sw (
                .clk(clk),
                .noisy_in(sw[i]),
                .clean_out(clean_sw[i])
            );
        end
    endgenerate

    // Debouncer for the center button
    debouncer u_deb_btn (
        .clk(clk),
        .noisy_in(btn_c),
        .clean_out(clean_btn_c)
    );

    // =========================================================
    // PIPELINE -> MEMORY WIRES
    // =========================================================
    wire [31:0] inst_mem_read_data;
    wire        inst_mem_is_valid = 1'b1;
    wire [31:0] inst_mem_address;
    wire        inst_mem_is_ready;

    // CPU Data Memory Wires (Intercepted by MMIO)
    wire [31:0] cpu_dmem_raddr, cpu_dmem_waddr;
    wire [31:0] cpu_dmem_wdata, cpu_dmem_rdata;
    wire        cpu_dmem_re, cpu_dmem_we;
    wire [3:0]  cpu_dmem_wbyte; 

    // Actual Data Memory Wires
    wire [31:0] actual_dmem_rdata;
    wire        actual_dmem_re, actual_dmem_we;

    // Peripheral Wires
    wire [31:0] sev_seg_out_data;

    // =========================================================
    // MMIO BUS CONTROLLER (The Traffic Cop)
    // =========================================================
    mmio_controller u_mmio (
        .clk          (clk),
        .reset        (reset),
        
        // Connected to CPU Execute/WB stages
        .cpu_raddr    (cpu_dmem_raddr),
        .cpu_re       (cpu_dmem_re),
        .cpu_rdata    (cpu_dmem_rdata),
        
        .cpu_waddr    (cpu_dmem_waddr),
        .cpu_wdata    (cpu_dmem_wdata),
        .cpu_we       (cpu_dmem_we),
        
        // Connected to actual dmem.v
        .dmem_we      (actual_dmem_we),
        .dmem_re      (actual_dmem_re),
        .dmem_rdata   (actual_dmem_rdata),
        
        // Connected to Physical Hardware
        .switches     (clean_sw),
        .btn_c        (clean_btn_c),
        .sev_seg_data (sev_seg_out_data)
    );

    // =========================================================
    // 7-SEGMENT DISPLAY DRIVER
    // =========================================================
    sev_seg_driver u_display (
        .clk          (clk),
        .data_in      (sev_seg_out_data),
        .anode        (an),
        .cathode      (seg)
    );

    // =========================================================
    // CORE PROCESSOR PIPELINE
    // =========================================================
    pipe pipe_u (
        .clk                  (clk),           // Fast clock
        .reset                (reset),
        .stall                (1'b0),
        .exception            (exception),
        .pc_out               (current_pc), 
        
        .inst_mem_address     (inst_mem_address), 
        .inst_mem_is_valid    (inst_mem_is_valid),
        .inst_mem_read_data   (inst_mem_read_data),
        .inst_mem_is_ready    (inst_mem_is_ready), 

        // Route data memory ports to MMIO intercept wires
        .dmem_read_address    (cpu_dmem_raddr), 
        .dmem_read_ready      (cpu_dmem_re), 
        .dmem_read_data_temp  (cpu_dmem_rdata), // CPU gets data from MMIO
        .dmem_read_valid      (1'b1),
        
        .dmem_write_address   (cpu_dmem_waddr), 
        .dmem_write_ready     (cpu_dmem_we), 
        .dmem_write_data      (cpu_dmem_wdata), 
        .dmem_write_byte      (cpu_dmem_wbyte), 
        .dmem_write_valid     (1'b1)
    );

    // =========================================================
    // INSTRUCTION MEMORY (IMEM)
    // =========================================================
    instr_mem IMEM (
        .clk    (clk), 
        .pc     (inst_mem_address), 
        .instr  (inst_mem_read_data)
    );

    // =========================================================
    // DATA MEMORY (DMEM)
    // =========================================================
    data_mem DMEM (
        .clk    (clk), 
        .re     (actual_dmem_re),       // Controlled by MMIO
        .raddr  (cpu_dmem_raddr),       // Pass-through address
        .rdata  (actual_dmem_rdata),    // Feeds back to MMIO
        
        .we     (actual_dmem_we),       // Controlled by MMIO
        .waddr  (cpu_dmem_waddr),       // Pass-through address
        .wdata  (cpu_dmem_wdata),       // Pass-through data
        .wstrb  (cpu_dmem_wbyte)        // Pass-through byte enable
    );

endmodule