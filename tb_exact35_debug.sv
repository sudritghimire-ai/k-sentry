`timescale 1ns/1ps
module tb_exact35_debug;
 logic clk=0,rst=1,init_valid=0,seq_hi_valid=0,seq_lo_valid=0,count_valid=0,session_ok=1,valid_sem=0;
 logic[63:0]init_expected_seq;logic[15:0]rx_count;logic[31:0]seq_hi,seq_lo;logic[135:0]semantic_bytes;
 logic accept_fast,slow_path,mismatch,status;
 hft_exact35_jordan_bench dut(.*);
 always #1 clk=~clk;
 integer i;
 logic[63:0] expected;logic[16:0] nextsum;

 task check_state(input string where);
   logic[63:0] rtl_expected;
   begin
    rtl_expected={dut.q.e3,dut.q.e2,dut.q.e1,dut.q.e0};
    if(dut.q.fast_ready && rtl_expected!==expected) begin
      $display("STATE_DIVERGE i=%0d where=%s model=%h rtl=%h fast_ready=%0d seq_ok=%0d hi_bad=%0d",
        i,where,expected,rtl_expected,dut.q.fast_ready,dut.q.seq_ok,dut.q.hi_bad);
      $fatal(1);
    end
   end
 endtask

 task initialize(input logic[63:0] e);
  begin
   @(negedge clk);init_expected_seq=e;init_valid=1;
   @(negedge clk);init_valid=0;expected=e;
   #0.01; check_state("init");
  end
 endtask

 task packet(input logic[63:0] s,input logic[15:0] c,input logic sess,
             input logic ea,input logic es,input logic em);
  begin
   if(i>=1935) $display("PRE i=%0d model=%h rtl=%h fr=%0d send=%h c=%0d",
      i,expected,{dut.q.e3,dut.q.e2,dut.q.e1,dut.q.e0},dut.q.fast_ready,s,c);
   @(negedge clk);seq_hi=s[63:32];session_ok=sess;seq_hi_valid=1;
   @(negedge clk);seq_hi_valid=0;seq_lo=s[31:0];seq_lo_valid=1;
   semantic_bytes=0;valid_sem=1;
   @(negedge clk);seq_lo_valid=0;valid_sem=0;rx_count=c;count_valid=1;
   @(negedge clk);#0.01;
   if(i>=1935) $display("POST i=%0d A/S/M=%0d/%0d/%0d rtl=%h fr=%0d low_sum=%h",
      i,accept_fast,slow_path,mismatch,{dut.q.e3,dut.q.e2,dut.q.e1,dut.q.e0},dut.q.fast_ready,dut.q.next_low_sum);
   if(accept_fast!==ea || slow_path!==es || mismatch!==em) begin
    $display("DECISION_FAIL i=%0d model=%h rtl=%h send=%h c=%h got=%0d/%0d/%0d exp=%0d/%0d/%0d",
      i,expected,{dut.q.e3,dut.q.e2,dut.q.e1,dut.q.e0},s,c,accept_fast,slow_path,mismatch,ea,es,em);
    $fatal(1);
   end
   count_valid=0;
   @(negedge clk);
  end
 endtask

 initial begin
  init_expected_seq=64'h1234_5678_0000_1000;seq_hi=0;seq_lo=0;rx_count=0;semantic_bytes=0;
  repeat(3)@(negedge clk);rst=0;initialize(init_expected_seq);
  for(i=0;i<1970;i=i+1) begin
   case(i%131)
    0: packet(expected+7,12,1,0,1,1);
    1: packet(expected-1,12,1,0,1,1);
    2: packet(expected,12,0,0,1,0);
    3: packet(expected,16'hffff,1,0,1,0);
    default: begin
      logic[15:0] nc; nc=(i%64)+1;
      nextsum={1'b0,expected[15:0]}+nc;
      packet(expected,nc,1,1,0,0);
      if(!nextsum[16]) begin expected=expected+nc; #0.01; check_state("accepted"); end
      else begin
        expected=expected+nc;
        packet(expected,7,1,0,1,0);
        initialize(expected+7); expected=expected+7;
      end
    end
   endcase
  end
  $display("DEBUG PASS");
  $finish;
 end
endmodule
