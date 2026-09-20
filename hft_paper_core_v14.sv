// HFT v14 paper-core candidate.
// Complete common path:
//   - two 32-bit streamed exact comparison of 64-bit MoldUDP64 sequence
//   - bad packet never advances expected sequence
//   - count 0 heartbeat: no advance
//   - count FFFF end-session: control path, no advance
//   - normal counts 1..FFFE update exact 64-bit expected state via staged 16-bit engine
//   - 17 semantic lanes use exact carry-save Jordan PacketFence state
//   - semantic state only advances for sequence-validated packet
//   - updater conflict/busy blocks fast acceptance, preserving correctness
// Wide integrity state remains internal to avoid artificial I/O placement effects.

module seq64_staged_updater14(
 input logic clk,input logic rst,input logic launch,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3,
 output logic busy,output logic conflict,output logic seq_overflow
);
 typedef enum logic[1:0] {IDLE=2'd0,C01=2'd1,I2=2'd2,I3=2'd3} st_t;
 st_t st;
 logic[16:0] a0,a1,a2,a3;
 logic[15:0] r0,r1,r2;
 logic c0,c1,c2;
 always_comb begin
   a0={1'b0,e0}+{1'b0,count};
   a1={1'b0,e1}+17'd1;
   a2={1'b0,e2}+17'd1;
   a3={1'b0,e3}+17'd1;
 end
 always_ff @(posedge clk) begin
   if(rst) begin
     e0<='0;e1<='0;e2<='0;e3<='0;st<=IDLE;busy<=0;conflict<=0;seq_overflow<=0;
     r0<='0;r1<='0;r2<='0;c0<=0;c1<=0;c2<=0;
   end else begin
     conflict<=0;seq_overflow<=0;
     if(launch && st!=IDLE) conflict<=1;
     case(st)
       IDLE: begin
         busy<=0;
         if(launch) begin
           r0<=a0[15:0];c0<=a0[16];
           r1<=a1[15:0];c1<=a1[16];
           st<=C01;busy<=1;
         end
       end
       C01: begin
         e0<=r0;
         if(c0)e1<=r1;
         if(c0&&c1) begin r2<=a2[15:0];c2<=a2[16];st<=I2;busy<=1; end
         else begin st<=IDLE;busy<=0; end
       end
       I2: begin
         e2<=r2;
         if(c2) begin st<=I3;busy<=1; end
         else begin st<=IDLE;busy<=0; end
       end
       I3: begin
         e3<=a3[15:0];seq_overflow<=a3[16];st<=IDLE;busy<=0;
       end
     endcase
   end
 end
endmodule

module seq_stream_compare14(
 input logic clk,input logic rst,input logic seq_valid,input logic[31:0] rx_chunk,
 input logic[31:0] exp_hi,input logic[31:0] exp_lo,input logic updater_busy,input logic session_ok,
 output logic accept_pulse,output logic packet_seq_ok,output logic mismatch,output logic slow_required
);
 logic phase,first_bad,blocked,neq;
 always_comb neq=(rx_chunk!=(phase?exp_lo:exp_hi));
 always_ff @(posedge clk) begin
   if(rst) begin phase<=0;first_bad<=0;blocked<=0;accept_pulse<=0;packet_seq_ok<=0;mismatch<=0;slow_required<=0; end
   else begin
     accept_pulse<=0;
     if(seq_valid) begin
       if(!phase) begin
         packet_seq_ok<=0;
         first_bad<=neq;
         blocked<=updater_busy|!session_ok;
         mismatch<=neq;
         slow_required<=updater_busy|!session_ok;
         phase<=1;
       end else begin
         mismatch<=first_bad|neq;
         slow_required<=blocked;
         packet_seq_ok<=!(first_bad|neq|blocked);
         accept_pulse<=!(first_bad|neq|blocked);
         phase<=0;
       end
     end
   end
 end
endmodule

module pf_csa_lane14(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[17:0] s1,output logic[17:0] c1,
 output logic[21:0] s2,output logic[21:0] c2
);
 logic[12:0] z0n;
 logic[17:0] b1,d1,s1n,c1n;
 logic[21:0] b20,d20,tS,tC,b21,d21,s2n,c2n;
 always_comb begin
   z0n=z0+x;
   b1={c1[16:0],1'b0};d1={{5{1'b0}},z0};
   s1n=s1^b1^d1;c1n=(s1&b1)|(s1&d1)|(b1&d1);
   b20={c2[20:0],1'b0};d20={{4{1'b0}},s1};
   tS=s2^b20^d20;tC=(s2&b20)|(s2&d20)|(b20&d20);
   b21={tC[20:0],1'b0};d21={{3{1'b0}},c1,1'b0};
   s2n=tS^b21^d21;c2n=(tS&b21)|(tS&d21)|(b21&d21);
 end
 always_ff @(posedge clk) begin
   if(rst) begin z0<='0;s1<='0;c1<='0;s2<='0;c2<='0; end
   else if(valid) begin z0<=z0n;s1<=s1n;c1<=c1n;s2<=s2n;c2<=c2n; end
 end
endmodule

module hft_paper_core_v14(
 input logic clk,input logic rst,
 input logic session_ok,
 input logic seq_valid,input logic[31:0] rx_seq_chunk,
 input logic count_valid,input logic[15:0] msg_count,
 input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic slow_required,
 output logic heartbeat,output logic end_session,output logic updater_conflict,
 output logic integrity_status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 logic updater_busy,seqov,packet_seq_ok;
 logic normal_count,launch;
 assign normal_count=(msg_count!=16'h0000)&&(msg_count!=16'hffff);
 assign launch=count_valid & packet_seq_ok & normal_count;
 assign heartbeat=count_valid & packet_seq_ok & (msg_count==16'h0000);
 assign end_session=count_valid & packet_seq_ok & (msg_count==16'hffff);

 seq64_staged_updater14 u(.clk(clk),.rst(rst),.launch(launch),.count(msg_count),
   .e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(updater_busy),.conflict(updater_conflict),.seq_overflow(seqov));

 seq_stream_compare14 q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx_chunk(rx_seq_chunk),
   .exp_hi({e3,e2}),.exp_lo({e1,e0}),.updater_busy(updater_busy),.session_ok(session_ok),
   .accept_pulse(accept_fast),.packet_seq_ok(packet_seq_ok),.mismatch(mismatch),.slow_required(slow_required));

 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[17:0] s1[0:16],c1[0:16];
 (* keep *) logic[21:0] s2[0:16],c2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   pf_csa_lane14 p(.clk(clk),.rst(rst),.valid(sem_valid & packet_seq_ok),.x(semantic_bytes[i*8 +:8]),
     .z0(z0[i]),.s1(s1[i]),.c1(c1[i]),.s2(s2[i]),.c2(c2[i]));
 end endgenerate
 // Prevent optimization while keeping integrity state internal.
 assign integrity_status = z0[0][0]^s1[5][3]^c1[8][7]^s2[12][11]^c2[16][19]^seqov;
endmodule
