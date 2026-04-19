module dynamic2bit #(
    parameter BTB_ENTRIES = 32,
    parameter INDEX_WIDTH = $clog2(BTB_ENTRIES),
    parameter TAG_WIDTH   = 32 - INDEX_WIDTH
) (
    input  wire        clk,
    input  wire        rst,

    // Fetch Stage Inputs
    input  wire [31:0] fetchPC,
    output wire        fetchHit,
    output wire [31:0] fetchTarget,

    // EX Stage Update Inputs
    input  wire        EXTaken,
    input  wire        EXBranch,
    input  wire [31:0] EXPC,
    input  wire [31:0] EXTarget
);

  // The 4 parallel arrays representing the BTB memory
  reg                 btb_valid   [0:BTB_ENTRIES-1]; // 1-bit flag indicating if the entry contains real data
  reg [TAG_WIDTH-1:0] btb_tag     [0:BTB_ENTRIES-1]; // Stores the upper bits of the Program Counter (PC) 
                                                     // to ensure the prediction is for the correct instruction
  reg [31:0]          btb_target  [0:BTB_ENTRIES-1]; // 32-bit address where the branch is expected to jump
  reg [1:0]           btb_counter [0:BTB_ENTRIES-1]; // 2-bit value storing confidence level of the prediction

  wire [INDEX_WIDTH-1:0] fetchIndex;
  wire [TAG_WIDTH-1:0]   fetchTag;
  wire [INDEX_WIDTH-1:0] EXIndex;
  wire [TAG_WIDTH-1:0]   EXTag;
  wire                   EXHit;

  reg  [1:0] NextCount;
  wire [1:0] Count;

    localparam [1:0]
    StronglyNotTaken = 2'b00,
    WeaklyNotTaken = 2'b01,
    WeaklyTaken  = 2'b10,
    StronglyTaken  = 2'b11;

  assign EXTag      = EXPC[31:INDEX_WIDTH];  // Tag Bits [31:7], tag is checked to ensure the entry actually belongs to the current instruction
  assign EXIndex    = EXPC[INDEX_WIDTH+1:2]; // Index Bits [6:2], index is used to look up a specific row in the 32-entry BTB array
                                             // Bits [1:0] are ignored as last 2 bits of instruction is 00
  assign fetchTag   = fetchPC[31:INDEX_WIDTH];  // Tag Bits [31:7] for FetchPC
  assign fetchIndex = fetchPC[INDEX_WIDTH+1:2]; // Index Bits [6:2] for FetchPC

  // Now Prediction is made
  assign fetchHit    = (btb_valid[fetchIndex] && (btb_tag[fetchIndex] == fetchTag)) && btb_counter[fetchIndex][1];
  assign fetchTarget = btb_target[fetchIndex];
  assign EXHit       = btb_valid[EXIndex] && (btb_tag[EXIndex] == EXTag);
  assign count       = btb_counter[EXIndex];

  // For a prediction to be a HIT ---> 
  // Valid Entry
  // Tag bits should match
  // The most significant bit of the 2-bit counter is 1. 
  // In a 2-bit predictor, binary 10 and 11 mean "Predicted Taken", while 00 and 01 mean "Predicted Not Taken"

  always @(posedge clk) 
  begin
    if (!rst) 
    begin
      if (EXHit) 
      begin
        btb_counter[EXIndex] <= NextCount;
      end 
      else 
      begin // update mem on the first take/not taken
        if (EXBranch) 
        begin // only store intentional jumps and branches jal,bne etc
          btb_valid[EXIndex]   <= 1'b1;
          btb_tag[EXIndex]     <= EXTag;
          btb_target[EXIndex]  <= EXTarget;
          btb_counter[EXIndex] <= EXTaken ? WeaklyTaken : WeaklyNotTaken;
        end
      end
    end
  end

  always @(*) begin
    case (count)
      WeaklyTaken:  NextCount = EXTaken ? StronglyTaken  : WeaklyNotTaken;
      StronglyTaken:  NextCount = EXTaken ? Count   : WeaklyTaken;
      WeaklyNotTaken: NextCount = EXTaken ? WeaklyNotTaken : StronglyNotTaken;
      StronglyNotTaken: NextCount = EXTaken ? WeaklyNotTaken : Count;
      default: NextCount = 2'b00; // Done to prevent latches
    endcase
  end

endmodule
