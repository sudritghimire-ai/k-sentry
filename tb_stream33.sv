`timescale 1ns/1ps
module tb_stream33;
 logic clk=0,rst=1,init_valid=0,seq_hi_valid=0,seq_lo_valid=0,count_valid=0,session_ok=1,valid_sem=0;
 logic[63:0]init_seq;logic[15:0]init_count,rx_count;logic[31:0]seq_hi,seq_lo;logic[135:0]semantic_bytes;
 logic accept_fast,slow_path,mismatch,status;
 hft_stream_lastcount_jordan33_bench dut(.*);
 always #1 clk=~clk;

 integer i,accepted=0,bad=0,special=0,carry_rec=0;
 logic[63:0] model_seq,next_seq;logic[15:0] model_count;logic[16:0] lsum;

 task initialize(input logic[63:0] s,input logic[15:0] c);
  begin
   @(negedge clk);init_seq=s;init_count=c;init_valid=1;
   @(negedge clk);init_valid=0;model_seq=s;model_count=c;
  end
 endtask

 task packet(
  input logic[63:0] s,input logic[15:0] c,input logic sess,
  input logic ea,input logic es,input logic em
 );
  begin
   @(negedge clk);seq_hi=s[63:32];session_ok=sess;seq_hi_valid=1;
   @(negedge clk);seq_hi_valid=0;seq_lo=s[31:0];seq_lo_valid=1;
   semantic_bytes={$random,$random,$random,$random,$random};valid_sem=1;
   @(negedge clk);seq_lo_valid=0;valid_sem=0;rx_count=c;count_valid=1;
   @(negedge clk);#0.01;
   if(accept_fast!==ea || slow_path!==es || mismatch!==em) begin
    $display("FAIL i=%0d seq=%h count=%h sess=%0d got=%0d/%0d/%0d exp=%0d/%0d/%0d",
      i,s,c,sess,accept_fast,slow_path,mismatch,ea,es,em);
    $fatal(1);
   end
   count_valid=0;
   @(negedge clk);#0.01;
   if(accept_fast||slow_path||mismatch) begin $display("FAIL pulse clear i=%0d",i);$fatal(1);end
  end
 endtask

 initial begin
  init_seq=64'h1234_5678_0000_1000;init_count=20;seq_hi=0;seq_lo=0;rx_count=0;semantic_bytes=0;
  repeat(3)@(negedge clk);rst=0;initialize(init_seq,init_count);

  for(i=0;i<500000;i=i+1) begin
   next_seq=model_seq+model_count;
   lsum={1'b0,model_seq[15:0]}+model_count;
   case(i%131)
    0: begin packet(next_seq+7,12,1,0,1,!lsum[16]);bad=bad+1;end
    1: begin packet(model_seq,12,1,0,1,!lsum[16]);bad=bad+1;end
    2: begin packet(next_seq,12,0,0,1,0);bad=bad+1;end
    3: begin packet(next_seq,16'hffff,1,0,1,0);special=special+1;end
    4: begin
      if(!lsum[16]) begin
        packet(next_seq,0,1,1,0,0);model_seq=next_seq;model_count=0;accepted=accepted+1;
      end else begin
        packet(next_seq,0,1,0,1,0);initialize(next_seq,0);carry_rec=carry_rec+1;
      end
    end
    default: begin
      logic[15:0] nc;nc=(i%64)+1;
      if(!lsum[16]) begin
        packet(next_seq,nc,1,1,0,0);model_seq=next_seq;model_count=nc;accepted=accepted+1;
      end else begin
        packet(next_seq,nc,1,0,1,0);initialize(next_seq,nc);carry_rec=carry_rec+1;
      end
    end
   endcase
  end

  initialize(64'h0000_0001_1234_fff8,16'd16);
  packet(64'h0000_0001_1235_0008,9,1,0,1,0);carry_rec=carry_rec+1;
  initialize(64'h0000_0001_1235_0008,9);
  packet(64'h0000_0001_1235_0011,11,1,1,0,0);accepted=accepted+1;

  $display("PASS: 500000 self-checked streamed MoldUDP64 decisions");
  $display("PASS: sequence high/low/count pipeline; copy-only accepted state");
  $display("PASS: gap/stale/session/EOS/carry/heartbeat/recovery cases");
  $display("INFO accepted=%0d bad=%0d special=%0d carry_recovery=%0d",accepted,bad,special,carry_rec);
  $finish;
 end
endmodule
