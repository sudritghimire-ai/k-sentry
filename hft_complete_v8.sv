// Exact 64-bit expected-sequence update by 16-bit MoldUDP message count.
// Four 16-bit limbs; upper +1 candidates are computed in parallel.

module seq64_count_update_bench(
 input logic clk,input logic rst,input logic valid,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3
);
 logic[16:0] s0,u1,u2,u3;
 logic c0,c1,c2;
 logic[15:0] n0,n1,n2,n3;
 always_comb begin
   s0={1'b0,e0}+{1'b0,count};
   u1={1'b0,e1}+17'd1;
   u2={1'b0,e2}+17'd1;
   u3={1'b0,e3}+17'd1;
   c0=s0[16];
   c1=c0 & u1[16];
   c2=c1 & u2[16];
   n0=s0[15:0];
   n1=c0?u1[15:0]:e1;
   n2=c1?u2[15:0]:e2;
   n3=c2?u3[15:0]:e3;
 end
 always_ff @(posedge clk) begin
   if(rst) begin e0<='0;e1<='0;e2<='0;e3<='0; end
   else if(valid) begin e0<=n0;e1<=n1;e2<=n2;e3<=n3; end
 end
endmodule

module packetfence_jordan_lane8(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
  if(rst) begin z0<='0;z1<='0;z2<='0; end
  else if(valid) begin z0<=z0+x;z1<=z1+z0;z2<=z2+z1; end
 end
endmodule

module complete_state_update_bench(
 input logic clk,input logic rst,input logic valid_seq,input logic[15:0] count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic[15:0] e0,e1,e2,e3, output logic[20:0] witness
);
 seq64_count_update_bench q(.clk(clk),.rst(rst),.valid(valid_seq),.count(count),.e0(e0),.e1(e1),.e2(e2),.e3(e3));
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[16:0] z1;logic[20:0] z2;
   packetfence_jordan_lane8 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),.z0(z0),.z1(z1),.z2(z2));
   if(i==0) assign witness=z2;
 end endgenerate
endmodule
