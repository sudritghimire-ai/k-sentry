// HFT v24: rare-event diversion + count-bounded two-phase semantic fast path.
// Fast-path contract:
//   - full 64-bit sequence must equal expected
//   - heartbeat count=0 accepted without advance
//   - EOS 0xffff signaled
//   - normal count must be <=64 for semantic fast mode
//   - low16 sequence carry is diverted to slow/recovery path
// Slow path reloads full expected sequence via recover_valid/recover_seq.

module seq_fast24_bench #(
 parameter [63:0] INIT_SEQ=64'd0
)(
 input logic clk,input logic rst,
 input logic pkt_valid,input logic session_ok,
 input logic[63:0] rx_seq,input logic[15:0] msg_count,
 input logic recover_valid,input logic[63:0] recover_seq,
 output logic accept_fast,output logic mismatch,output logic slow_required,
 output logic eos,output logic semantic_fast_ok
);
 (* keep *) logic[15:0] e0,e1,e2,e3;

 // Stage A leaves terminate independently in flops.
 (* keep *) logic m0,m1,m2,m3,msess;
 logic s_v,s_hb,s_eos,s_normal,s_carry,s_semok;
 logic[15:0] s_lo;
 logic[16:0] low_sum;
 logic stage_match;

 always_comb begin
   low_sum={1'b0,e0}+{1'b0,msg_count};
   stage_match=m0&m1&m2&m3&msess;
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     e0<=INIT_SEQ[15:0];e1<=INIT_SEQ[31:16];e2<=INIT_SEQ[47:32];e3<=INIT_SEQ[63:48];
     m0<=0;m1<=0;m2<=0;m3<=0;msess<=0;
     s_v<=0;s_hb<=0;s_eos<=0;s_normal<=0;s_carry<=0;s_semok<=0;s_lo<=0;
     accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;
   end else begin
     accept_fast<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;

     if(recover_valid) begin
       e0<=recover_seq[15:0];e1<=recover_seq[31:16];
       e2<=recover_seq[47:32];e3<=recover_seq[63:48];
       s_v<=0;
     end else if(s_v) begin
       mismatch<=~stage_match;
       if(!stage_match) slow_required<=1;
       else if(s_eos) eos<=1;
       else if(s_hb) accept_fast<=1;
       else if(s_normal) begin
         if(s_carry) slow_required<=1;
         else begin
           e0<=s_lo;
           accept_fast<=1;
           semantic_fast_ok<=s_semok;
         end
       end else slow_required<=1;
     end

     // Packet-input stage: four 16-bit exact comparisons + one 16-bit add.
     if(!recover_valid) begin
       s_v<=pkt_valid;
       if(pkt_valid) begin
         m0<=rx_seq[15:0]==e0;
         m1<=rx_seq[31:16]==e1;
         m2<=rx_seq[47:32]==e2;
         m3<=rx_seq[63:48]==e3;
         msess<=session_ok;
         s_hb<=(msg_count==16'd0);
         s_eos<=(msg_count==16'hffff);
         s_normal<=(msg_count!=16'd0)&&(msg_count!=16'hffff);
         s_carry<=low_sum[16];
         s_lo<=low_sum[15:0];
         s_semok<=(msg_count<=16'd64);
       end
     end
   end
 end
endmodule

module packetfence2_phase24_bench(
 input logic clk,input logic rst,input logic pkt_start,
 input logic[1:0] valid_count,
 input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic status
);
 // Parser contract: no more than 64 semantic messages are supplied per packet.
 // Each phase sees at most 32, so 13/17/21 bits are exact.
 (* keep *) logic[12:0] x0[0:16],y0[0:16];
 (* keep *) logic[16:0] x1[0:16],y1[0:16];
 (* keep *) logic[20:0] x2[0:16],y2[0:16];
 integer i;

 always_ff @(posedge clk) begin
   if(rst) begin
     status<=0;
     for(i=0;i<17;i=i+1) begin
       x0[i]<=0;x1[i]<=0;x2[i]<=0;y0[i]<=0;y1[i]<=0;y2[i]<=0;
     end
   end else if(pkt_start) begin
     // packet start may carry its first 1 or 2 semantic messages
     for(i=0;i<17;i=i+1) begin
       if(valid_count>=1) begin x0[i]<=sem_x[i*8+:8];x1[i]<=0;x2[i]<=0; end
       else begin x0[i]<=0;x1[i]<=0;x2[i]<=0; end
       if(valid_count==2) begin y0[i]<=sem_y[i*8+:8];y1[i]<=0;y2[i]<=0; end
       else begin y0[i]<=0;y1[i]<=0;y2[i]<=0; end
     end
   end else if(valid_count!=0) begin
     for(i=0;i<17;i=i+1) begin
       // even-position phase
       x0[i]<=x0[i]+sem_x[i*8+:8];
       x1[i]<=x1[i]+x0[i];
       x2[i]<=x2[i]+x1[i];
       // odd-position phase
       if(valid_count==2) begin
         y0[i]<=y0[i]+sem_y[i*8+:8];
         y1[i]<=y1[i]+y0[i];
         y2[i]<=y2[i]+y1[i];
       end
     end
   end

   status<=x2[0][0]^y2[0][1]^x2[8][7]^y2[16][13];
 end
endmodule

module hft_hot24_bench(
 input logic clk,input logic rst,
 input logic pkt_valid,input logic session_ok,input logic[63:0] rx_seq,input logic[15:0] msg_count,
 input logic recover_valid,input logic[63:0] recover_seq,
 input logic pkt_start,input logic[1:0] valid_count,input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos,
 output logic semantic_fast_ok,output logic status
);
 logic ps;
 seq_fast24_bench q(.clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),
  .rx_seq(rx_seq),.msg_count(msg_count),.recover_valid(recover_valid),.recover_seq(recover_seq),
  .accept_fast(accept_fast),.mismatch(mismatch),.slow_required(slow_required),.eos(eos),
  .semantic_fast_ok(semantic_fast_ok));
 packetfence2_phase24_bench p(.clk(clk),.rst(rst),.pkt_start(pkt_start),.valid_count(valid_count),
  .sem_x(sem_x),.sem_y(sem_y),.status(ps));
 assign status=ps^accept_fast;
endmodule
