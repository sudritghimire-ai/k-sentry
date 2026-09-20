// HFT fast-path v5: fixed two-beat 64-bit sequence checker + Jordan PacketFence.
// Dedicated normalized sequence extractor supplies first/second 32-bit halves on consecutive seq_valid cycles.

module seq32_pair_fast(
  input logic clk,input logic rst,
  input logic [31:0] rx_chunk,input logic [31:0] exp_chunk,
  input logic seq_valid,
  output logic accept_fast,output logic mismatch
);
  logic phase;      // 0 = first half, 1 = second half
  logic first_bad;
  logic neq;
  always_comb neq=(rx_chunk!=exp_chunk);
  always_ff @(posedge clk) begin
    if(rst) begin phase<=0;first_bad<=0;accept_fast<=0;mismatch<=0; end
    else begin
      accept_fast<=0;
      if(seq_valid) begin
        if(!phase) begin
          first_bad<=neq;
          mismatch<=neq;
          phase<=1;
        end else begin
          mismatch<=first_bad|neq;
          accept_fast<=!(first_bad|neq);
          phase<=0;
        end
      end
    end
  end
endmodule

module packetfence_jordan_lane5(
  input logic clk,input logic rst,input logic valid,input logic[7:0] x,
  output logic[12:0] z0,output logic[16:0] z1,output logic[20:0] z2
);
  always_ff @(posedge clk) begin
    if(rst) begin z0<='0;z1<='0;z2<='0; end
    else if(valid) begin z0<=z0+x; z1<=z1+z0; z2<=z2+z1; end
  end
endmodule

module hft_pair_jordan_merged_bench(
  input logic clk,input logic rst,
  input logic[31:0] rx_chunk,input logic[31:0] exp_chunk,input logic seq_valid,
  input logic valid_sem,input logic[135:0] semantic_bytes,
  output logic accept_fast,output logic mismatch,output logic[20:0] witness
);
  seq32_pair_fast s(.clk(clk),.rst(rst),.rx_chunk(rx_chunk),.exp_chunk(exp_chunk),
    .seq_valid(seq_valid),.accept_fast(accept_fast),.mismatch(mismatch));
  genvar i;
  generate for(i=0;i<17;i=i+1) begin:L
    logic[12:0] z0; logic[16:0] z1; logic[20:0] z2;
    packetfence_jordan_lane5 p(.clk(clk),.rst(rst),.valid(valid_sem),.x(semantic_bytes[i*8 +: 8]),.z0(z0),.z1(z1),.z2(z2));
    if(i==0) assign witness=z2;
  end endgenerate
endmodule
