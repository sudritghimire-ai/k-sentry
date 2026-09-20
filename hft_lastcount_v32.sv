// HFT v32: last-sequence / previous-count fast path.
// Exact common case: next_seq = last_seq + last_count with no low16 carry.
// Any carry, session change, EOS, or mismatch is diverted to slow/recovery path.
// Accepted state update is register-copy only: last_seq<=rx_seq, last_count<=rx_count.

module seq_lastcount_fast32(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_seq,input logic[15:0] init_count,
 input logic pkt_valid,input logic[63:0] rx_seq,input logic[15:0] rx_count,
 input logic session_ok,
 output logic accept_fast,output logic slow_path,output logic mismatch
);
 (* keep *) logic have_last;
 (* keep *) logic[63:0] last_seq;
 (* keep *) logic[15:0] last_count;

 logic[16:0] low_sum;
 logic high_eq,low_eq,no_carry,eos;
 logic fast_match;

 always_comb begin
   low_sum={1'b0,last_seq[15:0]}+{1'b0,last_count};
   no_carry=~low_sum[16];
   high_eq=(rx_seq[63:16]==last_seq[63:16]);
   low_eq=(rx_seq[15:0]==low_sum[15:0]);
   eos=(rx_count==16'hffff);
   fast_match=have_last & session_ok & no_carry & high_eq & low_eq & ~eos;
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     have_last<=0;last_seq<='0;last_count<='0;
     accept_fast<=0;slow_path<=0;mismatch<=0;
   end else begin
     accept_fast<=0;slow_path<=0;mismatch<=0;
     if(init_valid) begin
       have_last<=1;last_seq<=init_seq;last_count<=init_count;
     end else if(pkt_valid) begin
       if(fast_match) begin
         accept_fast<=1;
         // Copy-only state transition.
         last_seq<=rx_seq;
         last_count<=rx_count;
       end else begin
         slow_path<=1;
         mismatch<=have_last & session_ok & no_carry & ~eos & ~(high_eq&low_eq);
       end
     end
   end
 end
endmodule

module jordan_lane32(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 always_ff @(posedge clk) begin
   if(rst) begin z0<='0;z1<='0;z2<='0; end
   else if(valid) begin
     z0<=z0+x;
     z1<=z1+z0;
     z2<=z2+z1;
   end
 end
endmodule

module hft_lastcount_jordan32_bench(
 input logic clk,input logic rst,
 input logic init_valid,input logic[63:0] init_seq,input logic[15:0] init_count,
 input logic pkt_valid,input logic[63:0] rx_seq,input logic[15:0] rx_count,input logic session_ok,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic slow_path,output logic mismatch,output logic status
);
 seq_lastcount_fast32 q(.clk(clk),.rst(rst),.init_valid(init_valid),.init_seq(init_seq),.init_count(init_count),
   .pkt_valid(pkt_valid),.rx_seq(rx_seq),.rx_count(rx_count),.session_ok(session_ok),
   .accept_fast(accept_fast),.slow_path(slow_path),.mismatch(mismatch));

 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   jordan_lane32 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +:8]),
     .z0(z0[i]),.z1(z1[i]),.z2(z2[i]));
 end endgenerate
 assign status=z2[0][0]^z2[8][7]^z2[16][13];
endmodule
