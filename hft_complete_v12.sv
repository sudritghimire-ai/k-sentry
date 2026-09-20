// HFT v12: complete integrated fast path.
// - exact 64-bit in-order sequence validation streamed as two 32-bit chunks
// - exact 64-bit expected sequence update by MoldUDP16 message count in two stages
// - 17 semantic PacketFence lanes in carry-save Jordan basis
// Mismatch falls to a conventional slow-path ordering classifier.

module seq_update32x2_preinc(
 input logic clk,input logic rst,input logic count_valid,input logic[15:0] count,
 output logic[31:0] exp_hi,output logic[31:0] exp_lo,output logic busy
);
 logic st1v;
 logic[32:0] lo_sum, hi_inc;
 logic[31:0] r_lo,r_hi,r_hi_inc;
 logic r_carry;
 always_comb begin
   lo_sum={1'b0,exp_lo}+{{17{1'b0}},count};
   hi_inc={1'b0,exp_hi}+33'd1;
 end
 always_ff @(posedge clk) begin
   if(rst) begin
     exp_hi<='0;exp_lo<='0;st1v<=0;busy<=0;
     r_lo<='0;r_hi<='0;r_hi_inc<='0;r_carry<=0;
   end else begin
     if(st1v) begin
       exp_lo<=r_lo;
       exp_hi<=r_carry ? r_hi_inc : r_hi;
     end
     st1v<=count_valid;
     busy<=count_valid;
     if(count_valid) begin
       r_lo<=lo_sum[31:0];
       r_carry<=lo_sum[32];
       r_hi<=exp_hi;
       r_hi_inc<=hi_inc[31:0];
     end
   end
 end
endmodule

module seq_update32x2_direct(
 input logic clk,input logic rst,input logic count_valid,input logic[15:0] count,
 output logic[31:0] exp_hi,output logic[31:0] exp_lo,output logic busy
);
 logic st1v;
 logic[31:0] r_lo,r_hi;
 logic r_carry;
 logic[32:0] lo_sum;
 always_comb lo_sum={1'b0,exp_lo}+{{17{1'b0}},count};
 always_ff @(posedge clk) begin
   if(rst) begin exp_hi<='0;exp_lo<='0;st1v<=0;busy<=0;r_lo<='0;r_hi<='0;r_carry<=0; end
   else begin
     if(st1v) begin
       exp_lo<=r_lo;
       exp_hi<=r_hi + r_carry;
     end
     st1v<=count_valid; busy<=count_valid;
     if(count_valid) begin r_lo<=lo_sum[31:0];r_carry<=lo_sum[32];r_hi<=exp_hi; end
   end
 end
endmodule

module seq32_state_compare(
 input logic clk,input logic rst,input logic seq_valid,input logic[31:0] rx_chunk,
 input logic[31:0] exp_hi,input logic[31:0] exp_lo,
 output logic accept_fast,output logic mismatch
);
 logic phase,first_bad,neq;
 always_comb neq=(rx_chunk != (phase ? exp_lo : exp_hi));
 always_ff @(posedge clk) begin
   if(rst) begin phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0; end
   else begin
     accept_fast<=0;
     if(seq_valid) begin
       if(!phase) begin first_bad<=neq;mismatch<=neq;phase<=1; end
       else begin mismatch<=first_bad|neq;accept_fast<=!(first_bad|neq);phase<=0; end
     end
   end
 end
endmodule

module pf_csa_lane12(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,
 output logic[17:0] s1,output logic[17:0] c1,
 output logic[21:0] s2,output logic[21:0] c2
);
 logic[12:0] z0n;
 logic[17:0] b1,d1,s1n,c1n;
 logic[21:0] b20,d20,tS,tC,b21,d21,s2n,c2n;
 always_comb begin
   z0n=z0+x;
   b1={c1[16:0],1'b0}; d1={{5{1'b0}},z0};
   s1n=s1^b1^d1; c1n=(s1&b1)|(s1&d1)|(b1&d1);
   b20={c2[20:0],1'b0}; d20={{4{1'b0}},s1};
   tS=s2^b20^d20; tC=(s2&b20)|(s2&d20)|(b20&d20);
   b21={tC[20:0],1'b0}; d21={{3{1'b0}},c1,1'b0};
   s2n=tS^b21^d21; c2n=(tS&b21)|(tS&d21)|(b21&d21);
 end
 always_ff @(posedge clk) begin
   if(rst) begin z0<='0;s1<='0;c1<='0;s2<='0;c2<='0; end
   else if(valid) begin z0<=z0n;s1<=s1n;c1<=c1n;s2<=s2n;c2<=c2n; end
 end
endmodule

module complete_hft_preinc_bench(
 input logic clk,input logic rst,
 input logic seq_valid,input logic[31:0] rx_chunk,
 input logic count_valid,input logic[15:0] count,
 input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic updater_busy,
 output logic[21:0] witness_s,output logic[21:0] witness_c
);
 logic[31:0] exp_hi,exp_lo;
 seq_update32x2_preinc u(.clk(clk),.rst(rst),.count_valid(count_valid),.count(count),
   .exp_hi(exp_hi),.exp_lo(exp_lo),.busy(updater_busy));
 seq32_state_compare q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx_chunk(rx_chunk),
   .exp_hi(exp_hi),.exp_lo(exp_lo),.accept_fast(accept_fast),.mismatch(mismatch));
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[17:0] s1,c1;logic[21:0] s2,c2;
   pf_csa_lane12 p(.clk(clk),.rst(rst),.valid(sem_valid),.x(semantic_bytes[i*8 +:8]),
     .z0(z0),.s1(s1),.c1(c1),.s2(s2),.c2(c2));
   if(i==0) begin assign witness_s=s2;assign witness_c=c2; end
 end endgenerate
endmodule

module complete_hft_direct_bench(
 input logic clk,input logic rst,
 input logic seq_valid,input logic[31:0] rx_chunk,
 input logic count_valid,input logic[15:0] count,
 input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic updater_busy,
 output logic[21:0] witness_s,output logic[21:0] witness_c
);
 logic[31:0] exp_hi,exp_lo;
 seq_update32x2_direct u(.clk(clk),.rst(rst),.count_valid(count_valid),.count(count),
   .exp_hi(exp_hi),.exp_lo(exp_lo),.busy(updater_busy));
 seq32_state_compare q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx_chunk(rx_chunk),
   .exp_hi(exp_hi),.exp_lo(exp_lo),.accept_fast(accept_fast),.mismatch(mismatch));
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[17:0] s1,c1;logic[21:0] s2,c2;
   pf_csa_lane12 p(.clk(clk),.rst(rst),.valid(sem_valid),.x(semantic_bytes[i*8 +:8]),
     .z0(z0),.s1(s1),.c1(c1),.s2(s2),.c2(c2));
   if(i==0) begin assign witness_s=s2;assign witness_c=c2; end
 end endgenerate
endmodule
