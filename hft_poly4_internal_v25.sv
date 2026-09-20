// HFT v25i: internal-source timing wrapper for four-way polyphase PacketFence.
// Common path processes exactly 4 semantic vectors/cycle; final group is zero-padded.

module packetfence4_core25i(
 input logic clk,input logic rst,input logic pkt_start,input logic[543:0] sem4,
 output logic status
);
 (* keep *) logic[11:0] z0[0:3][0:16];
 (* keep *) logic[14:0] z1[0:3][0:16];
 (* keep *) logic[17:0] z2[0:3][0:16];
 integer r,i;
 always_ff @(posedge clk) begin
  if(rst) begin
   status<=0;
   for(r=0;r<4;r=r+1)for(i=0;i<17;i=i+1)begin z0[r][i]<=0;z1[r][i]<=0;z2[r][i]<=0;end
  end else if(pkt_start) begin
   for(r=0;r<4;r=r+1)for(i=0;i<17;i=i+1)begin
    z0[r][i]<=sem4[r*136+i*8+:8];z1[r][i]<=0;z2[r][i]<=0;
   end
  end else begin
   for(r=0;r<4;r=r+1)for(i=0;i<17;i=i+1)begin
    z0[r][i]<=z0[r][i]+sem4[r*136+i*8+:8];
    z1[r][i]<=z1[r][i]+z0[r][i];
    z2[r][i]<=z2[r][i]+z1[r][i];
   end
  end
  status<=z2[0][0][0]^z2[1][0][1]^z2[2][8][7]^z2[3][16][13];
 end
endmodule

module packetfence4_internal25i_bench(
 input logic clk,input logic rst,input logic pkt_start,input logic[63:0] seed,
 output logic status
);
 (* keep *) logic[543:0] src;
 logic fb;
 assign fb=src[543]^src[542]^src[540]^src[535];
 always_ff @(posedge clk) begin
  if(rst) src<={{480{1'b0}},seed};
  else src<={src[542:0],fb};
 end
 packetfence4_core25i p(.clk(clk),.rst(rst),.pkt_start(pkt_start),.sem4(src),.status(status));
endmodule
