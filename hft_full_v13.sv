// HFT v13: decoupled compare and candidate sequence update.
// Candidate next state is captured on every second sequence beat.
// A separate one-bit accept flag decides whether candidate commits next cycle.
// This removes expected-state -> comparator -> wide-register-enable timing dependency.

module hft_full_core_v13_bench(
 input logic clk,input logic rst,
 input logic[31:0] rx_chunk,input logic seq_valid,
 input logic[15:0] msg_count,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic status
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 (* keep *) logic phase,first_bad;
 logic[31:0] exp_chunk;
 logic neq, second_beat, accept_now;

 assign exp_chunk = phase ? {e3,e2} : {e1,e0};
 assign neq = (rx_chunk != exp_chunk);
 assign second_beat = phase & seq_valid;
 assign accept_now = second_beat & ~(first_bad | neq);

 // Candidate expected-sequence state, captured independently of accept.
 (* keep *) logic cand_v, cand_accept;
 (* keep *) logic[15:0] c0,c1,c2,c3;
 logic[16:0] s0,u1,u2,u3;
 logic carry0,carry1,carry2;

 always_comb begin
   s0={1'b0,e0}+{1'b0,msg_count};
   u1={1'b0,e1}+17'd1;
   u2={1'b0,e2}+17'd1;
   u3={1'b0,e3}+17'd1;
   carry0=s0[16];
   carry1=carry0 & u1[16];
   carry2=carry1 & u2[16];
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0;
     e0<='0;e1<='0;e2<='0;e3<='0;
     cand_v<=0;cand_accept<=0;c0<='0;c1<='0;c2<='0;c3<='0;
   end else begin
     accept_fast<=0;

     // Commit prior candidate only when its comparison accepted.
     if(cand_v && cand_accept) begin
       e0<=c0;e1<=c1;e2<=c2;e3<=c3;
     end

     // Fixed two-beat exact sequence equality.
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

     // Candidate arithmetic capture occurs for EVERY second beat.
     // accept only controls later commit, not these wide register enables.
     cand_v<=second_beat;
     if(second_beat) begin
       cand_accept<=~(first_bad|neq);
       c0<=s0[15:0];
       c1<=carry0 ? u1[15:0] : e1;
       c2<=carry1 ? u2[15:0] : e2;
       c3<=carry2 ? u3[15:0] : e3;
     end
   end
 end

 // 17 semantic byte lanes in exact Jordan/finite-difference basis.
 (* keep *) logic[12:0] z0[0:16];
 (* keep *) logic[16:0] z1[0:16];
 (* keep *) logic[20:0] z2[0:16];
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   always_ff @(posedge clk) begin
     if(rst) begin z0[i]<='0;z1[i]<='0;z2[i]<='0; end
     else if(valid_sem) begin
       z0[i]<=z0[i]+semantic_bytes[i*8 +:8];
       z1[i]<=z1[i]+z0[i];
       z2[i]<=z2[i]+z1[i];
     end
   end
 end endgenerate

 assign status=z2[0][0]^e0[0];
endmodule
