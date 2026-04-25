 // ----------------------------------------------------------------------------

// Stage 3: Write Back // no need to change 

// ----------------------------------------------------------------------------

module wb 

#(

    parameter [31:0] RESET = 32'h0000_0000

)

(

    input clk,

    input reset,


    input        stall_read_i,

    input [31:0] fetch_pc_i,


    input        wb_branch_i,

    input        wb_mem_to_reg_i,

    input        mem_write_i,


    input [31:0] write_address_i,

    input [31:0] alu_operand2_i,

    input [2:0]  alu_operation_i,


    input [2:0]  wb_alu_operation_i,

    input [1:0]  wb_read_address_i,


    input [31:0] dmem_read_data_i,

    input        dmem_write_valid_i,


    // Outputs

    output [31:0] inst_mem_address_o,

    output inst_mem_is_ready_o,

    output wb_stall_o,

    output reg [31:0] wb_write_address_o,

    output reg [31:0] wb_write_data_o,

    output reg [3:0]  wb_write_byte_o,

    output reg [31:0] wb_read_data_o,

    output reg [31:0] inst_fetch_pc_o,

    output reg wb_stall_first_o,

    output reg wb_stall_second_o

);


// import "opcode.vh" for OPCODES

// ============================================================================
// THE NUCLEAR FIX: Opcodes safely hardcoded directly into the module
// ============================================================================
`ifndef OPCODES_DEF
`define OPCODES_DEF
`define OPCODE      6:0
`define FUNC3       14:12
`define FUNCT7      31:25
`define SUBTYPE     30
`define RD          11:7
`define RS1         19:15
`define RS2         24:20
`endif

localparam  [31: 0] NOP     = 32'h0000_0013;

localparam  [ 6: 0] LUI     = 7'b0110111,
                    JAL     = 7'b1101111,
                    JALR    = 7'b1100111,
                    BRANCH  = 7'b1100011,
                    LOAD    = 7'b0000011,
                    STORE   = 7'b0100011,
                    ARITHI  = 7'b0010011,
                    ARITHR  = 7'b0110011,
                    CUSTOM0 = 7'b0001011;

localparam  [ 6: 0] M_EXT   = 7'b0000001;

localparam  [ 2: 0] BEQ     = 3'b000,
                    BNE     = 3'b001,
                    BLT     = 3'b100,
                    BGE     = 3'b101,
                    BLTU    = 3'b110,
                    BGEU    = 3'b111;

localparam  [ 2: 0] LB      = 3'b000,
                    LH      = 3'b001,
                    LW      = 3'b010,
                    LBU     = 3'b100,
                    LHU     = 3'b101;

localparam  [ 2: 0] SB      = 3'b000,
                    SH      = 3'b001,
                    SW      = 3'b010;
                    
localparam  [ 2: 0] ADD     = 3'b000,
                    SLL     = 3'b001,
                    SLT     = 3'b010,
                    SLTU    = 3'b011,
                    XOR     = 3'b100,
                    SR      = 3'b101,
                    OR      = 3'b110,
                    AND     = 3'b111;

localparam  [ 2: 0] MUL     = 3'b000,
                    MULH    = 3'b001,
                    MULHSU  = 3'b010,
                    MULHU   = 3'b011,
                    DIV     = 3'b100,
                    DIVU    = 3'b101,
                    REM     = 3'b110,
                    REMU    = 3'b111;

localparam  [ 2: 0] MANDIST_F3 = 3'b000;
// ============================================================================



// ----------------------------------------------------------------------------

// Instruction Memory Interface (Fetch PC generation)

// ----------------------------------------------------------------------------


assign inst_mem_address_o  = fetch_pc_i;

assign inst_mem_is_ready_o = !stall_read_i;


// ----------------------------------------------------------------------------

// WB Stall Logic

// ----------------------------------------------------------------------------


assign wb_stall_o = wb_stall_first_o || wb_stall_second_o;


// ----------------------------------------------------------------------------

// Instruction Fetch PC Update

// ----------------------------------------------------------------------------


// Drive instruction memory address using the current fetch PC

// Instruction fetch must be disabled when a read stall is asserted


always @(posedge clk or negedge reset) begin

    if (!reset)

        inst_fetch_pc_o <= RESET; // reset to instruction fetch program counter

    else if (!stall_read_i)

        inst_fetch_pc_o <= fetch_pc_i; // fetch the next instruction

