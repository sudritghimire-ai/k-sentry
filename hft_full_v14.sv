// HFT v14: full decoupled two-stage core.
// Fast exact two-beat equality, raw candidate sequence arithmetic, conditional commit,
// and 17-lane Jordan PacketFence all separated to avoid cross-path timing chains.

module hft_full_core_v14_bench(
 input logic clk,input logic rst,
 input logic[31:0] rx_chunk,input logic seq_valid,
 input logic[15:0] msg_count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 (* keep *) logic phase,first_bad;
 logic[31:0] exp_chunk;
 logic neq,second_beat;

 assign exp_chunk = phase ? {e3,e2} : {e1,e0};
 assign neq = (rx_chunk != exp_chunk);
 assign second_beat = phase & seq_valid;

 // Stage-A raw next-state candidates. No compare result gates these datapath registers.
 (* keep *) logic stage_v,stage_accept;
 (* keep *) logic[15:0] r_n0,r_u1,r_u2,r_u3,r_e1,r_e2,r_e3;
 (* keep *) logic r_c0,r_ov1,r_ov2;
 logic[16:0] s0,u1,u2,u3;

 always_comb begin
   s0={1'b0,e0}+{1'b0,msg_count};
   u1={1'b0,e1}+17'd1;
   u2={1'b0,e2}+17'd1;
   u3={1'b0,e3}+17'd1;
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0;
     e0<='0;e1<='0;e2<='0;e3<='0;
     stage_v<=0;stage_accept<=0;
     r_n0<='0;r_u1<='0;r_u2<='0;r_u3<='0;
     r_e1<='0;r_e2<='0;r_e3<='0;
     r_c0<=0;r_ov1<=0;r_ov2<=0;
   end else begin
     accept_fast<=0;

     // Stage B: conditional commit from already-registered raw candidates.
     if(stage_v && stage_accept) begin
       e0<=r_n0;
       e1<=r_c0 ? r_u1 : r_e1;
       e2<=(r_c0 & r_ov1) ? r_u2 : r_e2;
       e3<=(r_c0 & r_ov1 & r_ov2) ? r_u3 : r_e3;
     end

     // Exact two-beat equality fast path.
     if(seq_valid) begin
       if(!phase) begin
         first_bad<=neq;
         mismatch<=neq;
         phase<=1;
       end else begin
         mismatch<=first_bad|neq;
         accept_fast<=~(first_bad|neq);
         phase<=0;
       end
     end

     // Stage A launch on every second beat, whether accepted or not.
     // Only the 1-bit stage_accept carries comparison result to Stage B.
     stage_v<=second_beat;
     if(second_beat) begin
       stage_accept<=~(first_bad|neq);
       r_n0<=s0[15:0];
       r_u1<=u1[15:0]; r_u2<=u2[15:0]; r_u3<=u3[15:0];
       r_e1<=e1; r_e2<=e2; r_e3<=e3;
       r_c0<=s0[16];
       r_ov1<=u1[16];
       r_ov2<=u2[16];
     end
   end
 end

 // Exact Jordan/finite-difference semantic certificate.
 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   always_ff @(posedge clk) begin
     if(rst) begin z0[i]<='0;z1[i]<='0;z2[i]<='0; end
     else if(valid_sem) begin
       z0[i]<=z0[i]+semantic_bytes[i*8 +: 8];
       z1[i]<=z1[i]+z0[i];
       z2[i]<=z2[i]+z1[i];
     end
   end
 end endgenerate

 assign status=z2[0][0]^e0[0];
endmodule
