// HFT fast-path v7: carry-select Jordan PacketFence.

module add13_csel(input logic[12:0] a,b, output logic[12:0] y);
  (* keep *) logic[6:0] lo; (* keep *) logic[6:0] h0,h1;
  always_comb begin
    lo={1'b0,a[5:0]}+{1'b0,b[5:0]};
    h0={1'b0,a[12:6]}+{1'b0,b[12:6]};
    h1={1'b0,a[12:6]}+{1'b0,b[12:6]}+1'b1;
    y={lo[6]?h1[6:0]:h0[6:0],lo[5:0]};
  end
endmodule

module add17_csel(input logic[16:0] a,b, output logic[16:0] y);
  (* keep *) logic[8:0] lo; (* keep *) logic[8:0] h0,h1;
  always_comb begin
    lo={1'b0,a[7:0]}+{1'b0,b[7:0]};
    h0={1'b0,a[16:8]}+{1'b0,b[16:8]};
    h1={1'b0,a[16:8]}+{1'b0,b[16:8]}+1'b1;
    y={lo[8]?h1[8:0]:h0[8:0],lo[7:0]};
  end
endmodule

module add21_csel(input logic[20:0] a,b, output logic[20:0] y);
  (* keep *) logic[10:0] lo; (* keep *) logic[10:0] h0,h1;
  always_comb begin
    lo={1'b0,a[9:0]}+{1'b0,b[9:0]};
    h0={1'b0,a[20:10]}+{1'b0,b[20:10]};
    h1={1'b0,a[20:10]}+{1'b0,b[20:10]}+1'b1;
    y={lo[10]?h1[10:0]:h0[10:0],lo[9:0]};
  end
endmodule

module packetfence_csel_lane(
 input logic clk,input logic rst,input logic valid,input logic[7:0] x,
 output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
 logic[12:0] n0; logic[16:0] n1; logic[20:0] n2;
 add13_csel a0(.a(z0),.b({5'b0,x}),.y(n0));
 add17_csel a1(.a(z1),.b({4'b0,z0}),.y(n1));
 add21_csel a2(.a(z2),.b({4'b0,z1}),.y(n2));
 always_ff @(posedge clk) begin
   if(rst) begin z0<='0;z1<='0;z2<='0; end
   else if(valid) begin z0<=n0;z1<=n1;z2<=n2; end
 end
endmodule

module seq32_pair7(
 input logic clk,input logic rst,input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,input logic seq_valid,
 output logic accept_fast,output logic mismatch
);
 logic phase,first_bad,neq;
 always_comb neq=(rx_chunk!=exp_chunk);
 always_ff @(posedge clk) begin
   if(rst) begin phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0; end
   else begin accept_fast<=0; if(seq_valid) begin
     if(!phase) begin first_bad<=neq;mismatch<=neq;phase<=1; end
     else begin mismatch<=first_bad|neq;accept_fast<=!(first_bad|neq);phase<=0; end
   end end
 end
endmodule

module packetfence17_csel_bench(
 input logic clk,input logic rst,input logic valid,input logic[135:0] semantic_bytes,output logic[20:0] witness
);
 genvar i;
 generate for(i=0;i<17;i=i+1) begin:L
   logic[12:0] z0;logic[16:0] z1;logic[20:0] z2;
   packetfence_csel_lane p(.clk(clk),.rst(rst),.valid(valid),.x(semantic_bytes[i*8 +:8]),.z0(z0),.z1(z1),.z2(z2));
   if(i==0) assign witness=z2;
 end endgenerate
endmodule

module hft_pair_csel_merged_bench(
 input logic clk,input logic rst,input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,input logic seq_valid,
 input logic valid_sem,input logic[135:0] semantic_bytes,
 output logic accept_fast,output logic mismatch,output logic[20:0] witness
);
 seq32_pair7 q(.clk(clk),.rst(rst),.rx_chunk(rx_chunk),.exp_chunk(exp_chunk),.seq_valid(seq_valid),.accept_fast(accept_fast),.mismatch(mismatch));
 packetfence17_csel_bench p(.clk(clk),.rst(rst),.valid(valid_sem),.semantic_bytes(semantic_bytes),.witness(witness));
endmodule
