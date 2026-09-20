// HFT v20: carry-hoisted MoldUDP64 expected-sequence state.
// Hot path: exact 4x16-bit equality + one 16-bit count add.
// High 48-bit increment is precomputed and refreshed only after a low-word carry.

module hft_fields20_bench #(
  parameter [47:0] INIT_HI = 48'd0,
  parameter [15:0] INIT_LO = 16'd0,
  parameter [47:0] INIT_HIP1 = 48'd1
)(
  input logic clk,input logic rst,
  input logic pkt_valid,input logic session_ok,
  input logic [63:0] rx_seq,input logic [15:0] msg_count,
  input logic sem_valid,input logic [135:0] semantic_bytes,
  output logic accept_fast,output logic mismatch,output logic slow_required,
  output logic eos,output logic status
);
  // Canonical expected sequence split into low 16 and high 48.
  (* keep *) logic [15:0] elo;
  (* keep *) logic [15:0] eh0,eh1,eh2; // high48 little-limb order
  // Shadow = high48 + 1, refreshed only after low16 carry.
  (* keep *) logic [15:0] ph0,ph1,ph2;

  logic eq0,eq1,eq2,eq3,seq_eq;
  always_comb begin
    eq0=(rx_seq[15:0]  == elo);
    eq1=(rx_seq[31:16] == eh0);
    eq2=(rx_seq[47:32] == eh1);
    eq3=(rx_seq[63:48] == eh2);
    seq_eq=eq0 & eq1 & eq2 & eq3;
  end

  logic [16:0] low_sum;
  always_comb low_sum={1'b0,elo}+{1'b0,msg_count};

  // One-cycle candidate register breaks compare/update coupling.
  logic cand_v,cand_accept,cand_normal,cand_carry,cand_sem;
  logic [15:0] cand_lo;
  logic [135:0] cand_sem_bytes;

  // Rare background refresh of H+1 after a carry.
  typedef enum logic[1:0] {P_IDLE,P_L1,P_L2} pst_t;
  pst_t pst;
  logic [16:0] ph0_inc,ph1_inc;
  always_comb begin
    ph0_inc={1'b0,ph0}+17'd1;
    ph1_inc={1'b0,ph1}+17'd1;
  end

  integer i;
  (* keep *) logic [12:0] z0[0:16];
  (* keep *) logic [16:0] z1[0:16];
  (* keep *) logic [20:0] z2[0:16];

  always_ff @(posedge clk) begin
    if(rst) begin
      elo<=INIT_LO;
      eh0<=INIT_HI[15:0];eh1<=INIT_HI[31:16];eh2<=INIT_HI[47:32];
      ph0<=INIT_HIP1[15:0];ph1<=INIT_HIP1[31:16];ph2<=INIT_HIP1[47:32];
      cand_v<=0;cand_accept<=0;cand_normal<=0;cand_carry<=0;cand_sem<=0;
      cand_lo<=0;cand_sem_bytes<=0;
      accept_fast<=0;mismatch<=0;slow_required<=0;eos<=0;status<=0;pst<=P_IDLE;
      for(i=0;i<17;i=i+1) begin z0[i]<=0;z1[i]<=0;z2[i]<=0; end
    end else begin
      accept_fast<=0;
      eos<=0;
      slow_required<=0;

      // Commit previous packet candidate.
      if(cand_v) begin
        if(cand_accept) begin
          if(cand_normal) begin
            elo<=cand_lo;
            if(cand_carry) begin
              if(pst==P_IDLE) begin
                eh0<=ph0;eh1<=ph1;eh2<=ph2;
                // Begin background refresh: P := old P + 1.
                ph0<=ph0_inc[15:0];
                if(ph0_inc[16]) pst<=P_L1;
              end else begin
                // Cannot consume a second high carry before refresh completes.
                slow_required<=1;
              end
            end
          end
          if(cand_sem) begin
            for(i=0;i<17;i=i+1) begin
              z0[i]<=z0[i]+cand_sem_bytes[i*8 +:8];
              z1[i]<=z1[i]+z0[i];
              z2[i]<=z2[i]+z1[i];
            end
          end
        end
      end

      // Background high+1 refresh, rare and off common path.
      if(pst==P_L1) begin
        ph1<=ph1_inc[15:0];
        if(ph1_inc[16]) pst<=P_L2; else pst<=P_IDLE;
      end else if(pst==P_L2) begin
        ph2<=ph2+16'd1;
        pst<=P_IDLE;
      end

      // Capture this packet independently of later commit.
      cand_v<=pkt_valid;
      if(pkt_valid) begin
        mismatch<=~(session_ok & seq_eq);
        cand_accept<=session_ok & seq_eq;
        cand_normal<=(msg_count!=16'd0) && (msg_count!=16'hffff);
        cand_carry<=low_sum[16];
        cand_lo<=low_sum[15:0];
        cand_sem<=sem_valid;
        cand_sem_bytes<=semantic_bytes;

        if(session_ok & seq_eq) begin
          accept_fast<=1;
          if(msg_count==16'hffff) eos<=1;
          if((low_sum[16]) && (pst!=P_IDLE)) slow_required<=1;
        end else slow_required<=1;
      end

      status<=z2[0][0]^z2[8][7]^z2[16][13]^elo[0];
    end
  end
endmodule

// Protocol-faithful combinational decoder for a UDP-payload-aligned 512-bit first beat.
// Byte i is beat[511-8*i -: 8].
module mold_addorder_decode20(
 input logic [511:0] beat,
 output logic [79:0] session,
 output logic [63:0] seq,
 output logic [15:0] count,
 output logic [15:0] msg_len,
 output logic [7:0] msg_type,
 output logic [135:0] semantic,
 output logic one_addorder
);
 always_comb begin
   session=beat[511 -: 80];           // bytes 0..9
   seq=beat[431 -: 64];               // bytes 10..17
   count=beat[367 -: 16];             // bytes 18..19
   msg_len=beat[351 -: 16];           // bytes 20..21
   msg_type=beat[335 -: 8];           // byte 22
   semantic={
     beat[247 -: 64],                 // order reference bytes 33..40
     beat[183 -: 8],                  // side byte 41
     beat[175 -: 32],                 // shares bytes 42..45
     beat[79 -: 32]                   // price bytes 54..57
   };
   one_addorder=(count==16'd1)&&(msg_len==16'd36)&&(msg_type==8'h41);
 end
endmodule

module hft_mold_addorder20 #(
 parameter [79:0] SESSION=80'h54455354534553533031,
 parameter [47:0] INIT_HI=0,
 parameter [15:0] INIT_LO=0,
 parameter [47:0] INIT_HIP1=1
)(
 input logic clk,input logic rst,input logic beat_valid,input logic[511:0] beat,
 output logic accept_fast,output logic mismatch,output logic slow_required,output logic eos,output logic status
);
 logic[79:0] sess;logic[63:0] seq;logic[15:0] count,mlen;logic[7:0] typ;
 logic[135:0] sem;logic oneA;
 mold_addorder_decode20 d(.beat(beat),.session(sess),.seq(seq),.count(count),.msg_len(mlen),.msg_type(typ),.semantic(sem),.one_addorder(oneA));
 hft_fields20_bench #(.INIT_HI(INIT_HI),.INIT_LO(INIT_LO),.INIT_HIP1(INIT_HIP1)) c(
  .clk(clk),.rst(rst),.pkt_valid(beat_valid),.session_ok(sess==SESSION),
  .rx_seq(seq),.msg_count(count),.sem_valid(oneA),.semantic_bytes(sem),
  .accept_fast(accept_fast),.mismatch(mismatch),.slow_required(slow_required),.eos(eos),.status(status));
endmodule
