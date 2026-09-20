// HFT v9: two-stage exact expected-sequence updater.
// Assumption for this microarchitecture: packet-update valid pulses are separated by >=2 clocks,
// which is satisfied by minimum 100GbE wire spacing at a 400 MHz clock.

module seq64_count_update_pipe2_bench(
 input logic clk,input logic rst,input logic valid,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3,output logic busy
);
 logic st1v;
 logic[15:0] r_n0,r_u1,r_u2,r_u3,r_e1,r_e2,r_e3;
 logic r_c0,r_ov1,r_ov2;
 logic[16:0] s0,u1,u2,u3;
 always_comb begin
   s0={1'b0,e0}+{1'b0,count};
   u1={1'b0,e1}+17'd1;
   u2={1'b0,e2}+17'd1;
   u3={1'b0,e3}+17'd1;
 end
 always_ff @(posedge clk) begin
   if(rst) begin
     e0<='0;e1<='0;e2<='0;e3<='0;
     st1v<=0;busy<=0;
     r_n0<='0;r_u1<='0;r_u2<='0;r_u3<='0;r_e1<='0;r_e2<='0;r_e3<='0;
     r_c0<=0;r_ov1<=0;r_ov2<=0;
   end else begin
     // stage 2 commit
     if(st1v) begin
       e0<=r_n0;
       e1<=r_c0 ? r_u1 : r_e1;
       e2<=(r_c0 & r_ov1) ? r_u2 : r_e2;
       e3<=(r_c0 & r_ov1 & r_ov2) ? r_u3 : r_e3;
     end
     // stage 1 launch
     st1v<=valid;
     busy<=valid;
     if(valid) begin
       r_n0<=s0[15:0];
       r_u1<=u1[15:0];r_u2<=u2[15:0];r_u3<=u3[15:0];
       r_e1<=e1;r_e2<=e2;r_e3<=e3;
       r_c0<=s0[16];
       r_ov1<=u1[16];
       r_ov2<=u2[16];
     end
   end
 end
endmodule

module packetfence_jordan_lane9(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
  if(rst) begin z0<='0;z1<='0;z2<='0; end
  else if(valid) begin z0<=z0+x;z1<=z1+z0;z2<=z2+z1; end
 end
endmodule

module complete_pipe2_jordan_bench(
 input logic clk,input logic rst,input logic valid_seq,input logic[15:0] count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic[15:0] e0,e1,e2,e3,output logic busy,output logic[20:0] witness
);
 seq64_count_update_pipe2_bench q(.clk(clk),.rst(rst),.valid(valid_seq),.count(count),.e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(busy));
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
  logic[12:0] z0;logic[16:0] z1;logic[20:0] z2;
  packetfence_jordan_lane9 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),.z0(z0),.z1(z1),.z2(z2));
  if(i==0) assign witness=z2;
 end endgenerate
endmodule
