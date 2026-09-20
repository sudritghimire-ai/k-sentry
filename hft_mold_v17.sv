// HFT v17: MoldUDP64 layout-aware sequence integrity.
// Mold header: session[0..9], sequence[10..17], count[18..19].
// On a 64-bit parser beat schedule, sequence high 48 bits are available before
// sequence low 16 bits + count. Precompare 48 bits, finish with only 16-bit compare.

module mold_seq64_baseline17(
 input logic clk,input logic rst,
 input logic hi_valid,input logic[47:0] rx_hi,
 input logic lo_valid,input logic[15:0] rx_lo,
 input logic[47:0] exp_hi,input logic[15:0] exp_lo,
 output logic eq,output logic lt
);
 logic[47:0] hi_q;
 always_ff @(posedge clk)begin
  if(rst)begin hi_q<=0;eq<=0;lt<=0;end
  else begin
   if(hi_valid)hi_q<=rx_hi;
   if(lo_valid)begin
    eq<={hi_q,rx_lo}=={exp_hi,exp_lo};
    lt<={hi_q,rx_lo}<{exp_hi,exp_lo};
   end
  end
 end
endmodule

module mold_seq_stream17(
 input logic clk,input logic rst,
 input logic hi_valid,input logic[47:0] rx_hi,
 input logic lo_valid,input logic[15:0] rx_lo,
 input logic[47:0] exp_hi,input logic[15:0] exp_lo,input logic gate_in,
 output logic accept,output logic packet_ok,output logic mismatch
);
 logic hi_bad,gate_q;
 always_ff @(posedge clk)begin
  if(rst)begin hi_bad<=0;gate_q<=0;accept<=0;packet_ok<=0;mismatch<=0;end
  else begin
   accept<=0;
   if(hi_valid)begin hi_bad<=rx_hi!=exp_hi;gate_q<=gate_in;packet_ok<=0;end
   if(lo_valid)begin
    mismatch<=hi_bad|(rx_lo!=exp_lo);
    packet_ok<=gate_q&~hi_bad&(rx_lo==exp_lo);
    accept<=gate_q&~hi_bad&(rx_lo==exp_lo);
   end
  end
 end
endmodule

