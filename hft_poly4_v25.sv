// HFT v25: exact 4-way polyphase Jordan PacketFence.
// Interface contract: parser/compactor emits groups of four semantic events,
// except the final group of a packet which may contain 1..3.
// Packet is admitted only when MoldUDP64 message count <=64.

module packetfence4_phase25_bench(
 input logic clk,input logic rst,input logic pkt_start,
 input logic[2:0] valid_count,              // 0..4
 input logic[543:0] sem4,                  // event r at sem4[r*136 +: 136]
 output logic status
);
 // <=64 total -> <=16 events per phase.
 // Exact unsigned-8-bit bounds: z0 12b, z1 15b, z2 18b.
 (* keep *) logic[11:0] z0[0:3][0:16];
 (* keep *) logic[14:0] z1[0:3][0:16];
 (* keep *) logic[17:0] z2[0:3][0:16];
 integer r,i;

 always_ff @(posedge clk) begin
   if(rst) begin
     status<=0;
     for(r=0;r<4;r=r+1) for(i=0;i<17;i=i+1) begin
       z0[r][i]<=0;z1[r][i]<=0;z2[r][i]<=0;
     end
   end else if(pkt_start) begin
     for(r=0;r<4;r=r+1) for(i=0;i<17;i=i+1) begin
       if(valid_count>r) begin
         z0[r][i]<=sem4[r*136+i*8 +:8];
         z1[r][i]<=0;
         z2[r][i]<=0;
       end else begin
         z0[r][i]<=0;z1[r][i]<=0;z2[r][i]<=0;
       end
     end
   end else if(valid_count!=0) begin
     for(r=0;r<4;r=r+1) for(i=0;i<17;i=i+1) begin
       if(valid_count>r) begin
         z0[r][i]<=z0[r][i]+sem4[r*136+i*8 +:8];
         z1[r][i]<=z1[r][i]+z0[r][i];
         z2[r][i]<=z2[r][i]+z1[r][i];
       end
     end
   end
   status<=z2[0][0][0]^z2[1][0][1]^z2[2][8][7]^z2[3][16][13];
 end
endmodule

// No per-phase valid mux: exactly four events every non-final cycle.
// This isolates the arithmetic ceiling after parser compaction.
module packetfence4_full25_bench(
 input logic clk,input logic rst,input logic pkt_start,
 input logic[543:0] sem4,
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
    z0[r][i]<=sem4[r*136+i*8 +:8];z1[r][i]<=0;z2[r][i]<=0;
   end
  end else begin
   for(r=0;r<4;r=r+1)for(i=0;i<17;i=i+1)begin
    z0[r][i]<=z0[r][i]+sem4[r*136+i*8 +:8];
    z1[r][i]<=z1[r][i]+z0[r][i];
    z2[r][i]<=z2[r][i]+z1[r][i];
   end
  end
  status<=z2[0][0][0]^z2[1][0][1]^z2[2][8][7]^z2[3][16][13];
 end
endmodule
