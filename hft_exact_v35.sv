// HFT v35: exact 64-bit fast equality as four parallel 16-bit chunks.
// Ordinary packet path is globally exact. If preparing the next expected sequence
// requires a low16 carry, fast_ready is cleared and the next packet diverts to recovery.

module seq_chunk16_exact35(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_expected_seq,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 output logic accept_fast,output logic slow_path,output logic mismatch
);
 (* keep *) logic have_expected,fast_ready;
 (* keep *) logic[15:0] e3,e2,e1,e0;
 (* keep *) logic hi_bad,sess_hold;
 (* keep *) logic[31:0] cand_hi,cand_lo;
 (* keep *) logic seq_ok,seq_bad;

 logic bad3,bad2,bad1,bad0;
 logic[16:0] next_low_sum;

 always_comb begin
   bad3=(seq_hi[31:16]!=e3);
   bad2=(seq_hi[15:0]!=e2);
   bad1=(seq_lo[31:16]!=e1);
   bad0=(seq_lo[15:0]!=e0);
   next_low_sum={1'b0,cand_lo[15:0]}+{1'b0,rx_count};
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     have_expected<=0;fast_ready<=0;e3<='0;e2<='0;e1<='0;e0<='0;
     hi_bad<=0;sess_hold<=0;cand_hi<='0;cand_lo<='0;seq_ok<=0;seq_bad<=0;
     accept_fast<=0;slow_path<=0;mismatch<=0;
   end else begin
     accept_fast<=0;slow_path<=0;mismatch<=0;

     if(init_valid) begin
       have_expected<=1;fast_ready<=1;
       e3<=init_expected_seq[63:48];e2<=init_expected_seq[47:32];
       e1<=init_expected_seq[31:16];e0<=init_expected_seq[15:0];
       seq_ok<=0;seq_bad<=0;
     end

     if(seq_hi_valid) begin
       hi_bad <= bad3 | bad2;
       sess_hold <= session_ok;
       cand_hi <= seq_hi;
     end

     if(seq_lo_valid) begin
       cand_lo <= seq_lo;
       seq_ok <= have_expected & fast_ready & sess_hold &
                 ~hi_bad & ~bad1 & ~bad0;
       seq_bad <= have_expected & fast_ready & sess_hold &
                  (hi_bad | bad1 | bad0);
     end

     if(count_valid) begin
       if(seq_ok && rx_count!=16'hffff) begin
         accept_fast<=1;
         // Next expected sequence = current first-sequence + current message count.
         // High 48 bits are unchanged only when low16 does not carry.
         e3<=cand_hi[31:16]; e2<=cand_hi[15:0]; e1<=cand_lo[31:16];
         e0<=next_low_sum[15:0];
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

module jordan_lane35(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
  if(rst) begin z0<='0;z1<='0;z2<='0; end
  else if(valid) begin z0<=z0+x;z1<=z1+z0;z2<=z2+z1; end
 end
endmodule

module hft_exact35_jordan_bench(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_expected_seq,
 input logic seq_hi_valid,input logic[31:0] seq_hi,input logic session_ok,
 input logic seq_lo_valid,input logic[31:0] seq_lo,
 input logic count_valid,input logic[15:0] rx_count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic slow_path,output logic mismatch,output logic status
);
 seq_chunk16_exact35 q(.*);
 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   jordan_lane35 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),
    .z0(z0[i]),.z1(z1[i]),.z2(z2[i]));
 end endgenerate
 assign status=z2[0][0]^z2[8][7]^z2[16][13];
endmodule
