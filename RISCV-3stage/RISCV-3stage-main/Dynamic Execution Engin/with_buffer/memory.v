`timescale 1ns/1ps

// ============================================================================
// INSTRUCTION MEMORY (ROM)
// ============================================================================
// ============================================================================
// INSTRUCTION MEMORY (ROM)
// ============================================================================
module instr_mem (
    input  wire        clk,
    input  wire [31:0] pc,
    output wire [31:0] instr  
);

    reg [31:0] mem [0:1023];
    integer i;

    initial begin
        // 1. FIRST: Fill the entire memory with zeros (RISC-V NOPs)
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'b0;
        end
        
        // 2. SECOND: Load your 5 instructions over the zeros
        $readmemh("/home/cse/cs224/imem.hex", mem);
    end

    // Asynchronous Read: Updates instantly when PC changes
    assign instr = mem[pc[11:2]]; 

endmodule


// ============================================================================
// DATA MEMORY (RAM)
// ============================================================================
module data_mem (
    input  wire        clk,
    
    // Read Port (Driven by rs_mem.v)
    input  wire        re,
    input  wire [31:0] raddr,
    output reg  [31:0] rdata,
    
    // Write Port (Driven strictly by rob.v)
    input  wire        we,
    input  wire [31:0] waddr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb  // Write Strobes for Byte/Halfword/Word precision
);

    // 4KB of Data Memory (1024 words x 32 bits)
    reg [31:0] mem [0:1023];

    // Initialize RAM to zero to prevent 'X' states in simulation
    integer i;
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'b0;
        end
    end

    always @(posedge clk) begin
        // 1. SYNCHRONOUS WRITE WITH BYTE STROBES
        if (we) begin
            if (wstrb[0]) mem[waddr[11:2]][7:0]   <= wdata[7:0];
            if (wstrb[1]) mem[waddr[11:2]][15:8]  <= wdata[15:8];
            if (wstrb[2]) mem[waddr[11:2]][23:16] <= wdata[23:16];
            if (wstrb[3]) mem[waddr[11:2]][31:24] <= wdata[31:24];
        end

        // 2. SYNCHRONOUS READ WITH RAW FORWARDING
        if (re) begin
            // Read-After-Write (RAW) Hazard Protection:
            // If the processor tries to read and write to the exact same address 
            // on the exact same clock cycle, instantly forward the new data.
            if (we && (waddr[11:2] == raddr[11:2])) begin
                rdata <= wdata;
            end else begin
                rdata <= mem[raddr[11:2]];
            end
        end
    end

endmodule
