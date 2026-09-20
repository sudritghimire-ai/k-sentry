// HFT v34: precomputed expected-low streamed fast path.
// The only 16-bit add happens at the prior packet's count beat.
// Next packet sequence decision is equality-only.

module seq_precompute34(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_last_seq,input logic[15:0] init_last_count,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 output logic accept_fast,output logic slow_path,output logic mismatch
);
 (* keep *) logic have_expected,fast_ready;
 (* keep *) logic[47:0] expected_hi48;
 (* keep *) logic[15:0] expected_low16;

 (* keep *) logic hi_bad,sess_hold;
 (* keep *) logic[31:0] cand_hi,cand_lo;
 (* keep *) logic seq_ok,seq_bad;
 logic mid_bad,low_bad;
 logic[16:0] next_low_sum;
 logic[16:0] init_low_sum;

 always_comb begin
   mid_bad=(seq_lo[31:16]!=expected_hi48[15:0]);
   low_bad=(seq_lo[15:0]!=expected_low16);
   next_low_sum={1'b0,cand_lo[15:0]}+{1'b0,rx_count};
   init_low_sum={1'b0,init_last_seq[15:0]}+{1'b0,init_last_count};
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     have_expected<=0;fast_ready<=0;expected_hi48<='0;expected_low16<='0;
     hi_bad<=0;sess_hold<=0;cand_hi<='0;cand_lo<='0;seq_ok<=0;seq_bad<=0;
     accept_fast<=0;slow_path<=0;mismatch<=0;
   end else begin
     accept_fast<=0;slow_path<=0;mismatch<=0;

     if(init_valid) begin
       have_expected<=1;
       expected_hi48<=init_last_seq[63:16];
       expected_low16<=init_low_sum[15:0];
       fast_ready<=~init_low_sum[16];
       seq_ok<=0;seq_bad<=0;
     end

     if(seq_hi_valid) begin
       hi_bad <= (seq_hi!=expected_hi48[47:16]);
       sess_hold <= session_ok;
       cand_hi <= seq_hi;
     end

     if(seq_lo_valid) begin
       cand_lo <= seq_lo;
       seq_ok <= have_expected & fast_ready & sess_hold &
                 ~hi_bad & ~mid_bad & ~low_bad;
       seq_bad <= have_expected & fast_ready & sess_hold &
                  (hi_bad | mid_bad | low_bad);
     end

     if(count_valid) begin
       if(seq_ok && rx_count!=16'hffff) begin
         accept_fast<=1;
         // Precompute expected state for the NEXT packet.
         expected_hi48<={cand_hi,cand_lo[31:16]};
         expected_low16<=next_low_sum[15:0];
         fast_ready<=~next_low_sum[16];
       end else begin
         slow_path<=1;
         mismatch<=seq_bad;
       end
       seq_ok<=0;seq_bad<=0;
     end
   end
 end
endmodule

module jordan_lane34(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
  if(rst) begin z0<='0;z1<='0;z2<='0; end
  else if(valid) begin z0<=z0+x;z1<=z1+z0;z2<=z2+z1; end
 end
endmodule

module hft_precompute_jordan34_bench(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_last_seq,input logic[15:0] init_last_count,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic slow_path,output logic mismatch,output logic status
);
 seq_precompute34 q(.*);
 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   jordan_lane34 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),
    .z0(z0[i]),.z1(z1[i]),.z2(z2[i]));
 end endgenerate
 assign status=z2[0][0]^z2[8][7]^z2[16][13];
endmodule
