// HFT v18: same-cycle 64-bit exact equality fast-path alternatives.
// Mismatch can be classified by the conventional 64-bit ordering slow path.

module baseline64_order18(
 input logic clk,input logic rst,input logic[63:0] rx,input logic[63:0] exp,
 output logic eq,output logic lt
);
 logic[63:0] rq,eqv;
 always_ff @(posedge clk)begin if(rst)begin rq<=0;eqv<=0;eq<=0;lt<=0;end
 else begin rq<=rx;eqv<=exp;eq<=rq==eqv;lt<=rq<eqv;end end
endmodule

module eq64_flat18(
 input logic clk,input logic rst,input logic[63:0] rx,input logic[63:0] exp,output logic eq
);
 logic[63:0] rq,eqv;
 always_ff @(posedge clk)begin if(rst)begin rq<=0;eqv<=0;eq<=0;end
 else begin rq<=rx;eqv<=exp;eq<=rq==eqv;end end
endmodule

(* keep_hierarchy *)
module eq16_leaf18(input logic[15:0] a,b,output logic same);
 logic[3:0] nib;
 always_comb begin
  nib[0]=(a[3:0]==b[3:0]);nib[1]=(a[7:4]==b[7:4]);
  nib[2]=(a[11:8]==b[11:8]);nib[3]=(a[15:12]==b[15:12]);
  same=&nib;
 end
endmodule

module eq64_tree16_18(
 input logic clk,input logic rst,input logic[63:0] rx,input logic[63:0] exp,output logic eq
);
 logic[63:0] rq,eqv;(* keep *) logic[3:0] same;
 eq16_leaf18 a(.a(rq[15:0]),.b(eqv[15:0]),.same(same[0]));
 eq16_leaf18 b(.a(rq[31:16]),.b(eqv[31:16]),.same(same[1]));
 eq16_leaf18 c(.a(rq[47:32]),.b(eqv[47:32]),.same(same[2]));
 eq16_leaf18 d(.a(rq[63:48]),.b(eqv[63:48]),.same(same[3]));
 always_ff @(posedge clk)begin if(rst)begin rq<=0;eqv<=0;eq<=0;end
 else begin rq<=rx;eqv<=exp;eq<=&same;end end
endmodule

(* keep_hierarchy *)
module eq8_leaf18(input logic[7:0] a,b,output logic same);
 logic lo,hi;always_comb begin lo=(a[3:0]==b[3:0]);hi=(a[7:4]==b[7:4]);same=lo&hi;end
endmodule

module eq64_tree8_18(
 input logic clk,input logic rst,input logic[63:0] rx,input logic[63:0] exp,output logic eq
);
 logic[63:0] rq,eqv;(* keep *) logic[7:0] s;genvar i;
 generate for(i=0;i<8;i=i+1)begin:L eq8_leaf18 e(.a(rq[i*8+:8]),.b(eqv[i*8+:8]),.same(s[i]));end endgenerate
 logic a,b;
 always_comb begin a=&s[3:0];b=&s[7:4];end
 always_ff @(posedge clk)begin if(rst)begin rq<=0;eqv<=0;eq<=0;end
 else begin rq<=rx;eqv<=exp;eq<=a&b;end end
endmodule

module eq64_xor_tree18(
 input logic clk,input logic rst,input logic[63:0] rx,input logic[63:0] exp,output logic eq
);
 logic[63:0] rq,eqv,x;logic[15:0] n;logic[3:0] q;
 always_comb begin
   x=rq^eqv;
   for(integer i=0;i<16;i=i+1)n[i]=|x[i*4+:4];
   for(integer j=0;j<4;j=j+1)q[j]=|n[j*4+:4];
 end
 always_ff @(posedge clk)begin if(rst)begin rq<=0;eqv<=0;eq<=0;end
 else begin rq<=rx;eqv<=exp;eq<=~(|q);end end
endmodule
