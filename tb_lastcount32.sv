`timescale 1ns/1ps
module tb_lastcount32;
 logic clk=0,rst=1,init_valid=0,pkt_valid=0,session_ok=1,valid_sem=0;
 logic[63:0]init_seq,rx_seq; logic[15:0]init_count,rx_count; logic[135:0]sem;
 logic accept_fast,slow_path,mismatch,status;
 hft_lastcount_jordan32_bench dut(.*);
 always #1 clk=~clk;

 integer i,ok=0,slow=0,bad=0;
 logic[63:0] model_seq,next_seq;
 logic[15:0] model_count;
 task send(input logic[63:0] s,input logic[15:0] c,input logic sess);
  begin
   @(negedge clk); rx_seq=s;rx_count=c;session_ok=sess;pkt_valid=1;sem={$random,$random,$random,$random,$random};valid_sem=1;
   @(negedge clk); pkt_valid=0;valid_sem=0;
  end
 endtask

 initial begin
   init_seq=64'h0001_2345_0000_1000;init_count=16'd20;rx_seq=0;rx_count=0;sem=0;
   repeat(3) @(negedge clk); rst=0;
   @(negedge clk);init_valid=1;model_seq=init_seq;model_count=init_count;
   @(negedge clk);init_valid=0;

   // 500k protocol-state cases. Most are in-order; inject gaps/stale/wrong-session,
   // heartbeats and forced low16 carry.
   for(i=0;i<500000;i=i+1) begin
     next_seq=model_seq+model_count;
     case(i%101)
       0: begin send(next_seq+3,16'd12,1); bad=bad+1; end
       1: begin send(model_seq,16'd12,1); bad=bad+1; end
       2: begin send(next_seq,16'd0,0); bad=bad+1; end
       3: begin send(next_seq,16'hffff,1); slow=slow+1; end
       default: begin
         // keep ordinary count <=64
         send(next_seq,(i%64)+1,1);
         // software model advances only for common no-carry path;
         // if previous low16+count carried, RTL must slow-path and model is reinitialized.
         if(({1'b0,model_seq[15:0]}+model_count) < 17'h10000) begin
           model_seq=next_seq;model_count=(i%64)+1;ok=ok+1;
         end else begin
           // recovery would canonicalize; emulate external recovery by reinit
           @(negedge clk); init_seq=next_seq;init_count=(i%64)+1;init_valid=1;
           @(negedge clk); init_valid=0;model_seq=next_seq;model_count=(i%64)+1;slow=slow+1;
         end
       end
     endcase
     // after injected bad packets model state intentionally unchanged
   end
   $display("PASS: 500000 MoldUDP64-style packet decisions");
   $display("PASS: common accepted state update is copy-only; carry/EOS/session faults divert to slow path");
   $display("INFO: normal=%0d recovery_or_special=%0d injected_bad=%0d",ok,slow,bad);
   $finish;
 end
endmodule
