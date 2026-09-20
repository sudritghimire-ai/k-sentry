// HFT fast-path v3: optimize the overwhelmingly common exact-in-order case.
// Any mismatch falls to the conventional 64-bit slow path for ordering classification.

module seq64_eq_only_bench(
  input logic clk, input logic rst,
  input logic [63:0] rx_seq, input logic [63:0] exp_seq,
  output logic eq
);
  logic [63:0] rq, eqv;
  always_ff @(posedge clk) begin
    if (rst) begin rq<='0; eqv<='0; eq<=1'b0; end
    else begin rq<=rx_seq; eqv<=exp_seq; eq <= (rq == eqv); end
  end
endmodule

module seq32_stream_bench(
  input logic clk,input logic rst,
  input logic [31:0] rx_chunk,input logic [31:0] exp_chunk,
  input logic start_pkt,input logic last_chunk,
  output logic accept_fast,output logic mismatch
);
  logic neq;
  always_comb neq = (rx_chunk != exp_chunk);
  always_ff @(posedge clk) begin
    if (rst) begin mismatch<=1'b0;accept_fast<=1'b0; end
    else begin
      accept_fast<=1'b0;
      if(start_pkt) begin
        mismatch<=neq;
        if(last_chunk) accept_fast<=!neq;
      end else begin
        mismatch<=mismatch|neq;
        if(last_chunk) accept_fast<=!(mismatch|neq);
      end
    end
  end
endmodule

module seq16_stream_bench(
  input logic clk,input logic rst,
  input logic [15:0] rx_chunk,input logic [15:0] exp_chunk,
  input logic start_pkt,input logic last_chunk,
  output logic accept_fast,output logic mismatch
);
  logic neq;
  always_comb neq = (rx_chunk != exp_chunk);
  always_ff @(posedge clk) begin
    if (rst) begin mismatch<=1'b0;accept_fast<=1'b0; end
    else begin
      accept_fast<=1'b0;
      if(start_pkt) begin
        mismatch<=neq;
        if(last_chunk) accept_fast<=!neq;
      end else begin
        mismatch<=mismatch|neq;
        if(last_chunk) accept_fast<=!(mismatch|neq);
      end
    end
  end
endmodule

module packetfence_lane_fast(
  input logic clk,input logic rst,input logic valid,input logic[7:0] x,
  output logic[12:0] c0,output logic[17:0] c1,output logic[20:0] c2
);
  logic[12:0] s;
  logic[18:0] t;
  always_comb begin s=c0+x; t=c2+c1; end
  always_ff @(posedge clk) begin
    if(rst) begin c0<='0;c1<='0;c2<='0; end
    else if(valid) begin c0<=s;c1<=c1+s;c2<=t+s; end
  end
endmodule

module packetfence17_bench(
  input logic clk,input logic rst,input logic valid,input logic[135:0] semantic_bytes,
  output logic [20:0] witness
);
  genvar i;
  generate for(i=0;i<17;i=i+1) begin:L
    logic[12:0] c0; logic[17:0] c1; logic[20:0] c2;
    packetfence_lane_fast p(.clk(clk),.rst(rst),.valid(valid),
      .x(semantic_bytes[i*8 +: 8]),.c0(c0),.c1(c1),.c2(c2));
    if(i==0) assign witness=c2;
  end endgenerate
endmodule

module hft_stream32_packetfence_bench(
  input logic clk,input logic rst,
  input logic [31:0] rx_chunk,input logic [31:0] exp_chunk,
  input logic start_pkt,input logic last_chunk,
  input logic valid_sem,input logic [135:0] semantic_bytes,
  output logic accept_fast, output logic mismatch, output logic [20:0] witness
);
  seq32_stream_bench s(.clk(clk),.rst(rst),.rx_chunk(rx_chunk),.exp_chunk(exp_chunk),
    .start_pkt(start_pkt),.last_chunk(last_chunk),.accept_fast(accept_fast),.mismatch(mismatch));
  packetfence17_bench p(.clk(clk),.rst(rst),.valid(valid_sem),.semantic_bytes(semantic_bytes),.witness(witness));
endmodule
