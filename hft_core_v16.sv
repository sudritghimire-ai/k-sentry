// HFT v16: protocol-scale fast core.
// Exact streamed 64-bit sequence equality, staged expected-state update,
// and packet-local all-carry-save Jordan PacketFence sized for every normal
// MoldUDP64 message count (1..65534) using 8-bit semantic coordinates.
//
// PacketFence bounds per byte lane for n<=65534:
// z0 <= 255*n                               -> 24 bits
// z1 <= 255*n*(n-1)/2                       -> 39 bits
// z2 <= 255*n*(n-1)*(n-2)/6                 -> 54 bits
//
// Each zk is stored as (S,C), value = S + (C<<1); all updates are CSA only.
// A shared packet_start sets only one local "fresh" bit per lane; the wide
// state need not be cleared every packet.

module updater16_micro(
 input logic clk,input logic rst,input logic launch,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3,output logic busy,output logic conflict,output logic ov
);
 typedef enum logic[1:0]{IDLE=0,C01=1,I2=2,I3=3} st_t;
 st_t st;
 logic[16:0] a0,a1,a2,a3;
 logic[15:0] r0,r1,r2; logic c0,c1,c2;
 always_comb begin
   a0={1'b0,e0}+{1'b0,count}; a1={1'b0,e1}+17'd1;
   a2={1'b0,e2}+17'd1; a3={1'b0,e3}+17'd1;
 end
 always_ff @(posedge clk) begin
  if(rst) begin e0<=0;e1<=0;e2<=0;e3<=0;st<=IDLE;busy<=0;conflict<=0;ov<=0;
    r0<=0;r1<=0;r2<=0;c0<=0;c1<=0;c2<=0; end
  else begin
   conflict<=0;ov<=0;if(launch&&st!=IDLE)conflict<=1;
   case(st)
    IDLE: begin busy<=0;if(launch)begin r0<=a0[15:0];c0<=a0[16];r1<=a1[15:0];c1<=a1[16];st<=C01;busy<=1;end end
    C01: begin e0<=r0;if(c0)e1<=r1;
      if(c0&&c1)begin r2<=a2[15:0];c2<=a2[16];st<=I2;busy<=1;end
      else begin st<=IDLE;busy<=0;end end
    I2: begin e2<=r2;if(c2)begin st<=I3;busy<=1;end else begin st<=IDLE;busy<=0;end end
    I3: begin e3<=a3[15:0];ov<=a3[16];st<=IDLE;busy<=0;end
   endcase
  end
 end
endmodule

module seq_fast16(
 input logic clk,input logic rst,input logic seq_valid,input logic[31:0] rx,
 input logic[31:0] exp_hi,input logic[31:0] exp_lo,input logic gate_in,
 output logic accept,output logic packet_ok,output logic mismatch
);
 logic phase,first_bad,gate_q,neq;
 assign neq=(rx!=(phase?exp_lo:exp_hi));
 always_ff @(posedge clk) begin
  if(rst)begin phase<=0;first_bad<=0;gate_q<=0;accept<=0;packet_ok<=0;mismatch<=0;end
  else begin
   accept<=0;
   if(seq_valid)begin
    if(!phase)begin packet_ok<=0;first_bad<=neq;gate_q<=gate_in;mismatch<=neq;phase<=1;end
    else begin mismatch<=first_bad|neq;packet_ok<=gate_q&~(first_bad|neq);accept<=gate_q&~(first_bad|neq);phase<=0;end
   end
  end
 end
endmodule

module pf_allcsa_lane16(
 input logic clk,input logic rst,input logic packet_start,input logic valid,input logic[7:0] x,
 output logic[53:0] out_s2,output logic[53:0] out_c2
);
 (* keep *) logic fresh;
 (* keep *) logic[23:0] s0,c0;
 (* keep *) logic[38:0] s1,c1;
 (* keep *) logic[53:0] s2,c2;

 logic[23:0] x0,b0,n_s0,n_c0;
 logic[38:0] z0e,b10,t1s,t1c,b11,n_s1,n_c1;
 logic[53:0] z1e,b20,t2s,t2c,b21,n_s2,n_c2;

 always_comb begin
   // z0' = z0 + x
   x0={{16{1'b0}},x}; b0={c0[22:0],1'b0};
   n_s0=s0^b0^x0;
   n_c0=(s0&b0)|(s0&x0)|(b0&x0);

   // z1' = z1 + z0 = S1+(C1<<1)+S0+(C0<<1)
   z0e={{15{1'b0}},s0}; b10={c1[37:0],1'b0};
   t1s=s1^b10^z0e; t1c=(s1&b10)|(s1&z0e)|(b10&z0e);
   b11={t1c[37:0],1'b0};
   n_s1=t1s^b11^{{14{1'b0}},c0,1'b0};
   n_c1=(t1s&b11)|(t1s&{{14{1'b0}},c0,1'b0})|(b11&{{14{1'b0}},c0,1'b0});

   // z2' = z2 + z1
   z1e={{15{1'b0}},s1}; b20={c2[52:0],1'b0};
   t2s=s2^b20^z1e; t2c=(s2&b20)|(s2&z1e)|(b20&z1e);
   b21={t2c[52:0],1'b0};
   n_s2=t2s^b21^{{14{1'b0}},c1,1'b0};
   n_c2=(t2s&b21)|(t2s&{{14{1'b0}},c1,1'b0})|(b21&{{14{1'b0}},c1,1'b0});
 end

 always_ff @(posedge clk) begin
  if(rst)begin fresh<=1;s0<=0;c0<=0;s1<=0;c1<=0;s2<=0;c2<=0;end
  else begin
   if(packet_start)fresh<=1;
   if(valid)begin
    if(fresh|pkt_start)begin s0<={{16{1'b0}},x};c0<=0;s1<=0;c1<=0;s2<=0;c2<=0;fresh<=0;end
    else begin s0<=n_s0;c0<=n_c0;s1<=n_s1;c1<=n_c1;s2<=n_s2;c2<=n_c2;end
   end
  end
 end
 assign out_s2=s2;assign out_c2=c2;
endmodule

module hft_core_v16_17lane(
 input logic clk,input logic rst,input logic recover,input logic session_ok,
 input logic seq_valid,input logic[31:0] rx_seq_chunk,
 input logic count_valid,input logic[15:0] msg_count,
 input logic packet_start,input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 logic busy,conflict,ov,packet_ok;
 logic recovery_hold;

 // Count is delayed one cycle to tolerate sharing a parser word with final sequence bytes.
 logic cqv;logic[15:0] cq;
 always_ff @(posedge clk)begin
  if(rst)begin cqv<=0;cq<=0;end
  else begin cqv<=count_valid;if(count_valid)cq<=msg_count;end
 end
 logic normal,launch;
 assign normal=(cq!=16'h0000)&&(cq!=16'hffff);
 assign launch=cqv&packet_ok&normal;

 updater16_micro u(.clk(clk),.rst(rst),.launch(launch),.count(cq),
  .e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(busy),.conflict(conflict),.ov(ov));

 // gate_in is sampled only on first sequence beat; recovery bookkeeping is not
 // in the second-beat compare path.
 logic gate_in;
 assign gate_in=session_ok & ~busy & ~recovery_hold & ~launch;
 seq_fast16 q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx(rx_seq_chunk),
  .exp_hi({e3,e2}),.exp_lo({e1,e0}),.gate_in(gate_in),
  .accept(accept_fast),.packet_ok(packet_ok),.mismatch(mismatch));

 // Recovery/control is deliberately one-way; it never fans combinationally
 // through the accept datapath after gate_in is sampled.
 always_ff @(posedge clk)begin
  if(rst)recovery_hold<=0;
  else if(recover)recovery_hold<=0;
  else if(mismatch|conflict|ov|(cqv&packet_ok&(cq==16'hffff)))recovery_hold<=1;
 end
 assign slow_required=recovery_hold|busy|conflict|ov;

 // Locally pipeline semantic enable/data so packet_ok does not drive thousands of state bits.
 logic semv_q,start_q;
 logic[135:0] sem_q;
 always_ff @(posedge clk)begin
  if(rst)begin semv_q<=0;start_q<=0;sem_q<=0;end
  else begin
   semv_q<=sem_valid & packet_ok & ~recovery_hold;
   start_q<=packet_start;
   if(sem_valid)sem_q<=semantic_bytes;
  end
 end

 (* keep *) logic[53:0] ws2[0:16],wc2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1)begin:L
   pf_allcsa_lane16 p(.clk(clk),.rst(rst),.packet_start(start_q),.valid(semv_q),
    .x(sem_q[i*8+:8]),.out_s2(ws2[i]),.out_c2(wc2[i]));
 end endgenerate
 // Minimal observable sink; all state is marked keep.
 always_ff @(posedge clk)begin
  if(rst)status<=0;
  else status<=ws2[0][0]^wc2[0][1];
 end
endmodule

module hft_core_v16_36lane(
 input logic clk,input logic rst,input logic recover,input logic session_ok,
 input logic seq_valid,input logic[31:0] rx_seq_chunk,
 input logic count_valid,input logic[15:0] msg_count,
 input logic packet_start,input logic sem_valid,input logic[287:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;logic busy,conflict,ov,packet_ok,recovery_hold;
 logic cqv;logic[15:0] cq;
 always_ff @(posedge clk)begin if(rst)begin cqv<=0;cq<=0;end else begin cqv<=count_valid;if(count_valid)cq<=msg_count;end end
 logic launch;assign launch=cqv&packet_ok&(cq!=0)&(cq!=16'hffff);
 updater16_micro u(.clk(clk),.rst(rst),.launch(launch),.count(cq),.e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(busy),.conflict(conflict),.ov(ov));
 logic gate_in;assign gate_in=session_ok&~busy&~recovery_hold&~launch;
 seq_fast16 q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx(rx_seq_chunk),.exp_hi({e3,e2}),.exp_lo({e1,e0}),.gate_in(gate_in),.accept(accept_fast),.packet_ok(packet_ok),.mismatch(mismatch));
 always_ff @(posedge clk)begin if(rst)recovery_hold<=0;else if(recover)recovery_hold<=0;else if(mismatch|conflict|ov|(cqv&packet_ok&(cq==16'hffff)))recovery_hold<=1;end
 assign slow_required=recovery_hold|busy|conflict|ov;
 logic semv_q,start_q;logic[287:0] sem_q;
 always_ff @(posedge clk)begin if(rst)begin semv_q<=0;start_q<=0;sem_q<=0;end else begin semv_q<=sem_valid&packet_ok&~recovery_hold;start_q<=packet_start;if(sem_valid)sem_q<=semantic_bytes;end end
 (* keep *) logic[53:0] ws2[0:35],wc2[0:35];
 genvar i;generate for(i=0;i<36;i=i+1)begin:L pf_allcsa_lane16 p(.clk(clk),.rst(rst),.packet_start(start_q),.valid(semv_q),.x(sem_q[i*8+:8]),.out_s2(ws2[i]),.out_c2(wc2[i]));end endgenerate
 always_ff @(posedge clk)begin if(rst)status<=0;else status<=ws2[0][0]^wc2[35][1];end
endmodule
