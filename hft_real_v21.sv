// HFT v21: protocol-faithful sequence state + packet-local 2-message/cycle Jordan PacketFence.

module seq_hoist21_bench #(
 parameter [47:0] INIT_HI=48'd0,
 parameter [15:0] INIT_LO=16'd0,
 parameter [47:0] INIT_HIP1=48'd1
)(
 input logic clk,input logic rst,
 input logic pkt_valid,input logic session_ok,
 input logic[63:0] rx_seq,input logic[15:0] msg_count,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos
);
 (* keep *) logic[15:0] elo,eh0,eh1,eh2;
 (* keep *) logic[15:0] ph0,ph1,ph2; // H+1 shadow
 logic eq0,eq1,eq2,eq3,seq_eq;
 logic[16:0] low_sum,ph0_inc,ph1_inc;
 typedef enum logic[1:0]{P_IDLE,P_L1,P_L2} pst_t;
 pst_t pst;

 logic cand_v,cand_ok,cand_normal,cand_carry;
 logic[15:0] cand_lo;

 always_comb begin
  eq0=(rx_seq[15:0]==elo);
  eq1=(rx_seq[31:16]==eh0);
  eq2=(rx_seq[47:32]==eh1);
  eq3=(rx_seq[63:48]==eh2);
  seq_eq=eq0&eq1&eq2&eq3;
  low_sum={1'b0,elo}+{1'b0,msg_count};
  ph0_inc={1'b0,ph0}+17'd1;
  ph1_inc={1'b0,ph1}+17'd1;
 end

 always_ff @(posedge clk) begin
  if(rst) begin
   elo<=INIT_LO;
   eh0<=INIT_HI[15:0];eh1<=INIT_HI[31:16];eh2<=INIT_HI[47:32];
   ph0<=INIT_HIP1[15:0];ph1<=INIT_HIP1[31:16];ph2<=INIT_HIP1[47:32];
   pst<=P_IDLE;
   cand_v<=0;cand_ok<=0;cand_normal<=0;cand_carry<=0;cand_lo<=0;
   accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;
  end else begin
   accept_fast<=0;slow_required<=0;eos<=0;

   // Commit prior candidate. Only rare low carry touches high 48 bits.
   if(cand_v && cand_ok && cand_normal) begin
    elo<=cand_lo;
    if(cand_carry) begin
     if(pst==P_IDLE) begin
      eh0<=ph0;eh1<=ph1;eh2<=ph2;
      ph0<=ph0_inc[15:0];
      if(ph0_inc[16]) pst<=P_L1;
     end else slow_required<=1;
    end
   end

   // Rare background refresh of precomputed H+1.
   if(pst==P_L1) begin
    ph1<=ph1_inc[15:0];
    if(ph1_inc[16]) pst<=P_L2; else pst<=P_IDLE;
   end else if(pst==P_L2) begin
    ph2<=ph2+16'd1;
    pst<=P_IDLE;
   end

   cand_v<=pkt_valid;
   if(pkt_valid) begin
    mismatch<=~(session_ok&seq_eq);
    cand_ok<=session_ok&seq_eq&~(low_sum[16]&&(pst!=P_IDLE));
    cand_normal<=(msg_count!=16'd0)&&(msg_count!=16'hffff);
    cand_carry<=low_sum[16];
    cand_lo<=low_sum[15:0];

    if(session_ok&seq_eq) begin
     if(msg_count==16'hffff) eos<=1;
     else if(low_sum[16]&&(pst!=P_IDLE)) slow_required<=1;
     else accept_fast<=1; // includes heartbeat; no state advance for count=0
    end else slow_required<=1;
   end
  end
 end
endmodule

module packetfence2_jordan21_bench(
 input logic clk,input logic rst,input logic pkt_start,
 input logic[1:0] valid_count,
 input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic overflow,output logic status
);
 // Exact for <=64 messages of unsigned 8-bit coordinates.
 (* keep *) logic[13:0] z0[0:16];
 (* keep *) logic[18:0] z1[0:16];
 (* keep *) logic[23:0] z2[0:16];
 logic[6:0] nmsg;
 integer i;

 always_ff @(posedge clk) begin
  if(rst) begin
   nmsg<=0;overflow<=0;status<=0;
   for(i=0;i<17;i=i+1) begin z0[i]<=0;z1[i]<=0;z2[i]<=0; end
  end else if(pkt_start) begin
   overflow<=(valid_count>2);
   nmsg<=valid_count;
   for(i=0;i<17;i=i+1) begin
    if(valid_count==2) begin
     // Starting from zero, apply x then y exactly.
     z0[i] <= sem_x[i*8 +:8] + sem_y[i*8 +:8];
     z1[i] <= sem_x[i*8 +:8];
     z2[i] <= 0;
    end else if(valid_count==1) begin
     z0[i] <= sem_x[i*8 +:8];
     z1[i] <= 0;
     z2[i] <= 0;
    end else begin
     z0[i]<=0;z1[i]<=0;z2[i]<=0;
    end
   end
   status<=0;
  end else begin
   if(valid_count!=0) begin
    if((nmsg+valid_count)>7'd64) overflow<=1;
    else begin
     nmsg<=nmsg+valid_count;
     for(i=0;i<17;i=i+1) begin
      if(valid_count==2) begin
       z0[i] <= z0[i] + sem_x[i*8 +:8] + sem_y[i*8 +:8];
       z1[i] <= z1[i] + (z0[i]<<1) + sem_x[i*8 +:8];
       z2[i] <= z2[i] + (z1[i]<<1) + z0[i];
      end else begin
       z0[i] <= z0[i] + sem_x[i*8 +:8];
       z1[i] <= z1[i] + z0[i];
       z2[i] <= z2[i] + z1[i];
      end
     end
    end
   end
   status<=z2[0][0]^z2[8][7]^z2[16][13];
  end
 end
endmodule

module hft_hotpair21_bench(
 input logic clk,input logic rst,
 input logic pkt_valid,input logic session_ok,
 input logic[63:0] rx_seq,input logic[15:0] msg_count,
 input logic pkt_start,input logic[1:0] valid_count,
 input logic[135:0] sem_x,input logic[135:0] sem_y,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos,
 output logic pf_overflow,output logic status
);
 logic ps;
 seq_hoist21_bench q(.clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),
  .rx_seq(rx_seq),.msg_count(msg_count),.accept_fast(accept_fast),.mismatch(mismatch),
  .slow_required(slow_required),.eos(eos));
 packetfence2_jordan21_bench p(.clk(clk),.rst(rst),.pkt_start(pkt_start),
  .valid_count(valid_count),.sem_x(sem_x),.sem_y(sem_y),.overflow(pf_overflow),.status(ps));
 assign status=ps^accept_fast;
endmodule

module mold_addorder_decode21(
 input logic[511:0] beat,
 output logic[79:0] session,output logic[63:0] seq,output logic[15:0] count,
 output logic[15:0] msg_len,output logic[7:0] msg_type,output logic[135:0] semantic,
 output logic one_addorder
);
 always_comb begin
  session=beat[511 -:80];
  seq=beat[431 -:64];
  count=beat[367 -:16];
  msg_len=beat[351 -:16];
  msg_type=beat[335 -:8];
  semantic={beat[247 -:64],beat[183 -:8],beat[175 -:32],beat[79 -:32]};
  one_addorder=(count==16'd1)&&(msg_len==16'd36)&&(msg_type==8'h41);
 end
endmodule
