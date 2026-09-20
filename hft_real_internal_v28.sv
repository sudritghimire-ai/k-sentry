// v28: parser-register-clean integrated benchmark.
// Synthetic traffic generation is registered before entering the HFT integrity core.

module hft_real_internal28_bench(
 input logic clk,input logic rst,input logic[31:0] seed_in,
 output logic status
);
 (* keep *) logic[127:0] lfsr;
 (* keep *) logic r_pkt_valid,r_session_ok,r_pkt_start;
 (* keep *) logic[63:0] r_rx_seq;
 (* keep *) logic[15:0] r_msg_count;
 (* keep *) logic[1:0] r_valid_count;
 (* keep *) logic[135:0] r_sem_x,r_sem_y;

 logic accept_fast,mismatch,slow_required,eos,pf_overflow,pf_status;
 integer k;

 always_ff @(posedge clk) begin
   if(rst) begin
     lfsr <= {96'h1,seed_in};
     r_pkt_valid<=0;r_session_ok<=1;r_pkt_start<=0;
     r_rx_seq<=0;r_msg_count<=0;r_valid_count<=0;
     r_sem_x<=0;r_sem_y<=0;
   end else begin
     lfsr <= {lfsr[126:0],lfsr[127]^lfsr[125]^lfsr[100]^lfsr[98]};
     // Parser-output register stage.
     r_pkt_valid<=lfsr[0];
     r_session_ok<=~lfsr[1];
     r_pkt_start<=lfsr[2];
     r_rx_seq<=lfsr[95:32];
     r_msg_count<={8'd0,lfsr[23:16]};
     r_valid_count<={1'b0,lfsr[3]}+2'd1;
     for(k=0;k<17;k=k+1) begin
       r_sem_x[k*8 +:8] <= lfsr[(k*7)%120 +:8] + k;
       r_sem_y[k*8 +:8] <= lfsr[(k*5+11)%120 +:8] + (k*3+1);
     end
   end
 end

 seq_hoist21_bench q(
   .clk(clk),.rst(rst),.pkt_valid(r_pkt_valid),.session_ok(r_session_ok),
   .rx_seq(r_rx_seq),.msg_count(r_msg_count),.accept_fast(accept_fast),
   .mismatch(mismatch),.slow_required(slow_required),.eos(eos)
 );

 packetfence2_jordan21_bench p(
   .clk(clk),.rst(rst),.pkt_start(r_pkt_start),.valid_count(r_valid_count),
   .sem_x(r_sem_x),.sem_y(r_sem_y),.overflow(pf_overflow),.status(pf_status)
 );

 assign status=accept_fast^mismatch^slow_required^eos^pf_overflow^pf_status;
endmodule
