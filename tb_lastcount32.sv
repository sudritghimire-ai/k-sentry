`timescale 1ns/1ps
module tb_lastcount32;
  logic clk=0,rst=1,init_valid=0,pkt_valid=0,session_ok=1,valid_sem=0;
  logic[63:0] init_seq,rx_seq;
  logic[15:0] init_count,rx_count;
  logic[135:0] semantic_bytes;
  logic accept_fast,slow_path,mismatch,status;

  hft_lastcount_jordan32_bench dut(
    .clk(clk),.rst(rst),
    .init_valid(init_valid),.init_seq(init_seq),.init_count(init_count),
    .pkt_valid(pkt_valid),.rx_seq(rx_seq),.rx_count(rx_count),.session_ok(session_ok),
    .valid_sem(valid_sem),.semantic_bytes(semantic_bytes),
    .accept_fast(accept_fast),.slow_path(slow_path),.mismatch(mismatch),.status(status)
  );

  always #1 clk=~clk;

  integer i;
  integer pass_accept=0, pass_slow=0, pass_bad=0, carry_recov=0;
  logic[63:0] model_seq;
  logic[15:0] model_count;
  logic[16:0] model_low_sum;

  task do_init(input logic[63:0] s,input logic[15:0] c);
    begin
      @(negedge clk);
      init_seq=s; init_count=c; init_valid=1;
      @(negedge clk);
      init_valid=0;
      model_seq=s; model_count=c;
    end
  endtask

  task send_check(
    input logic[63:0] s,
    input logic[15:0] c,
    input logic sess,
    input logic exp_accept,
    input logic exp_slow,
    input logic exp_mismatch
  );
    begin
      @(negedge clk);
      rx_seq=s; rx_count=c; session_ok=sess; pkt_valid=1;
      semantic_bytes={$random,$random,$random,$random,$random};
      valid_sem=1;
      @(negedge clk);
      #0.01;
      if(accept_fast!==exp_accept || slow_path!==exp_slow || mismatch!==exp_mismatch) begin
        $display("FAIL decision i=%0d s=%h c=%h sess=%0d got A/S/M=%0d/%0d/%0d exp=%0d/%0d/%0d",
          i,s,c,sess,accept_fast,slow_path,mismatch,exp_accept,exp_slow,exp_mismatch);
        $fatal(1);
      end
      pkt_valid=0; valid_sem=0;
      @(negedge clk);
      #0.01;
      if(accept_fast!==1'b0 || slow_path!==1'b0 || mismatch!==1'b0) begin
        $display("FAIL pulse did not clear i=%0d",i);
        $fatal(1);
      end
    end
  endtask

  initial begin
    init_seq=64'h0001_2345_0000_1000;
    init_count=16'd20;
    rx_seq=0; rx_count=0; semantic_bytes=0;

    repeat(3) @(negedge clk);
    rst=0;
    do_init(init_seq,init_count);

    // 500k protocol-state decisions with deterministic adversarial injections.
    for(i=0;i<500000;i=i+1) begin
      model_low_sum={1'b0,model_seq[15:0]}+{1'b0,model_count};

      case(i%127)
        0: begin // positive gap
          send_check(model_seq+model_count+64'd3,16'd12,1,0,1,~model_low_sum[16]);
          pass_bad=pass_bad+1;
        end
        1: begin // stale/duplicate
          send_check(model_seq,16'd12,1,0,1,~model_low_sum[16]);
          pass_bad=pass_bad+1;
        end
        2: begin // wrong session
          send_check(model_seq+model_count,16'd12,0,0,1,0);
          pass_bad=pass_bad+1;
        end
        3: begin // EOS is always control/slow path
          send_check(model_seq+model_count,16'hffff,1,0,1,0);
          pass_slow=pass_slow+1;
        end
        4: begin // heartbeat: count 0; legal if sequence is expected
          if(!model_low_sum[16]) begin
            send_check(model_seq+model_count,16'd0,1,1,0,0);
            model_seq=model_seq+model_count; model_count=0;
            pass_accept=pass_accept+1;
          end else begin
            send_check(model_seq+model_count,16'd0,1,0,1,0);
            do_init(model_seq+model_count,0);
            carry_recov=carry_recov+1;
          end
        end
        default: begin
          if(!model_low_sum[16]) begin
            logic[15:0] nc;
            nc=(i%64)+1;
            send_check(model_seq+model_count,nc,1,1,0,0);
            model_seq=model_seq+model_count;
            model_count=nc;
            pass_accept=pass_accept+1;
          end else begin
            logic[15:0] nc;
            nc=(i%64)+1;
            send_check(model_seq+model_count,nc,1,0,1,0);
            // emulate exact external recovery after the deliberate fast-path carry diversion
            do_init(model_seq+model_count,nc);
            carry_recov=carry_recov+1;
          end
        end
      endcase
    end

    // Force a carry boundary explicitly.
    do_init(64'h0000_0000_1234_fff0,16'd32);
    send_check(64'h0000_0000_1235_0010,16'd7,1,0,1,0);
    carry_recov=carry_recov+1;

    // Verify recovery then succeeds on the same canonical packet/state.
    do_init(64'h0000_0000_1235_0010,16'd7);
    send_check(64'h0000_0000_1235_0017,16'd9,1,1,0,0);
    pass_accept=pass_accept+1;

    $display("PASS: 500000 self-checked MoldUDP64-style decisions");
    $display("PASS: bad/session/EOS/carry cases diverted without accidental fast accept");
    $display("PASS: heartbeat and recovery behavior verified");
    $display("INFO accepted=%0d injected_bad=%0d slow_special=%0d carry_recovery=%0d",
      pass_accept,pass_bad,pass_slow,carry_recov);
    $finish;
  end
endmodule
