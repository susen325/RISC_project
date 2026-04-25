// ----------------------------------------------------------------------------
// Instruction Memory (IMEM) - 4KB FPGA-safe ROM
// ----------------------------------------------------------------------------
// ----------------------------------------------------------------------------
// Instruction Memory (IMEM) - 4KB FPGA-safe ROM
// ----------------------------------------------------------------------------
module instr_mem (
    input  wire        clk,
    input  wire [31:0] pc,
    output wire [31:0] instr // Changed to wire
);

    (* ram_style = "block" *)
    reg [31:0] imem [0:1023];

    // Initialize instruction memory from hex file
    initial begin
       $readmemh("imem.hex", imem); 
    end 

    // -> THE FIX: Asynchronous (Combinational) instruction fetch
    // This instantly provides the instruction without a 1-cycle ghost delay
    assign instr = imem[pc[11:2]];

endmodule

// ----------------------------------------------------------------------------
// Data Memory (DMEM) - 16KB FPGA-safe RAM with MMIO Protection
// ----------------------------------------------------------------------------
module data_mem (
    input         clk,

    // Read port
    input         re,
    input  [31:0] raddr,
    output reg [31:0] rdata,

    // Write port
    input         we,
    input  [31:0] waddr,
    input  [31:0] wdata,
    input  [3:0]  wstrb
);

    (* ram_style = "block" *)
    reg [31:0] dmem [0:4095]; // UPGRADED: 4096 words = 16 KB

    // Decode byte address to word index (Need 12 bits for 4096 words)
    wire [11:0] rindex = raddr[13:2];
    wire [11:0] windex = waddr[13:2];

    // --- HARDWARE MEMORY PROTECTION LOGIC ---
    // Safely ignore MMIO addresses (0x8...) and out-of-bounds addresses
    wire is_mmio_read  = (raddr[31:28] == 4'h8);
    wire is_mmio_write = (waddr[31:28] == 4'h8);
    wire valid_raddr   = (!is_mmio_read)  && ((raddr >> 2) < 4096);
    wire valid_waddr   = (!is_mmio_write) && ((waddr >> 2) < 4096);

    // Initialize data memory (Zero out everything, then load hex)
    integer i;
    initial begin
        for (i = 0; i < 4096; i = i + 1) begin
            dmem[i] = 32'd0;
        end
        $readmemh("dmem.hex", dmem); 
    end

    // ----------------------------------------------------------------------------
    // Read & Write Logic (Synchronous)
    // ----------------------------------------------------------------------------

    always @(posedge clk) begin
        // ---- PROTECTED WRITE ----
        if (we && valid_waddr) begin
            if (wstrb[0]) dmem[windex][7:0]   <= wdata[7:0];
            if (wstrb[1]) dmem[windex][15:8]  <= wdata[15:8];
            if (wstrb[2]) dmem[windex][23:16] <= wdata[23:16];
            if (wstrb[3]) dmem[windex][31:24] <= wdata[31:24];
        end

        // ---- PROTECTED READ (1-cycle latency, RAW-safe) ----
        if (re) begin
            if (!valid_raddr) begin
                // Return 0 for MMIO or out-of-bounds to prevent X-propagation
                rdata <= 32'd0;
            end
            else if (we && valid_waddr && (rindex == windex)) begin
                // Byte-level forwarding
                rdata[7:0]   <= wstrb[0] ? wdata[7:0]   : dmem[rindex][7:0];
                rdata[15:8]  <= wstrb[1] ? wdata[15:8]  : dmem[rindex][15:8];
                rdata[23:16] <= wstrb[2] ? wdata[23:16] : dmem[rindex][23:16];
                rdata[31:24] <= wstrb[3] ? wdata[31:24] : dmem[rindex][31:24];
            end
            else begin
                rdata <= dmem[rindex];
            end
        end
    end

endmodule
