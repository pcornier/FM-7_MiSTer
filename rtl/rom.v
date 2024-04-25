
module rom #(
  parameter memfile="",
  parameter addr_width=12,
  parameter data_width=8
)
(
  input clk,
  input [addr_width-1:0] addr,
  output [data_width-1:0] dout,
  input ce_n
);

reg [data_width-1:0] q;
reg [data_width-1:0] mem[(1<<addr_width)-1:0];

assign dout = ce_n ? 0 : q;

initial begin
  $readmemh(memfile, mem);
end

always @(posedge clk)
  q <= mem[addr];

endmodule
