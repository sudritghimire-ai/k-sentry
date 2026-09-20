`timescale 1ns/1ps
module tb_hft_stress_v21;
  logic clk=0; always #1 clk=~clk;
  logic rst;

  // Sequence DUT
  logic pkt_valid,session_ok;
  logic [63:0] rx_seq;
  logic [15:0] msg_count;
  logic accept_fast,mismatch,slow_required,eos;
  seq_hoist21_bench #(.INIT_HI(48'd0),.INIT_LO(16'd0),.INIT_HIP1(48'd1)) sq(
    .clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),
    .rx_seq(rx_seq),.msg_count(msg_count),.accept_fast(accept_fast),
    .mismatch(mismatch),.slow_required(slow_required),.eos(eos));
  wire [63:0] expected={sq.eh2,sq.eh1,sq.eh0,sq.elo};

  // Two semantic cores: clean and corrupted
  logic a_start,b_start;
  logic [1:0] a_cnt,b_cnt;
  logic [135:0] ax,ay,bx,by;
  logic a_ov,b_ov,a_status,b_status;
  packetfence2_jordan21_bench pa(.clk(clk),.rst(rst),.pkt_start(a_start),.valid_count(a_cnt),
    .sem_x(ax),.sem_y(ay),.overflow(a_ov),.status(a_status));
  packetfence2_jordan21_bench pb(.clk(clk),.rst(rst),.pkt_start(b_start),.valid_count(b_cnt),
    .sem_x(bx),.sem_y(by),.overflow(b_ov),.status(b_status));

  integer i,j,k,t,errors;
  longint unsigned ref_expected;
  integer c,kind,pos1,pos2,pos3,swap_pos;
  logic [135:0] msgsA[0:63];
  logic [135:0] msgsB[0:63];
  logic [31:0] rnd;

  task automatic idle2;
    begin
      @(negedge clk); pkt_valid=0;
      repeat(2) @(posedge clk);
      #0.1;
    end
  endtask

  task automatic seq_case(input [63:0] s,input [15:0] cnt,input logic sess,
                          input logic want_accept,input logic want_mis,input logic want_eos);
    reg [63:0] prev_expected;
    begin
      prev_expected=expected;
      @(negedge clk);
      rx_seq=s; msg_count=cnt; session_ok=sess; pkt_valid=1;
      @(posedge clk); #0.1;
      if(accept_fast!==want_accept || mismatch!==want_mis || eos!==want_eos) begin
        $display("SEQ FLAG FAIL i=%0d seq=%h cnt=%h got a/m/e=%b%b%b want=%b%b%b",
          i,s,cnt,accept_fast,mismatch,eos,want_accept,want_mis,want_eos);
        $fatal(1);
      end
      idle2();
      if(!want_accept && expected!==prev_expected) begin
        $display("REJECT ADVANCED STATE before=%h after=%h",prev_expected,expected);
        $fatal(1);
      end
    end
  endtask

  function automatic [135:0] mkmsg(input integer packet,input integer idx,input integer salt);
    reg [135:0] v;
    integer q;
    begin
      v='0;
      for(q=0;q<17;q=q+1)
        v[q*8 +: 8] = (packet*73 + idx*29 + q*17 + salt*11 + (packet>>3) + (idx*q)) & 8'hff;
      mkmsg=v;
    end
  endfunction

  task automatic run_sem_packet(input integer packet_id,input integer fault_kind);
    integer pair;
    begin
      for(j=0;j<64;j=j+1) begin
        msgsA[j]=mkmsg(packet_id,j,0);
        msgsB[j]=msgsA[j];
      end

      // Deterministic nontrivial fault locations.
      pos1=(packet_id*7+3)%64;
      pos2=(packet_id*11+19)%64; if(pos2==pos1) pos2=(pos2+1)%64;
      pos3=(packet_id*13+37)%64; if(pos3==pos1||pos3==pos2) pos3=(pos3+2)%64;
      swap_pos=(packet_id*5+9)%63;

      case(fault_kind)
        1: msgsB[pos1][7:0] ^= 8'h01;                              // 1 substitution
        2: begin msgsB[pos1][7:0] ^= 8'h03; msgsB[pos2][15:8] ^= 8'h05; end
        3: begin msgsB[pos1][7:0] ^= 8'h03; msgsB[pos2][15:8] ^= 8'h05;
                 msgsB[pos3][23:16] ^= 8'h09; end
        4: begin // adjacent transposition; force distinct if necessary
             if(msgsB[swap_pos]===msgsB[swap_pos+1]) msgsB[swap_pos][7:0]^=8'h80;
             bx=msgsB[swap_pos]; msgsB[swap_pos]=msgsB[swap_pos+1]; msgsB[swap_pos+1]=bx;
           end
        default: ;
      endcase

      for(pair=0;pair<32;pair=pair+1) begin
        @(negedge clk);
        a_start=(pair==0); b_start=(pair==0);
        a_cnt=2; b_cnt=2;
        ax=msgsA[2*pair]; ay=msgsA[2*pair+1];
        bx=msgsB[2*pair]; by=msgsB[2*pair+1];
        @(posedge clk); #0.1;
      end
      @(negedge clk); a_start=0;b_start=0;a_cnt=0;b_cnt=0;
      @(posedge clk); #0.1;

      if(a_ov||b_ov) begin $display("Unexpected semantic overflow");$fatal(1); end

      // Full-state comparison over all 17 lanes, not status bit.
      if(fault_kind==0) begin
        for(j=0;j<17;j=j+1)
          if(pa.z0[j]!==pb.z0[j] || pa.z1[j]!==pb.z1[j] || pa.z2[j]!==pb.z2[j]) begin
            $display("IDENTICAL packet diverged id=%0d lane=%0d",packet_id,j);$fatal(1);
          end
      end else begin
        t=0;
        for(j=0;j<17;j=j+1)
          if(pa.z0[j]!==pb.z0[j] || pa.z1[j]!==pb.z1[j] || pa.z2[j]!==pb.z2[j]) t=1;
        if(!t) begin
          $display("SEMANTIC COLLISION packet=%0d kind=%0d",packet_id,fault_kind);
          $fatal(1);
        end
      end
    end
  endtask

  initial begin
    rst=1;pkt_valid=0;session_ok=1;rx_seq=0;msg_count=0;
    a_start=0;b_start=0;a_cnt=0;b_cnt=0;ax=0;ay=0;bx=0;by=0;
    repeat(4) @(posedge clk); @(negedge clk);rst=0; #0.1;
    ref_expected=0;

    // 200k protocol decisions. ~80% valid, rest deliberate faults/heartbeats.
    for(i=0;i<200000;i=i+1) begin
      kind=i%20;
      if(kind==0) begin // heartbeat
        seq_case(ref_expected,16'd0,1,1,0,0);
      end else if(kind==1) begin // gap
        seq_case(ref_expected+64'd7,16'd1,1,0,1,0);
      end else if(kind==2) begin // stale/duplicate
        seq_case(ref_expected-64'd1,16'd1,1,0,1,0);
      end else if(kind==3) begin // wrong session
        seq_case(ref_expected,16'd1,0,0,1,0);
      end else if(kind==4) begin // EOS
        seq_case(ref_expected,16'hffff,1,0,0,1);
      end else begin
        c=((i*37) % 250)+1;
        seq_case(ref_expected,c[15:0],1,1,0,0);
        ref_expected=ref_expected+c;
        if(expected!==ref_expected[63:0]) begin
          $display("SEQ MODEL FAIL i=%0d rtl=%h ref=%h",i,expected,ref_expected);$fatal(1);
        end
      end
    end

    // 20k packet semantic differential campaign: 4k of each class.
    for(k=0;k<20000;k=k+1) run_sem_packet(k,k%5);

    $display("PASS: 200000 MoldUDP64 sequence/session/count decisions vs independent model");
    $display("PASS: rejected gap/stale/wrong-session/EOS packets never advanced expected sequence");
    $display("PASS: 20000 x 64-message semantic packets compared by full 17-lane certificate");
    $display("PASS: zero collisions in 4000 each of 1-sub, 2-sub, 3-sub, adjacent-swap campaigns");
    $finish;
  end
endmodule
