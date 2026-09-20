`timescale 1ns/1ps
module tb_hft_real_v21;
  logic clk=0; always #5 clk=~clk;
  logic rst;

  // ---------- MoldUDP64 decoder ----------
  logic [511:0] beat;
  logic [79:0] dec_session;
  logic [63:0] dec_seq;
  logic [15:0] dec_count,dec_mlen;
  logic [7:0] dec_type;
  logic [135:0] dec_sem;
  logic dec_oneA;
  localparam [79:0] SESSION=80'h54455354534553533031; // "TESTSESS01"

  mold_addorder_decode21 dec(
    .beat(beat),.session(dec_session),.seq(dec_seq),.count(dec_count),
    .msg_len(dec_mlen),.msg_type(dec_type),.semantic(dec_sem),.one_addorder(dec_oneA));

  function automatic [511:0] make_addorder(
    input [79:0] sess,input [63:0] seq,input [15:0] count,
    input [63:0] orderref,input [7:0] side,input [31:0] shares,
    input [63:0] stock,input [31:0] price
  );
    reg [511:0] b;
    begin
      b='0;
      b[511 -:80]=sess;
      b[431 -:64]=seq;
      b[367 -:16]=count;
      b[351 -:16]=16'd36;
      b[335 -:8]=8'h41;       // 'A'
      b[327 -:16]=16'h1234;   // stock locate
      b[311 -:16]=16'h5678;   // tracking
      b[295 -:48]=48'h010203040506; // timestamp
      b[247 -:64]=orderref;
      b[183 -:8]=side;
      b[175 -:32]=shares;
      b[143 -:64]=stock;
      b[79 -:32]=price;
      make_addorder=b;
    end
  endfunction

  // ---------- Carry-hoisted sequence core ----------
  logic pkt_valid,session_ok;
  logic [63:0] rx_seq;
  logic [15:0] msg_count;
  logic accept_fast,mismatch,slow_required,eos;

  seq_hoist21_bench #(
    .INIT_HI(48'd0),.INIT_LO(16'hfffe),.INIT_HIP1(48'd1)
  ) sq(
    .clk(clk),.rst(rst),.pkt_valid(pkt_valid),.session_ok(session_ok),
    .rx_seq(rx_seq),.msg_count(msg_count),.accept_fast(accept_fast),
    .mismatch(mismatch),.slow_required(slow_required),.eos(eos));

  wire [63:0] dbg_expected={sq.eh2,sq.eh1,sq.eh0,sq.elo};

  task automatic send_seq(
    input [63:0] s,input [15:0] c,input logic sessok,
    input logic want_accept,input logic want_mismatch,input logic want_eos
  );
    begin
      @(negedge clk);
      rx_seq=s;msg_count=c;session_ok=sessok;pkt_valid=1;
      @(posedge clk); #1;
      if(accept_fast!==want_accept) begin
        $display("ACCEPT mismatch seq=%h count=%h got=%b want=%b",s,c,accept_fast,want_accept);
        $fatal(1);
      end
      if(mismatch!==want_mismatch) begin
        $display("MISMATCH flag wrong seq=%h count=%h got=%b want=%b",s,c,mismatch,want_mismatch);
        $fatal(1);
      end
      if(eos!==want_eos) begin
        $display("EOS flag wrong seq=%h count=%h got=%b want=%b",s,c,eos,want_eos);
        $fatal(1);
      end
      @(negedge clk); pkt_valid=0;
      // two idle cycles: candidate commit + rare preincrement refresh
      repeat(2) @(posedge clk);
      #1;
    end
  endtask

  // ---------- Packet-local two-message Jordan core ----------
  logic pf_start;
  logic [1:0] pf_count;
  logic [135:0] pf_x,pf_y;
  logic pf_overflow,pf_status;
  packetfence2_jordan21_bench pf(
    .clk(clk),.rst(rst),.pkt_start(pf_start),.valid_count(pf_count),
    .sem_x(pf_x),.sem_y(pf_y),.overflow(pf_overflow),.status(pf_status));

  longint unsigned rz0a,rz1a,rz2a,rz0b,rz1b,rz2b;
  longint unsigned oz0,oz1,oz2;
  integer k;
  integer xv,yv,xb,yb;
  longint unsigned ref_exp;
  integer cnt;
  integer errors;

  task automatic pf_two(input integer xa,input integer ya,input integer xb0,input integer yb0,input logic start);
    longint unsigned t0,t1,t2;
    begin
      @(negedge clk);
      pf_x='0;pf_y='0;
      pf_x[7:0]=xa[7:0];pf_y[7:0]=ya[7:0];
      pf_x[135:128]=xb0[7:0];pf_y[135:128]=yb0[7:0];
      pf_start=start;pf_count=2;

      // independent reference, using old states
      if(start) begin
        rz0a=xa+ya;rz1a=xa;rz2a=0;
        rz0b=xb0+yb0;rz1b=xb0;rz2b=0;
      end else begin
        t0=rz0a;t1=rz1a;t2=rz2a;
        rz0a=t0+xa+ya;rz1a=t1+2*t0+xa;rz2a=t2+2*t1+t0;
        t0=rz0b;t1=rz1b;t2=rz2b;
        rz0b=t0+xb0+yb0;rz1b=t1+2*t0+xb0;rz2b=t2+2*t1+t0;
      end

      @(posedge clk); #1;
      if(pf.z0[0]!==rz0a[13:0] || pf.z1[0]!==rz1a[18:0] || pf.z2[0]!==rz2a[23:0]) begin
        $display("PF lane0 mismatch k=%0d rtl=%0d,%0d,%0d ref=%0d,%0d,%0d",
          k,pf.z0[0],pf.z1[0],pf.z2[0],rz0a,rz1a,rz2a);
        $fatal(1);
      end
      if(pf.z0[16]!==rz0b[13:0] || pf.z1[16]!==rz1b[18:0] || pf.z2[16]!==rz2b[23:0]) begin
        $display("PF lane16 mismatch");
        $fatal(1);
      end
      @(negedge clk);pf_start=0;pf_count=0;
    end
  endtask

  initial begin
    errors=0;
    rst=1;pkt_valid=0;session_ok=1;rx_seq=0;msg_count=0;
    pf_start=0;pf_count=0;pf_x=0;pf_y=0;beat=0;
    repeat(3) @(posedge clk);
    @(negedge clk);rst=0;

    // Decoder: exact real-field offsets.
    beat=make_addorder(SESSION,64'h0123456789abcdef,16'd1,
      64'h1122334455667788,8'h42,32'd12345,64'h4142434445464748,32'd987654);
    #1;
    if(dec_session!==SESSION || dec_seq!==64'h0123456789abcdef || dec_count!==1 ||
       dec_mlen!==36 || dec_type!==8'h41 || !dec_oneA) begin
      $display("Mold decoder header failure");$fatal(1);
    end
    if(dec_sem!=={64'h1122334455667788,8'h42,32'd12345,32'd987654}) begin
      $display("Mold decoder semantic extraction failure got=%h",dec_sem);$fatal(1);
    end

    // Directed sequence semantics, including low-word carry.
    if(dbg_expected!==64'h000000000000fffe) $fatal(1);
    send_seq(64'h000000000000fffe,16'd1,1,1,0,0);
    if(dbg_expected!==64'h000000000000ffff) begin $display("expected1 %h",dbg_expected);$fatal(1);end

    send_seq(64'h000000000000ffff,16'd1,1,1,0,0);
    if(dbg_expected!==64'h0000000000010000) begin $display("carry failed %h",dbg_expected);$fatal(1);end

    // Heartbeat: valid exact sequence, no advance.
    send_seq(64'h0000000000010000,16'd0,1,1,0,0);
    if(dbg_expected!==64'h0000000000010000) $fatal(1);

    // Gap and duplicate/stale packet: no advance.
    send_seq(64'h0000000000010005,16'd1,1,0,1,0);
    if(dbg_expected!==64'h0000000000010000) $fatal(1);

    send_seq(64'h0000000000010000,16'd1,1,1,0,0);
    if(dbg_expected!==64'h0000000000010001) $fatal(1);

    send_seq(64'h0000000000010000,16'd1,1,0,1,0);
    if(dbg_expected!==64'h0000000000010001) $fatal(1);

    // Wrong session.
    send_seq(64'h0000000000010001,16'd1,0,0,1,0);
    if(dbg_expected!==64'h0000000000010001) $fatal(1);

    // End of session marker: exact sequence but not fast data accept and no +65535.
    send_seq(64'h0000000000010001,16'hffff,1,0,0,1);
    if(dbg_expected!==64'h0000000000010001) $fatal(1);

    // Random accepted packets and heartbeats.
    ref_exp=64'h0000000000010001;
    for(k=0;k<5000;k=k+1) begin
      if((k%97)==0) cnt=0; else cnt=$urandom_range(1,200);
      send_seq(ref_exp,cnt[15:0],1,1,0,0);
      if(cnt!=0) ref_exp=ref_exp+cnt;
      if(dbg_expected!==ref_exp[63:0]) begin
        $display("random expected mismatch k=%0d rtl=%h ref=%h",k,dbg_expected,ref_exp);
        $fatal(1);
      end
    end

    // PacketFence: 64 messages, two per cycle, checked every update.
    rz0a=0;rz1a=0;rz2a=0;rz0b=0;rz1b=0;rz2b=0;
    for(k=0;k<32;k=k+1) begin
      xv=$urandom_range(0,255); yv=$urandom_range(0,255);
      xb=$urandom_range(0,255); yb=$urandom_range(0,255);
      pf_two(xv,yv,xb,yb,(k==0));
    end
    if(pf_overflow) begin $display("overflow too early");$fatal(1);end

    // 65th message must signal bound overflow without silently wrapping.
    @(negedge clk);pf_x='0;pf_x[7:0]=8'h7f;pf_y=0;pf_count=1;pf_start=0;
    @(posedge clk);#1;
    if(!pf_overflow) begin $display("missing packetfence overflow");$fatal(1);end
    @(negedge clk);pf_count=0;

    $display("PASS: MoldUDP64 decode + carry-hoisted sequence + 2-message Jordan PacketFence");
    $display("PASS: 5000 randomized sequence packets, heartbeat/gap/duplicate/session/EOS/carry cases");
    $display("PASS: exact 64-message packet-local Jordan bound and overflow detection");
    $finish;
  end
endmodule
