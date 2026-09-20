// v31: corrected streamed two-beat exact sequence fast path.
// High 32-bit compare is captured on hi beat. Low compare/count metadata is captured on lo beat.
// result_valid guarantees each packet decision is consumed exactly once.
// Low16 carry is rare-path: no high-word state mutation on hot path.

module seq_stream31_bench #(
 parameter [63:0] INIT_SEQ=64'd0
)(
 input logic clk,input logic rst,
 input logic seq_hi_valid,input logic[31:0] rx_hi32,
 input logic seq_lo_valid,input logic[31:0] rx_lo32,
 input logic session_ok,input logic[15:0] msg_count,
 input logic recover_valid,input logic[63:0] recover_seq,
 output logic accept_fast,output logic mismatch,output logic slow_required,
 output logic eos,output logic semantic_fast_ok
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 (* keep *) logic hi_bad;
 (* keep *) logic result_valid;
 (* keep *) logic lo_bad_q,sess_q,hb_q,eos_q,normal_q,carry_q,semok_q;
 (* keep *) logic[15:0] next_lo_q;
 logic hi_bad_now,lo_bad_now;
 logic[16:0] low_sum;

 always_comb begin
   hi_bad_now = (rx_hi32 != {e3,e2});
   lo_bad_now = (rx_lo32 != {e1,e0});
   low_sum = {1'b0,e0}+{1'b0,msg_count};
 end

 always_ff @(posedge clk) begin
   if(rst) begin
     e0<=INIT_SEQ[15:0];e1<=INIT_SEQ[31:16];e2<=INIT_SEQ[47:32];e3<=INIT_SEQ[63:48];
     hi_bad<=0;result_valid<=0;
     lo_bad_q<=0;sess_q<=0;hb_q<=0;eos_q<=0;normal_q<=0;carry_q<=0;semok_q<=0;next_lo_q<=0;
     accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;
   end else begin
     accept_fast<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;

     if(recover_valid) begin
       e0<=recover_seq[15:0];e1<=recover_seq[31:16];e2<=recover_seq[47:32];e3<=recover_seq[63:48];
       hi_bad<=0;
       result_valid<=0;
       mismatch<=0;
     end else begin
       // Consume each low-beat decision exactly once.
       if(result_valid) begin
         if(lo_bad_q || hi_bad || !sess_q) begin
           mismatch<=1;
           slow_required<=1;
         end else if(eos_q) begin
           mismatch<=0;
           eos<=1;
         end else if(hb_q) begin
           mismatch<=0;
           accept_fast<=1;
         end else if(normal_q) begin
           mismatch<=0;
           if(carry_q) slow_required<=1;
           else begin
             e0<=next_lo_q;
             accept_fast<=1;
             semantic_fast_ok<=semok_q;
           end
         end else begin
           slow_required<=1;
         end
       end

       if(seq_hi_valid) hi_bad<=hi_bad_now;

       result_valid<=seq_lo_valid;
       if(seq_lo_valid) begin
         lo_bad_q<=lo_bad_now;
         sess_q<=session_ok;
         hb_q<=(msg_count==16'd0);
         eos_q<=(msg_count==16'hffff);
         normal_q<=(msg_count!=16'd0)&&(msg_count!=16'hffff);
         carry_q<=low_sum[16];
         next_lo_q<=low_sum[15:0];
         semok_q<=(msg_count<=16'd64);
       end
     end
   end
 end
endmodule
