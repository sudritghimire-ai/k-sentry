// HFT v10: 8+8 carry-select two-stage expected sequence updater.

module add16_csel10(input logic[15:0] a,b, output logic[16:0] y);
 logic[8:0] lo,h0,h1;
 always_comb begin
   lo={1'b0,a[7:0]}+{1'b0,b[7:0]};
   h0={1'b0,a[15:8]}+{1'b0,b[15:8]};
   h1={1'b0,a[15:8]}+{1'b0,b[15:8]}+9'd1;
   y={lo[8] ? h1 : h0, lo[7:0]};
 end
endmodule

module seq64_count_update_pipe2_csel_bench(
 input logic clk,input logic rst,input logic valid,input logic[15:0] count,
 output logic[15:0] e0,e1,e2,e3
);
 logic st1v;
 logic[15:0] r_n0,r_u1,r_u2,r_u3,r_e1,r_e2,r_e3;
 logic r_c0,r_ov1,r_ov2;
 logic[16:0] s0,u1,u2,u3;
 add16_csel10 a0(.a(e0),.b(count),.y(s0));
 add16_csel10 a1(.a(e1),.b(16'd1),.y(u1));
 add16_csel10 a2(.a(e2),.b(16'd1),.y(u2));
 add16_csel10 a3(.a(e3),.b(16'd1),.y(u3));
 always_ff @(posedge clk) begin
   if(rst) begin e0<='0;e1<='0;e2<='0;e3<='0;st1v<=0;
     r_n0<='0;r_u1<='0;r_u2<='0;r_u3<='0;r_e1<='0;r_e2<='0;r_e3<='0;r_c0<=0;r_ov1<=0;r_ov2<=0;
   end else begin
     if(st1v) begin
       e0<=r_n0;
       e1<=r_c0?r_u1:r_e1;
       e2<=(r_c0&r_ov1)?r_u2:r_e2;
       e3<=(r_c0&r_ov1&r_ov2)?r_u3:r_e3;
     end
     st1v<=valid;
     if(valid) begin
       r_n0<=s0[15:0];r_u1<=u1[15:0];r_u2<=u2[15:0];r_u3<=u3[15:0];
       r_e1<=e1;r_e2<=e2;r_e3<=e3;
       r_c0<=s0[16];
       r_ov1<=&e1;
       r_ov2<=&e2;
     end
   end
 end
endmodule
