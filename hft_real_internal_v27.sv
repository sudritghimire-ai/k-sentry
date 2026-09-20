// v27: internal-source integrated benchmark for package-clean P&R.
// Measures seq_hoist21 + packetfence2_jordan21 together without wide top-level market-data pins.

module hft_real_internal27_bench(
 input logic clk,input logic rst,input logic[31:0] seed_in,
 output logic status
);
 (* keep *) logic[127:0] lfsr;
 logic pkt_valid,session_ok,pkt_start;
 logic[63:0] rx_seq;
 logic[15:0] msg_count;
 logic[1:0] valid_count;
 logic[135:0] sem_x,sem_y;
 logic accept_fast,mismatch,slow_required,eos,pf_overflow,pf_status;

 always_ff @(posedge clk) begin
   if(rst) lfsr <= {96'h1,seed_in};
   else lfsr <= {lfsr[126:0],lfsr[127]^lfsr[125]^lfsr[100]^lfsr[98]};
 end

 assign pkt_valid=lfsr[0];
 assign session_ok=~lfsr[1];
 assign pkt_start=lfsr[2];
 assign rx_seq=lfsr[95:32];
 assign msg_count={8'd0,lfsr[23:16]};
 assign valid_count={1'b0,lfsr[3]}+2'd1;

 genvar i;
 generate for(i=0;i<17;i=i+1) begin:G
   assign sem_x[i*8 +:8]=lfsr[(i*7)%120 +:8] ^ (8'(i*13));
   assign sem_y[i*8 +:8]=lfsr[(i*5+11)%120 +:8] ^ (8'(i*29+7));
 end endgenerate

 seq_hoist21_bench q(
   .clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),
   .rx_seq(rx_seq),.msg_count(msg_count),.accept_fast(accept_fast),
   .mismatch(mismatch),.slow_required(slow_required),.eos(eos)
 );

 packetfence2_jordan21_bench p(
   .clk(clk),.rst(rst),.pkt_start(pkt_start),.valid_count(valid_count),
   .sem_x(sem_x),.sem_y(sem_y),.overflow(pf_overflow),.status(pf_status)
 );

 assign status=accept_fast^mismatch^slow_required^eos^pf_overflow^pf_status^lfsr[17];
endmodule