module upd17_staged(
 input logic clk,input logic rst,input logic launch,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3,output logic busy,output logic conflict,output logic ov
);
 typedef enum logic[1:0]{IDLE=0,C01=1,I2=2,I3=3} st_t;st_t st;
 logic[16:0] a0,a1,a2,a3;logic[15:0] r0,r1,r2;logic c0,c1,c2;
 always_comb begin a0={1'b0,e0}+{1'b0,count};a1={1'b0,e1}+17'd1;a2={1'b0,e2}+17'd1;a3={1'b0,e3}+17'd1;end
 always_ff @(posedge clk)begin
  if(rst)begin e0<=0;e1<=0;e2<=0;e3<=0;st<=IDLE;busy<=0;conflict<=0;ov<=0;r0<=0;r1<=0;r2<=0;c0<=0;c1<=0;c2<=0;end
  else begin
   conflict<=0;ov<=0;if(launch&&st!=IDLE)conflict<=1;
   case(st)
    IDLE:begin busy<=0;if(launch)begin r0<=a0[15:0];c0<=a0[16];r1<=a1[15:0];c1<=a1[16];st<=C01;busy<=1;end end
    C01:begin e0<=r0;if(c0)e1<=r1;if(c0&&c1)begin r2<=a2[15:0];c2<=a2[16];st<=I2;busy<=1;end else begin st<=IDLE;busy<=0;end end
    I2:begin e2<=r2;if(c2)begin st<=I3;busy<=1;end else begin st<=IDLE;busy<=0;end end
    I3:begin e3<=a3[15:0];ov<=a3[16];st<=IDLE;busy<=0;end
   endcase
  end
 end
endmodule

module pf_csa54_lane17(
 input logic clk,input logic rst,input logic pkt_start,input logic valid,input logic[7:0] x,
 output logic[53:0] os2,output logic[53:0] oc2
);
 (* keep *) logic fresh;(* keep *) logic[23:0] s0,c0;(* keep *) logic[38:0] s1,c1;(* keep *) logic[53:0] s2,c2;
 logic[23:0] b0,x0,ns0,nc0;logic[38:0] b10,z0e,t1s,t1c,b11,c0e,ns1,nc1;
 logic[53:0] b20,z1e,t2s,t2c,b21,c1e,ns2,nc2;
 always_comb begin
  b0={c0[22:0],1'b0};x0={{16{1'b0}},x};ns0=s0^b0^x0;nc0=(s0&b0)|(s0&x0)|(b0&x0);
  b10={c1[37:0],1'b0};z0e={{15{1'b0}},s0};t1s=s1^b10^z0e;t1c=(s1&b10)|(s1&z0e)|(b10&z0e);
  b11={t1c[37:0],1'b0};c0e={{14{1'b0}},c0,1'b0};ns1=t1s^b11^c0e;nc1=(t1s&b11)|(t1s&c0e)|(b11&c0e);
  b20={c2[52:0],1'b0};z1e={{15{1'b0}},s1};t2s=s2^b20^z1e;t2c=(s2&b20)|(s2&z1e)|(b20&z1e);
  b21={t2c[52:0],1'b0};c1e={{14{1'b0}},c1,1'b0};ns2=t2s^b21^c1e;nc2=(t2s&b21)|(t2s&c1e)|(b21&c1e);
 end
 always_ff @(posedge clk)begin
  if(rst)begin fresh<=1;s0<=0;c0<=0;s1<=0;c1<=0;s2<=0;c2<=0;end
  else begin
   if(pkt_start)fresh<=1;
   if(valid)begin
    if(fresh)begin s0<={{16{1'b0}},x};c0<=0;s1<=0;c1<=0;s2<=0;c2<=0;fresh<=0;end
    else begin s0<=ns0;c0<=nc0;s1<=ns1;c1<=nc1;s2<=ns2;c2<=nc2;end
   end
  end
 end
 assign os2=s2;assign oc2=c2;
endmodule

module hft_mold_core_v17_17lane(
 input logic clk,input logic rst,input logic recover,input logic session_ok,
 input logic seq_hi_valid,input logic[47:0] rx_seq_hi,
 input logic seq_lo_count_valid,input logic[15:0] rx_seq_lo,input logic[15:0] msg_count,
 input logic packet_sem_start,input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 logic busy,conflict,ov,packet_ok,recovery;
 logic gate_in;assign gate_in=session_ok&~busy&~recovery;
 mold_seq_stream17 q(.clk(clk),.rst(rst),.hi_valid(seq_hi_valid),.rx_hi(rx_seq_hi),
  .lo_valid(seq_lo_count_valid),.rx_lo(rx_seq_lo),.exp_hi({e3,e2,e1}),.exp_lo(e0),
  .gate_in(gate_in),.accept(accept_fast),.packet_ok(packet_ok),.mismatch(mismatch));

 // Count and acceptance are registered together on the low-sequence beat.
 logic pending;logic[15:0] cq;logic okq;
 always_ff @(posedge clk)begin
  if(rst)begin pending<=0;cq<=0;okq<=0;end
  else begin
   pending<=seq_lo_count_valid;
   if(seq_lo_count_valid)begin cq<=msg_count;okq<=gate_in&~q.hi_bad&(rx_seq_lo==e0);end
  end
 end
 logic launch;assign launch=pending&okq&(cq!=0)&(cq!=16'hffff);
 upd17_staged u(.clk(clk),.rst(rst),.launch(launch),.count(cq),.e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(busy),.conflict(conflict),.ov(ov));

 always_ff @(posedge clk)begin
  if(rst)recovery<=0;
  else if(recover)recovery<=0;
  else if(mismatch|conflict|ov|(pending&okq&(cq==16'hffff)))recovery<=1;
 end
 assign slow_required=recovery|busy|conflict|ov;

 logic semv_q,start_q;logic[135:0] sem_q;
 always_ff @(posedge clk)begin
  if(rst)begin semv_q<=0;start_q<=0;sem_q<=0;end
  else begin semv_q<=sem_valid&packet_ok&~recovery;start_q<=packet_sem_start;if(sem_valid)sem_q<=semantic_bytes;end
 end
 (* keep *) logic[53:0] ss[0:16],cc[0:16];
 genvar i;generate for(i=0;i<17;i=i+1)begin:L pf_csa54_lane17 p(.clk(clk),.rst(rst),.pkt_start(start_q),.valid(semv_q),.x(sem_q[i*8+:8]),.os2(ss[i]),.oc2(cc[i]));end endgenerate
 always_ff @(posedge clk)begin if(rst)status<=0;else status<=ss[0][0]^cc[0][1];end
endmodule
