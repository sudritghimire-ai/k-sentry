// HFT v26: eight registered 8-bit equality leaves, one 16-bit low-word add.
// Rare low-word carry is slow-path; recover_valid reloads the canonical 64-bit sequence.

module seq8leaf26_bench #(
 parameter [63:0] INIT_SEQ=64'd0
)(
 input logic clk,input logic rst,input logic pkt_valid,input logic session_ok,
 input logic[63:0] rx_seq,input logic[15:0] msg_count,
 input logic recover_valid,input logic[63:0] recover_seq,
 output logic accept_fast,output logic mismatch,output logic slow_required,
 output logic eos,output logic semantic_fast_ok
);
 (* keep *) logic[15:0] e0,e1,e2,e3;
 (* keep *) logic[7:0] mb;
 logic msess,s_v,s_hb,s_eos,s_normal,s_carry,s_semok;
 logic[15:0] s_lo;
 logic[16:0] low_sum;
 logic stage_match;

 always_comb begin
  low_sum={1'b0,e0}+{1'b0,msg_count};
  stage_match=(&mb)&msess;
 end

 always_ff @(posedge clk) begin
  if(rst) begin
   e0<=INIT_SEQ[15:0];e1<=INIT_SEQ[31:16];e2<=INIT_SEQ[47:32];e3<=INIT_SEQ[63:48];
   mb<=0;msess<=0;s_v<=0;s_hb<=0;s_eos<=0;s_normal<=0;s_carry<=0;s_semok<=0;s_lo<=0;
   accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;
  end else begin
   accept_fast<=0;slow_required<=0;eos<=0;semantic_fast_ok<=0;

   if(recover_valid) begin
    e0<=recover_seq[15:0];e1<=recover_seq[31:16];e2<=recover_seq[47:32];e3<=recover_seq[63:48];
    s_v<=0;
   end else if(s_v) begin
    mismatch<=~stage_match;
    if(!stage_match) slow_required<=1;
    else if(s_eos) eos<=1;
    else if(s_hb) accept_fast<=1;
    else if(s_normal) begin
     if(s_carry) slow_required<=1;
     else begin e0<=s_lo;accept_fast<=1;semantic_fast_ok<=s_semok;end
    end else slow_required<=1;
   end

   if(!recover_valid) begin
    s_v<=pkt_valid;
    if(pkt_valid) begin
     mb[0]<=rx_seq[7:0]   ==e0[7:0];
     mb[1]<=rx_seq[15:8]  ==e0[15:8];
     mb[2]<=rx_seq[23:16] ==e1[7:0];
     mb[3]<=rx_seq[31:24] ==e1[15:8];
     mb[4]<=rx_seq[39:32] ==e2[7:0];
     mb[5]<=rx_seq[47:40] ==e2[15:8];
     mb[6]<=rx_seq[55:48] ==e3[7:0];
     mb[7]<=rx_seq[63:56] ==e3[15:8];
     msess<=session_ok;
     s_hb<=msg_count==16'd0;
     s_eos<=msg_count==16'hffff;
     s_normal<=(msg_count!=16'd0)&&(msg_count!=16'hffff);
     s_carry<=low_sum[16];
     s_lo<=low_sum[15:0];
     s_semok<=msg_count<=16'd64;
    end
   end
  end
 end
endmodule
