`timescale 1ns/1ps
module tb_exact35;
 logic clk=0,rst=1,init_valid=0,seq_hi_valid=0,seq_lo_valid=0,count_valid=0,session_ok=1,valid_sem=0;
 logic[63:0]init_expected_seq;logic[15:0]rx_count;logic[31:0]seq_hi,seq_lo;logic[135:0]semantic_bytes;
 logic accept_fast,slow_path,mismatch,status;
 hft_exact35_jordan_bench dut(.*);
 always #1 clk=~clk;

 integer i,accepted=0,bad=0,special=0,carry_rec=0;
 logic[63:0] expected;logic[16:0] nextsum;

 task initialize(input logic[63:0] e);
  begin
   @(negedge clk);init_expected_seq=e;init_valid=1;
   @(negedge clk);init_valid=0;expected=e;
  end
 endtask

 task packet(input logic[63:0] s,input logic[15:0] c,input logic sess,
             input logic ea,input logic es,input logic em);
  begin
   @(negedge clk);seq_hi=s[63:32];session_ok=sess;seq_hi_valid=1;
   @(negedge clk);seq_hi_valid=0;seq_lo=s[31:0];seq_lo_valid=1;
   semantic_bytes={$random,$random,$random,$random,$random};valid_sem=1;
   @(negedge clk);seq_lo_valid=0;valid_sem=0;rx_count=c;count_valid=1;
   @(negedge clk);#0.01;
   if(accept_fast!==ea || slow_path!==es || mismatch!==em) begin
    $display("FAIL i=%0d s=%h c=%h got=%0d/%0d/%0d exp=%0d/%0d/%0d",
      i,s,c,accept_fast,slow_path,mismatch,ea,es,em);$fatal(1);
   end
   count_valid=0;
   @(negedge clk);#0.01;
   if(accept_fast||slow_path||mismatch) begin $display("FAIL pulse clear i=%0d",i);$fatal(1);end
  end
 endtask

 initial begin
  init_expected_seq=64'h1234_5678_0000_1000;seq_hi=0;seq_lo=0;rx_count=0;semantic_bytes=0;
  repeat(3)@(negedge clk);rst=0;initialize(init_expected_seq);

  for(i=0;i<500000;i=i+1) begin
   case(i%131)
    0: begin packet(expected+7,12,1,0,1,1);bad=bad+1;end
    1: begin packet(expected-1,12,1,0,1,1);bad=bad+1;end
    2: begin packet(expected,12,0,0,1,0);bad=bad+1;end
    3: begin packet(expected,16'hffff,1,0,1,0);special=special+1;end
    default: begin
      logic[15:0] nc;nc=(i%64)+1;
      nextsum={1'b0,expected[15:0]}+nc;
      packet(expected,nc,1,1,0,0);accepted=accepted+1;
      if(!nextsum[16]) expected=expected+nc;
      else begin
        // packet itself was correct; its successor requires exact recovery due carry.
        expected=expected+nc;
        // Next packet must divert because fast_ready was cleared.
        packet(expected,7,1,0,1,0);carry_rec=carry_rec+1;
        // recovery installs canonical next expected (the diverted packet's successor).
        initialize(expected+7); expected=expected+7;
      end
    end
   endcase
  end

  // Explicit corruption in every 16-bit chunk: none may fast-accept.
  initialize(64'h1111_2222_3333_4444);
  packet(64'h1110_2222_3333_4444,1,1,0,1,1);
  packet(64'h1111_2223_3333_4444,1,1,0,1,1);
  packet(64'h1111_2222_3332_4444,1,1,0,1,1);
  packet(64'h1111_2222_3333_4445,1,1,0,1,1);

  $display("PASS: 500000 self-checked exact 64-bit chunked sequence decisions");
  $display("PASS: faults in each 16-bit chunk rejected; carry transitions divert exactly");
  $display("INFO accepted=%0d bad=%0d special=%0d carry_recovery=%0d",accepted,bad,special,carry_rec);
  $finish;
 end
endmodule
