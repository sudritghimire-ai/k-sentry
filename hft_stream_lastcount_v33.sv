// HFT v33: streamed last-sequence / previous-count fast path.
// Parser presents normalized high32, low32, then current message count.
// No wide equality tree and no computed next-sequence state.

module seq_stream_lastcount33(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_seq,input logic[15:0] init_count,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 output logic accept_fast,output logic slow_path,output logic mismatch
);
 (* keep *) logic have_last;
 (* keep *) logic[31:0] last_hi,last_lo;
 (* keep *) logic[15:0] last_count;

 (* keep *) logic hi_bad;
 (* keep *) logic sess_hold;
 (* keep *) logic[31:0] cand_hi,cand_lo;
 (* keep *) logic seq_candidate_ok;
 (* keep *) logic seq_candidate_mismatch;
 (* keep *) logic carry_divert;

 logic[16:0] low_sum;
 logic mid_bad,low_bad,no_carry;

 always_comb begin
   low_sum={1'b0,last_lo[15:0]}+{1'b0,last_count};
   no_carry=~low_sum[16];
   mid_bad=(seq_lo[31:16]!=last_lo[31:16]);
   low_bad=(seq_lo[15:0]!=low_sum[15:0]);
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     have_last<=0;last_hi<='0;last_lo<='0;last_count<='0;
     hi_bad<=0;sess_hold<=0;cand_hi<='0;cand_lo<='0;
     seq_candidate_ok<=0;seq_candidate_mismatch<=0;carry_divert<=0;
     accept_fast<=0;slow_path<=0;mismatch<=0;
   end else begin
     accept_fast<=0;slow_path<=0;mismatch<=0;

     if(init_valid) begin
       have_last<=1;
       last_hi<=init_seq[63:32];
       last_lo<=init_seq[31:0];
       last_count<=init_count;
       seq_candidate_ok<=0;carry_divert<=0;
     end

     if(seq_hi_valid) begin
       hi_bad <= (seq_hi!=last_hi);
       sess_hold <= session_ok;
       cand_hi <= seq_hi;
     end

     if(seq_lo_valid) begin
       cand_lo <= seq_lo;
       carry_divert <= have_last & ~no_carry;
       seq_candidate_ok <= have_last & sess_hold & no_carry &
                           ~hi_bad & ~mid_bad & ~low_bad;
       seq_candidate_mismatch <= have_last & sess_hold & no_carry &
                                 (hi_bad | mid_bad | low_bad);
     end

     if(count_valid) begin
       if(seq_candidate_ok && rx_count!=16'hffff) begin
         accept_fast<=1;
         // Copy-only accepted state transition.
         last_hi<=cand_hi;
         last_lo<=cand_lo;
         last_count<=rx_count;
       end else begin
         slow_path<=1;
         mismatch<=seq_candidate_mismatch;
       end
       seq_candidate_ok<=0;
       seq_candidate_mismatch<=0;
       carry_divert<=0;
     end
   end
 end
endmodule

module jordan_lane33(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
  if(rst) begin z0<='0;z1<='0;z2<='0; end
  else if(valid) begin z0<=z0+x;z1<=z1+z0;z2<=z2+z1; end
 end
endmodule

module hft_stream_lastcount_jordan33_bench(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_seq,input logic[15:0] init_count,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic slow_path,output logic mismatch,output logic status
);
 seq_stream_lastcount33 q(
   .clk(clk),.rst(rst),.init_valid(init_valid),.init_seq(init_seq),.init_count(init_count),
   .seq_hi_valid(seq_hi_valid),.seq_hi(seq_hi),.session_ok(session_ok),
   .seq_lo_valid(seq_lo_valid),.seq_lo(seq_lo),.count_valid(count_valid),.rx_count(rx_count),
   .accept_fast(accept_fast),.slow_path(slow_path),.mismatch(mismatch));

 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   jordan_lane33 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),
     .z0(z0[i]),.z1(z1[i]),.z2(z2[i]));
 end endgenerate
 assign status=z2[0][0]^z2[8][7]^z2[16][13];
endmodule
