module branchPredictor #(
    parameter BTB_ENTRIES = 32,
    parameter INDEX_WIDTH = $clog2(BTB_ENTRIES),
    parameter TAG_WIDTH   = 32 - INDEX_WIDTH
) (
    input  wire        clk,
    input  wire        rst,

    // Fetch stage inputs
    input  wire [31:0] fetchPC,
    output wire        fetchHit,
    output wire [31:0] fetchTarget,

    // EX stage update inputs
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
  reg                 btb_predict [0:BTB_ENTRIES-1]; // 1-bit value storing last branch decision

  wire [INDEX_WIDTH-1:0] fetchIndex;
  wire [TAG_WIDTH-1:0]   fetchTag;
  wire [INDEX_WIDTH-1:0] EXIndex;
  wire [TAG_WIDTH-1:0]   EXTag;
  wire                   EXHit;

  assign EXIndex    = EXPC[INDEX_WIDTH+1:2];
  assign EXTag      = EXPC[31:INDEX_WIDTH];
  assign fetchIndex = fetchPC[INDEX_WIDTH+1:2];
  assign fetchTag   = fetchPC[31:INDEX_WIDTH];

  // Prediction is simply looking at the single history bit (btb_predict)
  assign fetchHit    = (btb_valid[fetchIndex] && (btb_tag[fetchIndex] == fetchTag)) && btb_predict[fetchIndex];
  assign fetchTarget = btb_target[fetchIndex];
  
  assign EXHit       = btb_valid[EXIndex] && (btb_tag[EXIndex] == EXTag);

  always @(posedge clk) 
  begin
    if (!rst) 
    begin
      if (EXHit) 
      begin
        // CHANGED: Just update the history with whatever actually happened (1 or 0)
        btb_predict[EXIndex] <= EXTaken;
      end 
      else 
      begin 
        if (EXBranch) 
        begin 
          // Allocate a new entry
          btb_valid[EXIndex]   <= 1'b1;
          btb_tag[EXIndex]     <= EXTag;
          btb_target[EXIndex]  <= EXTarget;
          btb_predict[EXIndex] <= EXTaken; // Set initial prediction based on this first execution          
        end
      end
    end
  end

endmodule
