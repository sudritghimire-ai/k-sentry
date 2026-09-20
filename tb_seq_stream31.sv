`timescale 1ns/1ps
module tb_seq_stream31;
 logic clk=0; always #1 clk=~clk;
 logic rst,hi_v,lo_v,session_ok,recover_valid;
 logic[31:0] rx_hi,rx_lo;
 logic[15:0] count;
 logic[63:0] recover_seq;
 logic accept_fast,mismatch,slow_required,eos,semantic_fast_ok;
 seq_stream31_bench dut(.clk(clk),.rst(rst),.seq_hi_valid(hi_v),.rx_hi32(rx_hi),
  .seq_lo_valid(lo_v),.rx_lo32(rx_lo),.session_ok(session_ok),.msg_count(count),
  .recover_valid(recover_valid),.recover_seq(recover_seq),.accept_fast(accept_fast),
  .mismatch(mismatch),.slow_required(slow_required),.eos(eos),.semantic_fast_ok(semantic_fast_ok));
 wire[63:0] expected={dut.e3,dut.e2,dut.e1,dut.e0};
 longint unsigned refexp;
 integer i,c,kind;
 task automatic send(input [63:0] seq,input[15:0] cnt,input logic sess,
  input logic wa,input logic wm,input logic ws,input logic we);
  reg[63:0] before;
  begin
   before=expected;
   @(negedge clk); hi_v=1;lo_v=0;rx_hi=seq[63:32];session_ok=sess;count=cnt;
   @(posedge clk);#0.1;
   @(negedge clk); hi_v=0;lo_v=1;rx_lo=seq[31:0];session_ok=sess;count=cnt;
   @(posedge clk);#0.1;
   @(negedge clk); lo_v=0;
   @(posedge clk);#0.1;
   if(accept_fast!==wa||mismatch!==wm||slow_required!==ws||eos!==we) begin
    $display("FLAG FAIL i=%0d seq=%h cnt=%h got=%b%b%b%b want=%b%b%b%b",i,seq,cnt,
      accept_fast,mismatch,slow_required,eos,wa,wm,ws,we);$fatal(1);
   end
   // One idle cycle must not replay result.
   @(posedge clk);#0.1;
   if(accept_fast||slow_required||eos) begin
    $display("STALE RESULT REPLAY i=%0d a/s/e=%b%b%b",i,accept_fast,slow_required,eos);$fatal(1);
   end
   if(!wa && expected!==before) begin
    $display("REJECT ADVANCED STATE i=%0d before=%h after=%h",i,before,expected);$fatal(1);
   end
  end
 endtask

 initial begin
  rst=1;hi_v=0;lo_v=0;session_ok=1;count=0;recover_valid=0;recover_seq=0;rx_hi=0;rx_lo=0;
  repeat(3)@(posedge clk);@(negedge clk);rst=0;refexp=0;

  for(i=0;i<100000;i=i+1) begin
   kind=i%25;
   if(kind==0) send(refexp,0,1,1,0,0,0);
   else if(kind==1) send(refexp+9,1,1,0,1,1,0);
   else if(kind==2) send(refexp-1,1,1,0,1,1,0);
   else if(kind==3) send(refexp,1,0,0,1,1,0);
   else if(kind==4) send(refexp,16'hffff,1,0,0,0,1);
   else begin
    c=((i*31)%500)+1;
    // If the normal low-word add would carry, v31 deliberately diverts to slow path.
    if(({1'b0,refexp[15:0]}+c)>17'h0ffff) begin
      send(refexp,c[15:0],1,0,0,1,0);
      // emulate recovery engine applying canonical seq+count
      @(negedge clk);recover_seq=refexp+c;recover_valid=1;
      @(posedge clk);#0.1;@(negedge clk);recover_valid=0;
      refexp=refexp+c;
    end else begin
      send(refexp,c[15:0],1,1,0,0,0);
      refexp=refexp+c;
    end
    if(expected!==refexp[63:0]) begin $display("MODEL FAIL i=%0d rtl=%h ref=%h",i,expected,refexp);$fatal(1);end
   end
  end
  $display("PASS: 100000 streamed two-beat sequence decisions");
  $display("PASS: no stale decision replay; mismatches never advance hot state");
  $display("PASS: low16 carry always diverted to recovery and canonical state restored");
  $finish;
 end
endmodule
