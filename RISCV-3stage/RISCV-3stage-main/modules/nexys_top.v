`timescale 1ns / 1ps

module top_fpga #(
    parameter IMEMSIZE = 4096,
    parameter DMEMSIZE = 4096
)(
    input  wire clk,        // 100 MHz board clock
    input  wire reset,      // Red C12 button (Active Low) - CPU WAKE/SLEEP
    input  [15:0] data_1,   // The 16 physical slide switches
    input  data_reset,      // Down Button - CLEARS ARRAY
    input  checker,         
    output [15:0] led,
    output [7:0]  an,      // NEW: Anodes
    output [6:0]  seg,     // NEW: Segments
    input  wire UART_RXD,   // Receives from PC
    output wire UART_TXD    // Sends to PC
);

// ---------------------------------------------------------
// 1. CLOCK DIVIDER (100 MHz to 10 Hz for the CPU)
// ---------------------------------------------------------
wire inst_mem_is_ready;
reg [25:0] clk_cnt = 0;       
reg        slow_clk = 0;

always @(posedge clk) begin
    if (clk_cnt == 26'd49_999_999) begin
        clk_cnt  <= 26'd0;
        slow_clk <= ~slow_clk; 
    end else begin
        clk_cnt <= clk_cnt + 1'b1;
    end
end

// ---------------------------------------------------------
// 2. CPU WIRES
// ---------------------------------------------------------
wire [31:0] current_pc; 
wire exception;
wire [31:0] inst_mem_read_data;
wire [31:0] inst_mem_address;
wire [31:0] dmem_read_data;
wire [31:0] dmem_read_address;
wire [31:0] dmem_write_address;
wire [31:0] dmem_write_data;
wire [3:0]  dmem_write_byte;
wire        dmem_read_ready;
wire        dmem_write_ready;
// ---------------------------------------------------------
// 3. INDUSTRIAL DEBOUNCER & ARRAY CAPTURE (Runs on 100 MHz)
// ---------------------------------------------------------
reg [15:0] data [0:3]; 
reg [1:0]  data_counter = 0;

reg [19:0] debounce_timer = 0;
reg        clean_button = 0;
reg        clean_button_prev = 0;

always @(posedge clk or posedge data_reset) begin 
    if(data_reset) begin
        data_counter <= 2'b0;
        data[0] <= 16'b0;
        data[1] <= 16'b0; 
        data[2] <= 16'b0; data[3] <= 16'b0;
        debounce_timer <= 0;
        clean_button <= 0;
        clean_button_prev <= 0;
    end
    else begin
        // Debouncer: Wait 10ms to ignore metal bouncing
        if (checker == 1'b1) begin
            if (debounce_timer < 20'd1_000_000)
                debounce_timer <= debounce_timer + 1;
            else
                clean_button <= 1'b1; 
        end else begin
            debounce_timer <= 0;
            clean_button <= 1'b0;
        end

        // Edge Detector: Only save once per push
        clean_button_prev <= clean_button;
        if(clean_button == 1'b1 && clean_button_prev == 1'b0) begin
            data[data_counter] <= data_1;
            data_counter <= data_counter + 1'b1; 
        end
    end
end

// ---------------------------------------------------------
// 4. ARRAY MMIO SWITCHBOARD (FIXED: 1-Cycle Latency)
// ---------------------------------------------------------
wire is_mmio = (dmem_read_address[31] == 1'b1);
wire is_ram  = (dmem_read_address[31] == 1'b0);

// 1. Combinational lookup based on current address
wire [31:0] mmio_read_data_comb = 
    (dmem_read_address[3:0] == 4'h0) ? {16'b0, data[0]} :
    (dmem_read_address[3:0] == 4'h4) ? {16'b0, data[1]} :
    (dmem_read_address[3:0] == 4'h8) ? {16'b0, data[2]} :
    (dmem_read_address[3:0] == 4'hC) ? {16'b0, data[3]} : 32'b0;

// 2. 1-Cycle Pipeline Registers to match RAM latency
reg [31:0] mmio_read_data_reg = 0;
reg        is_mmio_reg = 0;

// This runs on the same slow clock as the CPU pipeline
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        mmio_read_data_reg <= 32'b0;
        is_mmio_reg        <= 1'b0;
    end else begin
        mmio_read_data_reg <= mmio_read_data_comb;
        is_mmio_reg        <= is_mmio;
    end
end

// 3. The Multiplexer uses the DELAYED signals, not the instant ones!
wire [31:0] final_cpu_read_data = is_mmio_reg ? mmio_read_data_reg : dmem_read_data;

wire safe_ram_re = dmem_read_ready & is_ram;
wire safe_ram_we = dmem_write_ready & is_ram;
// ---------------------------------------------------------
// 5. PIPELINE & MEMORY BLOCKS
// ---------------------------------------------------------
pipe pipe_u (
    .clk(clk), 
    .reset(cpu_run_reset), // NEW: Uses the multiplexed sleep reset!
    .stall(1'b0),
    .exception(exception),
    .pc_out(current_pc), 
    .inst_mem_address(inst_mem_address), 
    .inst_mem_is_valid(1'b1),
    .inst_mem_read_data(inst_mem_read_data),
    .inst_mem_is_ready(inst_mem_is_ready), 
    .dmem_read_address(dmem_read_address), 
    .dmem_read_ready(dmem_read_ready), 
    .dmem_read_data_temp(final_cpu_read_data),
    .dmem_read_valid(1'b1),
    .dmem_write_address(dmem_write_address), 
    .dmem_write_ready(dmem_write_ready), 
    .dmem_write_data(dmem_write_data), 
    .dmem_write_byte(dmem_write_byte), 
    .dmem_write_valid(1'b1)
);

// ---------------------------------------------------------
// 6. UART RECEIVER & BOOTLOADER LOGIC
// ---------------------------------------------------------
wire prog_mode = data_1[15]; // Programming Switch

wire [7:0] rx_data;
wire       rx_valid;

uart_rx my_rx (
    .clk(clk),
    .reset(reset),
    .uart_rx_pin(UART_RXD), 
    .rx_data(rx_data),
    .rx_valid(rx_valid)
);

wire [31:0] boot_addr;
wire [31:0] boot_data;
wire        boot_we;

wire boot_reset = reset & prog_mode;
bootloader my_boot (
    .clk(clk),
    .reset(boot_reset),
    .rx_valid(rx_valid),
    .rx_data(rx_data),
    .imem_addr(boot_addr),
    .imem_data(boot_data),
    .imem_we(boot_we)
);

// CPU Sleep Logic
wire cpu_run_reset = reset & ~prog_mode; 

// The IMEM Multiplexer (CPU vs Bootloader)
wire [31:0] actual_imem_addr = prog_mode ? boot_addr : inst_mem_address;
wire [31:0] actual_imem_data = prog_mode ? boot_data : 32'b0; 
wire        actual_imem_we   = prog_mode ? boot_we   : 1'b0;  

instr_mem IMEM (
    .clk_read(clk),         // CPU reads at 10 Hz
    .clk_write(clk),             // Bootloader writes at 100 MHz
    .pc(actual_imem_addr), 
    .instr(inst_mem_read_data),
    .we(actual_imem_we),
    .addr(actual_imem_addr),
    .data_in(actual_imem_data)
);

data_mem DMEM (
    .clk(clk), .re(safe_ram_re), .raddr(dmem_read_address), 
    .rdata(dmem_read_data), .we(safe_ram_we), .waddr(dmem_write_address), 
    .wdata(dmem_write_data), .wstrb(dmem_write_byte)
);

// ---------------------------------------------------------
// 7. TRACE BUFFER & UART TRANSMITTER (For A* output)
// ---------------------------------------------------------
wire       uart_tx_en;
wire [7:0] uart_tx_data;
wire       uart_tx_busy;
 
// FIXED: Using actual CPU pipeline variables here
wire trace_we = (dmem_write_ready && (dmem_write_address == 32'h80000040));

trace_buffer my_trace_bram (
    .clk(clk),
    .reset(reset),
    .trace_we(trace_we),
    .trace_data(dmem_write_data), // FIXED variable name
    .tx_busy(uart_tx_busy),      
    .tx_en(uart_tx_en),          
    .tx_byte(uart_tx_data)       
);
   
uart_tx my_tx (
    .clk(clk),
    .reset(reset),
    .tx_en(uart_tx_en),          
    .tx_data(uart_tx_data),      
    .tx_pin(UART_TXD),           
    .tx_busy(uart_tx_busy)       
);

// ---------------------------------------------------------
// 8. LED & 7-SEGMENT OUTPUT REGISTERS 
// ---------------------------------------------------------
reg [15:0] led_reg = 0;
reg [31:0] sev_seg_reg = 0; 

wire is_mmio_write = (dmem_write_address[31] == 1'b1);
wire is_led_write     = is_mmio_write && (dmem_write_address[7:0] == 8'h08) && dmem_write_ready;
wire is_sev_seg_write = is_mmio_write && (dmem_write_address[7:0] == 8'h20) && dmem_write_ready;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        led_reg <= 16'b0;
        sev_seg_reg <= 32'b0;
    end else begin
        if (is_led_write)     led_reg <= dmem_write_data[15:0];
        if (is_sev_seg_write) sev_seg_reg <= dmem_write_data;
    end
end

assign led[13:0] = led_reg[13:0]; // Don't forget to wire the physical LEDs!
assign led[15] = clk;
assign led[14] = reset;

wire [31:0] debug_terminal = inst_mem_read_data;

sev_seg_driver DISPLAY (
    .clk(clk),              // Display multiplexer must run at 100MHz!
    .reset(reset),
    .display_data(debug_terminal), // Overridden with current instruction
    .an(an),
    .seg(seg)
);
endmodule
