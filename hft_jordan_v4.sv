// HFT fast-path v4: Jordan/finite-difference PacketFence.
// z0=C0, z1=C1-C0, z2=C2-2*C1+C0.
// Exact recurrence: z0'=z0+x, z1'=z1+z0, z2'=z2+z1.
// All three are independent single-add carry chains.

module seq32_stream_fast(
  input logic clk,input logic rst,
  input logic [31:0] rx_chunk,input logic [31:0] exp_chunk,
  input logic start_pkt,input logic last_chunk,
  output logic accept_fast,output logic mismatch
);
  logic neq;
  always_comb neq=(rx_chunk!=exp_chunk);
  always_ff @(posedge clk) begin
    if(rst) begin mismatch<=0;accept_fast<=0; end
    else begin
      accept_fast<=0;
      if(start_pkt) begin mismatch<=neq; if(last_chunk)accept_fast<=!neq; end
      else begin mismatch<=mismatch|neq; if(last_chunk)accept_fast<=!(mismatch|neq); end
    end
  end
endmodule

module packetfence_jordan_lane(
  input logic clk,input logic rst,input logic valid,input logic[7:0] x,
  output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
  always_ff @(posedge clk) begin
    if(rst) begin z0<='0;z1<='0;z2<='0; end
    else if(valid) begin
      z0 <= z0 + x;
      z1 <= z1 + z0;
      z2 <= z2 + z1;
    end
  end
endmodule

module packetfence17_jordan_bench(
  input logic clk,input logic rst,input logic valid,input logic[135:0] semantic_bytes,
  output logic[20:0] witness
);
  genvar i;
  generate for(i=0;i<17;i=i+1) begin:L
    logic[12:0] z0; logic[16:0] z1; logic[20:0] z2;
    packetfence_jordan_lane p(.clk(clk),.rst(rst),.valid(valid),
      .x(semantic_bytes[i*8 +: 8]),.z0(z0),.z1(z1),.z2(z2));
    if(i==0) assign witness=z2;
  end endgenerate
endmodule

module hft_jordan_merged_bench(
  input logic clk,input logic rst,
  input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,
  input logic start_pkt,input logic last_chunk,
  input logic valid_sem,input logic[135:0] semantic_bytes,
  output logic accept_fast,output logic mismatch,output logic[20:0] witness
);
  seq32_stream_fast s(.clk(clk),.rst(rst),.rx_chunk(rx_chunk),.exp_chunk(exp_chunk),
    .start_pkt(start_pkt),.last_chunk(last_chunk),.accept_fast(accept_fast),.mismatch(mismatch));
  packetfence17_jordan_bench p(.clk(clk),.rst(rst),.valid(valid_sem),
    .semantic_bytes(semantic_bytes),.witness(witness));
endmodule
