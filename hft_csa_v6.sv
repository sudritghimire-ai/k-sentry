// HFT fast-path v6: carry-save Jordan PacketFence.
// Exact redundant representation: value = sum + (carry << 1).
// No carry-propagate addition in z1/z2 hot updates.

module seq32_pair_fast6(
  input logic clk,input logic rst,input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,
  input logic seq_valid,output logic accept_fast,output logic mismatch
);
  logic phase, first_bad, neq;
  always_comb neq=(rx_chunk!=exp_chunk);
  always_ff @(posedge clk) begin
    if(rst) begin phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0; end
    else begin
      accept_fast<=0;
      if(seq_valid) begin
        if(!phase) begin first_bad<=neq;mismatch<=neq;phase<=1; end
        else begin mismatch<=first_bad|neq;accept_fast<=!(first_bad|neq);phase<=0; end
      end
    end
  end
endmodule

module packetfence_csa_lane(
  input logic clk,input logic rst,input logic valid,input logic[7:0] x,
  output logic[12:0] z0,
  output logic[17:0] s1,output logic[17:0] c1,
  output logic[21:0] s2,output logic[21:0] c2
);
  logic[12:0] z0n;
  logic[17:0] a1,b1,d1,s1n,c1n;
  logic[21:0] a20,b20,d20,tS,tC,a21,b21,d21,s2n,c2n;
  always_comb begin
    z0n = z0 + x;
    a1=s1; b1={c1[16:0],1'b0}; d1={{5{1'b0}},z0};
    s1n=a1^b1^d1;
    c1n=(a1&b1)|(a1&d1)|(b1&d1);

    a20=s2; b20={c2[20:0],1'b0}; d20={{4{1'b0}},s1};
    tS=a20^b20^d20;
    tC=(a20&b20)|(a20&d20)|(b20&d20);
    a21=tS; b21={tC[20:0],1'b0}; d21={{3{1'b0}},c1,1'b0};
    s2n=a21^b21^d21;
    c2n=(a21&b21)|(a21&d21)|(b21&d21);
  end
  always_ff @(posedge clk) begin
    if(rst) begin z0<='0;s1<='0;c1<='0;s2<='0;c2<='0; end
    else if(valid) begin z0<=z0n;s1<=s1n;c1<=c1n;s2<=s2n;c2<=c2n; end
  end
endmodule

module packetfence17_csa_bench(
 input logic clk,input logic rst,input logic valid,input logic[135:0] semantic_bytes,
 output logic[21:0] witness_s,output logic[21:0] witness_c
);
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[17:0] s1,c1;logic[21:0] s2,c2;
   packetfence_csa_lane p(.clk(clk),.rst(rst),.valid(valid),.x(semantic_bytes[i*8 +:8]),
    .z0(z0),.s1(s1),.c1(c1),.s2(s2),.c2(c2));
   if(i==0) begin assign witness_s=s2; assign witness_c=c2; end
 end endgenerate
endmodule

module hft_pair_csa_merged_bench(
 input logic clk,input logic rst,input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,input logic seq_valid,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic[21:0] witness_s,output logic[21:0] witness_c
);
 seq32_pair_fast6 q(.clk(clk),.rst(rst),.rx_chunk(rx_chunk),.exp_chunk(exp_chunk),.seq_valid(seq_valid),.accept_fast(accept_fast),.mismatch(mismatch));
 packetfence17_csa_bench p(.clk(clk),.rst(rst),.valid(valid_sem),.semantic_bytes(semantic_bytes),.witness_s(witness_s),.witness_c(witness_c));
endmodule
