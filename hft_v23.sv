// HFT v23: registered 16-bit equality leaves + control-decoupled two-phase PacketFence.

module seq_stage23_bench #(
 parameter [47:0] INIT_HI=48'd0,
 parameter [15:0] INIT_LO=16'd0,
 parameter [47:0] INIT_HIP1=48'd1
)(
 input logic clk,input logic rst,
 input logic pkt_valid,input logic session_ok,input logic[63:0] rx_seq,input logic[15:0] msg_count,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos
);
 (* keep *) logic[15:0] elo,eh0,eh1,eh2,ph0,ph1,ph2;
 logic[16:0] low_sum,ph0_inc,ph1_inc;
 typedef enum logic[1:0]{P_IDLE,P_L1,P_L2} pst_t; pst_t pst;

 // Stage-A leaves: no wide AND cone before these flops.
 (* keep *) logic m0,m1,m2,m3,msess;
 logic s_v,s_normal,s_eos,s_carry;logic[15:0] s_lo;
 logic stage_match;

 always_comb begin
  low_sum={1'b0,elo}+{1'b0,msg_count};
  ph0_inc={1'b0,ph0}+17'd1;
  ph1_inc={1'b0,ph1}+17'd1;
  stage_match=m0&m1&m2&m3&msess;
 end

 always_ff @(posedge clk) begin
  if(rst) begin
   elo<=INIT_LO;eh0<=INIT_HI[15:0];eh1<=INIT_HI[31:16];eh2<=INIT_HI[47:32];
   ph0<=INIT_HIP1[15:0];ph1<=INIT_HIP1[31:16];ph2<=INIT_HIP1[47:32];pst<=P_IDLE;
   m0<=0;m1<=0;m2<=0;m3<=0;msess<=0;s_v<=0;s_normal<=0;s_eos<=0;s_carry<=0;s_lo<=0;
   accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;
  end else begin
   accept_fast<=0;slow_required<=0;eos<=0;

   // Stage B uses only registered 1-bit comparisons and registered candidate data.
   if(s_v) begin
    mismatch<=~stage_match;
    if(stage_match) begin
     if(s_eos) eos<=1;
     else if(s_normal) begin
      if(s_carry && pst!=P_IDLE) slow_required<=1;
      else begin
       elo<=s_lo;
       if(s_carry) begin
        eh0<=ph0;eh1<=ph1;eh2<=ph2;
        ph0<=ph0_inc[15:0];
        if(ph0_inc[16]) pst<=P_L1;
       end
       accept_fast<=1;
      end
     end else accept_fast<=1;
    end else slow_required<=1;
   end

   if(pst==P_L1) begin
    ph1<=ph1_inc[15:0];
    if(ph1_inc[16]) pst<=P_L2; else pst<=P_IDLE;
   end else if(pst==P_L2) begin
    ph2<=ph2+16'd1;pst<=P_IDLE;
   end

   // Stage A: 4 independent 16-bit compares + one 16-bit add.
   s_v<=pkt_valid;
   if(pkt_valid) begin
    m0<=rx_seq[15:0]==elo;
    m1<=rx_seq[31:16]==eh0;
    m2<=rx_seq[47:32]==eh1;
    m3<=rx_seq[63:48]==eh2;
    msess<=session_ok;
    s_normal<=(msg_count!=0)&&(msg_count!=16'hffff);
    s_eos<=(msg_count==16'hffff);
    s_carry<=low_sum[16];
    s_lo<=low_sum[15:0];
   end
  end
 end
endmodule

module packetfence2_phase23_bench(
 input logic clk,input logic rst,input logic pkt_start,
 input logic[1:0] valid_count,input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic overflow,output logic status
);
 (* keep *) logic[12:0] x0[0:16],y0[0:16];
 (* keep *) logic[16:0] x1[0:16],y1[0:16];
 (* keep *) logic[20:0] x2[0:16],y2[0:16];
 logic[6:0] nmsg;
 integer i;

 always_ff @(posedge clk) begin
  if(rst) begin
   nmsg<=0;overflow<=0;status<=0;
   for(i=0;i<17;i=i+1) begin x0[i]<=0;x1[i]<=0;x2[i]<=0;y0[i]<=0;y1[i]<=0;y2[i]<=0;end
  end else if(pkt_start) begin
   nmsg<=valid_count;overflow<=0;
   for(i=0;i<17;i=i+1) begin
    if(valid_count>=1) begin x0[i]<=sem_x[i*8+:8];x1[i]<=0;x2[i]<=0;end
    else begin x0[i]<=0;x1[i]<=0;x2[i]<=0;end
    if(valid_count==2) begin y0[i]<=sem_y[i*8+:8];y1[i]<=0;y2[i]<=0;end
    else begin y0[i]<=0;y1[i]<=0;y2[i]<=0;end
   end
  end else begin
   // Count/overflow path is advisory only; it never gates the arithmetic updates.
   if(valid_count!=0) begin
    nmsg<=nmsg+valid_count;
    if((nmsg+valid_count)>7'd64) overflow<=1;
    for(i=0;i<17;i=i+1) begin
     x0[i]<=x0[i]+sem_x[i*8+:8];
     x1[i]<=x1[i]+x0[i];
     x2[i]<=x2[i]+x1[i];
     if(valid_count==2) begin
      y0[i]<=y0[i]+sem_y[i*8+:8];
      y1[i]<=y1[i]+y0[i];
      y2[i]<=y2[i]+y1[i];
     end
    end
   end
   status<=x2[0][0]^y2[0][1]^x2[8][7]^y2[16][13];
  end
 end
endmodule

module hft_hot23_bench(
 input logic clk,input logic rst,input logic pkt_valid,input logic session_ok,
 input logic[63:0] rx_seq,input logic[15:0] msg_count,
 input logic pkt_start,input logic[1:0] valid_count,input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos,
 output logic pf_overflow,output logic status
);
 logic ps;
 seq_stage23_bench q(.clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),.rx_seq(rx_seq),.msg_count(msg_count),
  .accept_fast(accept_fast),.mismatch(mismatch),.slow_required(slow_required),.eos(eos));
 packetfence2_phase23_bench p(.clk(clk),.rst(rst),.pkt_start(pkt_start),.valid_count(valid_count),.sem_x(sem_x),.sem_y(sem_y),
  .overflow(pf_overflow),.status(ps));
 assign status=ps^accept_fast;
endmodule
