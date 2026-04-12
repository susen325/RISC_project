`timescale 1ns/1ps

module registerFile(
    output [31:0] reg1,
    output [31:0] reg2,
    input [31:0] writeData,
    input [4:0] addr1,
    input [4:0] addr2,
    input [4:0] writeAddr,
    input writeEn,
    input clk
  );

  reg [31:0] registers [31:0];

  assign reg1 = (|addr1) ? registers[addr1] : 32'b0;
  assign reg2 = (|addr2) ? registers[addr2] : 32'b0;

  // Synchronous write on the falling edge
  always @(negedge clk)
  begin
    if (writeEn && (|writeAddr))
      registers[writeAddr] <= writeData;
  end

endmodule