end


// ----------------------------------------------------------------------------

// Branch Stall Generation

// ----------------------------------------------------------------------------


// Generate two-cycle stall for branch instructions

// - First cycle: stall when branch is detected

// - Second cycle: extend stall by one more cycle

// - Stall must not advance when a pending load has not completed


always @(posedge clk or negedge reset) begin

    if (!reset) begin

        wb_stall_first_o  <= 1'b0;

        wb_stall_second_o <= 1'b0;

    end

    else if (!stall_read_i &&

            !((wb_mem_to_reg_i && !dmem_write_valid_i))) begin

        wb_stall_first_o  <= wb_branch_i;

        wb_stall_second_o <= wb_stall_first_o;

    end

end


// ----------------------------------------------------------------------------

// Data Memory Write (Store Instructions)

// ----------------------------------------------------------------------------


// Prepare data memory write signals for store instructions

// - Generate write address

// - Generate write data with proper byte replication

// - Generate byte-enable signals based on address alignment


always @(posedge clk or negedge reset) begin

    if (!reset) begin

        wb_write_address_o <= 32'h0;

        wb_write_byte_o    <= 4'h0;

        wb_write_data_o    <= 32'h0;

    end

    else if (!stall_read_i && mem_write_i) begin

        wb_write_address_o <= write_address_i;

        case (alu_operation_i)


            SB: begin

                wb_write_data_o <= {4{alu_operand2_i[7:0]}};

                case (write_address_i[1:0])

                    2'b00:  wb_write_byte_o <= 4'b0001;

                    2'b01:  wb_write_byte_o <= 4'b0010;

                    2'b10:  wb_write_byte_o <= 4'b0100;

                    default:wb_write_byte_o <= 4'b1000;

                endcase

            end

            SH: begin

                wb_write_data_o <= {2{alu_operand2_i[15:0]}};

                wb_write_byte_o <= write_address_i[1] ? 4'b1100 : 4'b0011;

            end

            SW: begin

                wb_write_data_o <= alu_operand2_i;

                wb_write_byte_o <= 4'b1111;

            end

            default: begin

                wb_write_data_o <= 32'hx;

                wb_write_byte_o <= 4'hx;

            end

        endcase

    end

end


// ----------------------------------------------------------------------------

// Data Memory Read (Load Instructions)

// ----------------------------------------------------------------------------


// Format load data based on load type

// - Apply sign-extension or zero-extension

// - Select correct byte or halfword using read address bits



always @* begin

    case (wb_alu_operation_i)

        LB: begin // Load byte

            case (wb_read_address_i)

                2'b00: wb_read_data_o = {{24{dmem_read_data_i[7]}},  dmem_read_data_i[7:0]};

                2'b01: wb_read_data_o = {{24{dmem_read_data_i[15]}}, dmem_read_data_i[15:8]};

                2'b10: wb_read_data_o = {{24{dmem_read_data_i[23]}}, dmem_read_data_i[23:16]};

                2'b11: wb_read_data_o = {{24{dmem_read_data_i[31]}}, dmem_read_data_i[31:24]};

            endcase

        end


        // load halfword

        LH: wb_read_data_o =

            wb_read_address_i[1]

            ? {{16{dmem_read_data_i[31]}}, dmem_read_data_i[31:16]}

            : {{16{dmem_read_data_i[15]}}, dmem_read_data_i[15:0]};


        LW: wb_read_data_o = dmem_read_data_i; // load word


        LBU: begin // load byte unsigned

            case (wb_read_address_i)

                2'b00: wb_read_data_o = {24'h0, dmem_read_data_i[7:0]};

                2'b01: wb_read_data_o = {24'h0, dmem_read_data_i[15:8]};

                2'b10: wb_read_data_o = {24'h0, dmem_read_data_i[23:16]};

                2'b11: wb_read_data_o = {24'h0, dmem_read_data_i[31:24]};

            endcase

        end


        // load halfword unsigned

        LHU: wb_read_data_o =

            wb_read_address_i[1]

            ? {16'h0, dmem_read_data_i[31:16]}

            : {16'h0, dmem_read_data_i[15:0]};


        default:

            wb_read_data_o = 'hx;

    endcase

end


endmodule 