// HFT v11: internal-state integration benchmark.
// Avoids forcing sequence/semantic state registers to top-level I/O pads.

module seq64_count_update_pipe2_int(
 input logic clk,input logic rst,input logic valid,input logic[15:0] count,
 output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 (* keep *) logic st1v;
 (* keep *) logic[15:0] r_n0,r_u1,r_u2,r_u3,r_e1,r_e2,r_e3;
 (* keep *) logic r_c0,r_ov1,r_ov2;
 logic[16:0] s0,u1,u2,u3;
 always_comb begin
   s0={1'b0,e0}+{1'b0,count}; u1={1'b0,e1}+17'd1; u2={1'b0,e2}+17'd1; u3={1'b0,e3}+17'd1;
 end
 always_ff @(posedge clk) begin
  if(rst) begin e0<='0;e1<='0;e2<='0;e3<='0;st1v<=0;
    r_n0<='0;r_u1<='0;r_u2<='0;r_u3<='0;r_e1<='0;r_e2<='0;r_e3<='0;r_c0<=0;r_ov1<=0;r_ov2<=0;
  end else begin
   if(st1v) begin
    e0<=r_n0;e1<=r_c0?r_u1:r_e1;e2<=(r_c0&r_ov1)?r_u2:r_e2;e3<=(r_c0&r_ov1&r_ov2)?r_u3:r_e3;
   end
   st1v<=valid;
   if(valid) begin
    r_n0<=s0[15:0];r_u1<=u1[15:0];r_u2<=u2[15:0];r_u3<=u3[15:0];
    r_e1<=e1;r_e2<=e2;r_e3<=e3;r_c0<=s0[16];r_ov1<=u1[16];r_ov2<=u2[16];
   end
  end
 end
 assign status=^e0 ^ ^e1 ^ ^e2 ^ ^e3;
endmodule

module packetfence17_jordan_int(
 input logic clk,input logic rst,input logic valid,input logic[135:0] semantic_bytes,
 output logic status
);
 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
  always_ff @(posedge clk) begin
   if(rst) begin z0[i]<='0;z1[i]<='0;z2[i]<='0; end
   else if(valid) begin z0[i]<=z0[i]+semantic_bytes[i*8 +:8];z1[i]<=z1[i]+z0[i];z2[i]<=z2[i]+z1[i]; end
  end
 end endgenerate
 assign status=z2[0][0]^z2[8][7]^z2[16][13];
endmodule

module complete_internal_state_bench(
 input logic clk,input logic rst,input logic valid_seq,input logic[15:0] count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic status
);
 logic a,b;
 seq64_count_update_pipe2_int q(.clk(clk),.rst(rst),.valid(valid_seq),.count(count),.status(a));
 packetfence17_jordan_int p(.clk(clk),.rst(rst),.valid(valid_sem),.semantic_bytes(semantic_bytes),.status(b));
 assign status=a^b;
endmodule
