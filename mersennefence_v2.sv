// MersenneFence v2: exact 64-bit sequence guard using only 11..15-bit CRT channels.
// CRT moduli: 2^12, 2^11-1, 2^13-1, 2^14-1, 2^15-1.
// Product > 2^64; guard moduli are pairwise coprime.
// Fast window: signed delta in [-2047, 2047].

module seq64_order_bench(
    input  logic        clk,
    input  logic        rst,
    input  logic [63:0] rx_seq,
    input  logic [63:0] exp_seq,
    output logic        eq,
    output logic        lt
);
    logic [63:0] rx_q, exp_q;
    always_ff @(posedge clk) begin
        if (rst) begin rx_q <= '0; exp_q <= '0; eq <= 1'b0; lt <= 1'b0; end
        else begin
            rx_q <= rx_seq;
            exp_q <= exp_seq;
            eq <= (rx_q == exp_q);
            lt <= (rx_q < exp_q);
        end
    end
endmodule

module mersenne_guard_comb(
    input  logic [63:0] rx_seq,
    input  logic [11:0] exp_r0,
    input  logic [10:0] exp_r11,
    input  logic [12:0] exp_r13,
    input  logic [13:0] exp_r14,
    input  logic [14:0] exp_r15,
    output logic        fast_valid,
    output logic signed [12:0] delta
);
    function automatic [10:0] mod2047(input logic [63:0] x);
        logic [12:0] p0,p1,p2; logic [13:0] s; logic [11:0] f;
        begin
            p0 = {2'b0,x[10:0]} + {2'b0,x[21:11]};
            p1 = {2'b0,x[32:22]} + {2'b0,x[43:33]};
            p2 = {2'b0,x[54:44]} + {4'b0,x[63:55]};
            s = p0 + p1 + p2;
            f = {1'b0,s[10:0]} + (s >> 11);
            mod2047 = (f >= 12'd2047) ? (f - 12'd2047) : f[10:0];
        end
    endfunction
    function automatic [12:0] mod8191(input logic [63:0] x);
        logic [13:0] p0,p1,p2; logic [15:0] s; logic [13:0] f;
        begin
            p0={1'b0,x[12:0]}+{1'b0,x[25:13]};
            p1={1'b0,x[38:26]}+{1'b0,x[51:39]};
            p2={1'b0,x[63:52]}; s=p0+p1+p2;
            f={1'b0,s[12:0]}+(s>>13);
            mod8191=(f>=14'd8191)?(f-14'd8191):f[12:0];
        end
    endfunction
    function automatic [13:0] mod16383(input logic [63:0] x);
        logic [14:0] p0,p1,p2; logic [16:0] s; logic [14:0] f;
        begin
            p0={1'b0,x[13:0]}+{1'b0,x[27:14]};
            p1={1'b0,x[41:28]}+{1'b0,x[55:42]};
            p2={7'b0,x[63:56]}; s=p0+p1+p2;
            f={1'b0,s[13:0]}+(s>>14);
            mod16383=(f>=15'd16383)?(f-15'd16383):f[13:0];
        end
    endfunction
    function automatic [14:0] mod32767(input logic [63:0] x);
        logic [15:0] p0,p1,p2; logic [17:0] s; logic [15:0] f;
        begin
            p0={1'b0,x[14:0]}+{1'b0,x[29:15]};
            p1={1'b0,x[44:30]}+{1'b0,x[59:45]};
            p2={12'b0,x[63:60]}; s=p0+p1+p2;
            f={1'b0,s[14:0]}+(s>>15);
            mod32767=(f>=16'd32767)?(f-16'd32767):f[14:0];
        end
    endfunction

    function automatic [10:0] addd2047(input logic [10:0] e,input logic signed[12:0] d);
      logic signed[14:0] z; begin z=$signed({1'b0,e})+d; if(z<0)z=z+15'sd2047; else if(z>=15'sd2047)z=z-15'sd2047; addd2047=z[10:0]; end
    endfunction
    function automatic [12:0] addd8191(input logic [12:0] e,input logic signed[12:0] d);
      logic signed[14:0] z; begin z=$signed({1'b0,e})+d; if(z<0)z=z+15'sd8191; else if(z>=15'sd8191)z=z-15'sd8191; addd8191=z[12:0]; end
    endfunction
    function automatic [13:0] addd16383(input logic [13:0] e,input logic signed[12:0] d);
      logic signed[15:0] z; begin z=$signed({1'b0,e})+d; if(z<0)z=z+16'sd16383; else if(z>=16'sd16383)z=z-16'sd16383; addd16383=z[13:0]; end
    endfunction
    function automatic [14:0] addd32767(input logic [14:0] e,input logic signed[12:0] d);
      logic signed[16:0] z; begin z=$signed({1'b0,e})+d; if(z<0)z=z+17'sd32767; else if(z>=17'sd32767)z=z-17'sd32767; addd32767=z[14:0]; end
    endfunction

    logic [11:0] dlow; logic signed [12:0] ds;
    logic [10:0] rr11,cr11; logic [12:0] rr13,cr13;
    logic [13:0] rr14,cr14; logic [14:0] rr15,cr15;
    always_comb begin
      dlow=rx_seq[11:0]-exp_r0;
      ds=dlow[11]?($signed({1'b0,dlow})-13'sd4096):$signed({1'b0,dlow});
      delta=ds;
      rr11=mod2047(rx_seq); rr13=mod8191(rx_seq); rr14=mod16383(rx_seq); rr15=mod32767(rx_seq);
      cr11=addd2047(exp_r11,ds); cr13=addd8191(exp_r13,ds); cr14=addd16383(exp_r14,ds); cr15=addd32767(exp_r15,ds);
      fast_valid=(ds>=-13'sd2047)&&(ds<=13'sd2047)&&(rr11==cr11)&&(rr13==cr13)&&(rr14==cr14)&&(rr15==cr15);
    end
endmodule

module mersenne_guard_bench(
    input logic clk,input logic rst,input logic[63:0] rx_seq,
    input logic[11:0] exp_r0,input logic[10:0] exp_r11,input logic[12:0] exp_r13,input logic[13:0] exp_r14,input logic[14:0] exp_r15,
    output logic fast_valid,output logic signed[12:0] delta
);
    logic[63:0] rx_q; logic[11:0] e0_q; logic[10:0] e11_q; logic[12:0] e13_q; logic[13:0] e14_q; logic[14:0] e15_q;
    logic fv_c; logic signed[12:0] d_c;
    mersenne_guard_comb u(.rx_seq(rx_q),.exp_r0(e0_q),.exp_r11(e11_q),.exp_r13(e13_q),.exp_r14(e14_q),.exp_r15(e15_q),.fast_valid(fv_c),.delta(d_c));
    always_ff @(posedge clk) begin
      if(rst) begin rx_q<='0;e0_q<='0;e11_q<='0;e13_q<='0;e14_q<='0;e15_q<='0;fast_valid<=0;delta<='0; end
      else begin rx_q<=rx_seq;e0_q<=exp_r0;e11_q<=exp_r11;e13_q<=exp_r13;e14_q<=exp_r14;e15_q<=exp_r15;fast_valid<=fv_c;delta<=d_c; end
    end
endmodule

module mersenne_guard_predecoded_bench(
    input logic clk,input logic rst,
    input logic[11:0] rx_r0,exp_r0,input logic[10:0] rx_r11,exp_r11,input logic[12:0] rx_r13,exp_r13,input logic[13:0] rx_r14,exp_r14,input logic[14:0] rx_r15,exp_r15,
    output logic fast_valid,output logic signed[12:0] delta
);
    logic[11:0] r0q,e0q; logic[10:0] r11q,e11q; logic[12:0] r13q,e13q; logic[13:0] r14q,e14q; logic[14:0] r15q,e15q;
    logic[11:0] dlow; logic signed[12:0] ds; logic[10:0] c11; logic[12:0] c13; logic[13:0] c14; logic[14:0] c15;
    function automatic [10:0] a11(input logic[10:0] e,input logic signed[12:0] d); logic signed[14:0] z; begin z=$signed({1'b0,e})+d;if(z<0)z=z+15'sd2047;else if(z>=15'sd2047)z=z-15'sd2047;a11=z[10:0];end endfunction
    function automatic [12:0] a13(input logic[12:0] e,input logic signed[12:0] d); logic signed[14:0] z; begin z=$signed({1'b0,e})+d;if(z<0)z=z+15'sd8191;else if(z>=15'sd8191)z=z-15'sd8191;a13=z[12:0];end endfunction
    function automatic [13:0] a14(input logic[13:0] e,input logic signed[12:0] d); logic signed[15:0] z; begin z=$signed({1'b0,e})+d;if(z<0)z=z+16'sd16383;else if(z>=16'sd16383)z=z-16'sd16383;a14=z[13:0];end endfunction
    function automatic [14:0] a15(input logic[14:0] e,input logic signed[12:0] d); logic signed[16:0] z; begin z=$signed({1'b0,e})+d;if(z<0)z=z+17'sd32767;else if(z>=17'sd32767)z=z-17'sd32767;a15=z[14:0];end endfunction
    always_comb begin dlow=r0q-e0q; ds=dlow[11]?($signed({1'b0,dlow})-13'sd4096):$signed({1'b0,dlow}); c11=a11(e11q,ds);c13=a13(e13q,ds);c14=a14(e14q,ds);c15=a15(e15q,ds); end
    always_ff @(posedge clk) begin
      if(rst) begin r0q<='0;e0q<='0;r11q<='0;e11q<='0;r13q<='0;e13q<='0;r14q<='0;e14q<='0;r15q<='0;e15q<='0;fast_valid<=0;delta<='0; end
      else begin
        r0q<=rx_r0;e0q<=exp_r0;r11q<=rx_r11;e11q<=exp_r11;r13q<=rx_r13;e13q<=exp_r13;r14q<=rx_r14;e14q<=exp_r14;r15q<=rx_r15;e15q<=exp_r15;
        delta<=ds; fast_valid<=(ds>=-13'sd2047)&&(ds<=13'sd2047)&&(r11q==c11)&&(r13q==c13)&&(r14q==c14)&&(r15q==c15);
      end
    end
endmodule

module packetfence_raw_lane(
    input logic clk,input logic rst,input logic valid,input logic[7:0] x,
    output logic[12:0] c0,output logic[17:0] c1,output logic[20:0] c2
);
    logic[12:0] s; logic[18:0] t;
    always_comb begin s=c0+x; t=c2+c1; end
    always_ff @(posedge clk) begin
      if(rst) begin c0<='0;c1<='0;c2<='0; end
      else if(valid) begin c0<=s;c1<=c1+s;c2<=t+s; end
    end
endmodule

module mersennefence_merged_bench(
    input logic clk,input logic rst,input logic[63:0] rx_seq,
    input logic[11:0] exp_r0,input logic[10:0] exp_r11,input logic[12:0] exp_r13,input logic[13:0] exp_r14,input logic[14:0] exp_r15,
    output logic fast_valid
);
    logic signed[12:0] delta;
    mersenne_guard_bench g(.clk(clk),.rst(rst),.rx_seq(rx_seq),.exp_r0(exp_r0),.exp_r11(exp_r11),.exp_r13(exp_r13),.exp_r14(exp_r14),.exp_r15(exp_r15),.fast_valid(fast_valid),.delta(delta));
    logic[63:0] lfsr;
    always_ff @(posedge clk) begin if(rst)lfsr<=64'h1; else lfsr<={lfsr[62:0],lfsr[63]^lfsr[62]^lfsr[60]^lfsr[59]}; end
    genvar i;
    generate for(i=0;i<17;i=i+1) begin: L
      logic[7:0] xv; logic[12:0] c0; logic[17:0] c1; logic[20:0] c2; localparam logic[7:0] K=i*17;
      assign xv=lfsr[(i*3)%56 +: 8]^K;
      packetfence_raw_lane p(.clk(clk),.rst(rst),.valid(1'b1),.x(xv),.c0(c0),.c1(c1),.c2(c2));
    end endgenerate
endmodule
