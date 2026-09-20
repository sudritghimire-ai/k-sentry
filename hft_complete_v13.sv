// HFT v13: protocol-aware staged exact expected-sequence updater.
// Normal update: two parallel 16-bit adders, commit next cycle.
// 32-bit low-word wrap enters a rare micro-path that increments upper limbs.
// Any new sequence arriving while updater busy is explicitly rejected from fast path.
// Exact for all schedules; throughput degradation only triggers slow path.

module seq64_staged16_updater(
 input logic clk,input logic rst,input logic count_valid,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3,
 output logic busy,output logic overflow_event
);
 typedef enum logic[1:0] {IDLE=2'd0, COMMIT01=2'd1, INC2=2'd2, INC3=2'd3} st_t;
 st_t st;
 logic[16:0] s0, i1, i2, i3;
 logic[15:0] r0,r1,r2;
 logic c0,c1,c2;
 always_comb begin
   s0={1'b0,e0}+{1'b0,count};
   i1={1'b0,e1}+17'd1;
   i2={1'b0,e2}+17'd1;
   i3={1'b0,e3}+17'd1;
 end
 always_ff @(posedge clk) begin
   if(rst) begin
     e0<='0;e1<='0;e2<='0;e3<='0;st<=IDLE;busy<=0;overflow_event<=0;
     r0<='0;r1<='0;r2<='0;c0<=0;c1<=0;c2<=0;
   end else begin
     overflow_event<=0;
     case(st)
       IDLE: begin
         busy<=0;
         if(count_valid) begin
           r0<=s0[15:0]; c0<=s0[16];
           r1<=i1[15:0]; c1<=i1[16];
           st<=COMMIT01; busy<=1;
         end
       end
       COMMIT01: begin
         e0<=r0;
         if(c0) e1<=r1;
         if(c0 && c1) begin
           r2<=i2[15:0]; c2<=i2[16];
           st<=INC2; busy<=1;
         end else begin
           st<=IDLE; busy<=0;
         end
       end
       INC2: begin
         e2<=r2;
         if(c2) begin
           st<=INC3; busy<=1;
         end else begin
           st<=IDLE;busy<=0;
         end
       end
       INC3: begin
         e3<=i3[15:0];
         overflow_event<=i3[16];
         st<=IDLE;busy<=0;
       end
     endcase
   end
 end
endmodule

module seq32_state_compare13(
 input logic clk,input logic rst,input logic seq_valid,input logic[31:0] rx_chunk,
 input logic[31:0] exp_hi,input logic[31:0] exp_lo,input logic updater_busy,
 output logic accept_fast,output logic mismatch,output logic slow_required
);
 logic phase,first_bad,neq,blocked;
 always_comb neq=(rx_chunk != (phase ? exp_lo : exp_hi));
 always_ff @(posedge clk) begin
   if(rst) begin phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0;slow_required<=0;blocked<=0; end
   else begin
     accept_fast<=0;
     if(seq_valid) begin
       if(!phase) begin
         blocked<=updater_busy;
         first_bad<=neq;
         mismatch<=neq;
         slow_required<=updater_busy;
         phase<=1;
       end else begin
         mismatch<=first_bad|neq;
         slow_required<=blocked;
         accept_fast<=!(first_bad|neq|blocked);
         phase<=0;
       end
     end
   end
 end
endmodule

module pf_csa_lane13(
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

module complete_hft_v13_bench(
 input logic clk,input logic rst,
 input logic seq_valid,input logic[31:0] rx_chunk,
 input logic count_valid,input logic[15:0] count,
 input logic sem_valid,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic updater_busy,
 output logic[21:0] witness_s,output logic[21:0] witness_c
);
 logic[15:0] e0,e1,e2,e3;logic ov;
 seq64_staged16_updater u(.clk(clk),.rst(rst),.count_valid(count_valid),.count(count),
   .e0(e0),.e1(e1),.e2(e2),.e3(e3),.busy(updater_busy),.overflow_event(ov));
 seq32_state_compare13 q(.clk(clk),.rst(rst),.seq_valid(seq_valid),.rx_chunk(rx_chunk),
   .exp_hi({e3,e2}),.exp_lo({e1,e0}),.updater_busy(updater_busy),
   .accept_fast(accept_fast),.mismatch(mismatch),.slow_required(slow_required));
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[17:0] s1,c1;logic[21:0] s2,c2;
   pf_csa_lane13 p(.clk(clk),.rst(rst),.valid(sem_valid),.x(semantic_bytes[i*8 +:8]),
     .z0(z0),.s1(s1),.c1(c1),.s2(s2),.c2(c2));
   if(i==0) begin assign witness_s=s2;assign witness_c=c2; end
 end endgenerate
endmodule
