/***************************************************/
/* Matrix Vector Multiplication (MVM) Engine       */
/* dot8 — Fully pipelined 8-lane dot product unit  */
/* Computes the dot product of two 8-element signed*/
/* vectors using a multiply + adder-tree reduction */
/*                                                 */
/* Author: Liam Ung                                */
/* Originally developed for ECE 327 (Digital       */
/* Hardware Systems), University of Waterloo       */
/***************************************************/
`timescale 1ns / 1ps //REMOVE LATER
module dot8 # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32
)(
    input clk,
    input rst,
    input signed [8*IWIDTH-1:0] vec0,
    input signed [8*IWIDTH-1:0] vec1,
    input ivalid,
    output signed [OWIDTH-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
logic signed [8*IWIDTH-1:0] r_a, r_b;
logic signed [2*IWIDTH-1:0] s00, s01, s02, s03, s04, s05, s06, s07;
logic signed [2*IWIDTH:0] s10, s11, s12, s13;
logic signed [2*IWIDTH+1:0] s20, s21;
logic signed [OWIDTH-1:0] r_sum;
logic v0, v1, v2, v3, v4;

always_ff @(posedge clk) begin
    if(rst) begin
        r_a <= 0;
        r_b <= 0;
        r_sum <= 0;

        v0 <= 0; v1 <= 0; v2 <= 0; v3 <= 0; v4 <= 0;
        s00 <= 0; s01 <= 0; s02 <= 0; s03 <= 0; s04 <= 0; s05 <= 0; s06 <= 0; s07 <= 0;
        s10 <= 0; s11 <= 0; s12 <= 0; s13 <= 0;
        s20 <= 0; s21 <= 0;
    end else begin
        //stage 0
        r_a <= vec0;
        r_b <= vec1;
        v0 <= ivalid;

        //stage 1
        v1 <= v0;
        s00 <= $signed(r_a[0 +: IWIDTH]) * $signed(r_b[0 +: IWIDTH]);
        s01 <= $signed(r_a[IWIDTH +: IWIDTH]) * $signed(r_b[IWIDTH +: IWIDTH]);
        s02 <= $signed(r_a[2*IWIDTH +: IWIDTH]) * $signed(r_b[2*IWIDTH +: IWIDTH]);
        s03 <= $signed(r_a[3*IWIDTH +: IWIDTH]) * $signed(r_b[3*IWIDTH +: IWIDTH]);
        s04 <= $signed(r_a[4*IWIDTH +: IWIDTH]) * $signed(r_b[4*IWIDTH +: IWIDTH]);
        s05 <= $signed(r_a[5*IWIDTH +: IWIDTH]) * $signed(r_b[5*IWIDTH +: IWIDTH]);
        s06 <= $signed(r_a[6*IWIDTH +: IWIDTH]) * $signed(r_b[6*IWIDTH +: IWIDTH]);
        s07 <= $signed(r_a[7*IWIDTH +: IWIDTH]) * $signed(r_b[7*IWIDTH +: IWIDTH]);

        //stage 2
        v2 <= v1;
        s10 <= $signed(s00) + $signed(s01);
        s11 <= $signed(s02) + $signed(s03);
        s12 <= $signed(s04) + $signed(s05);
        s13 <= $signed(s06) + $signed(s07);

        //stage 3
        v3 <= v2;
        s20 <= $signed(s10) + $signed(s11);
        s21 <= $signed(s12) + $signed(s13);

        //stage 4
        v4 <= v3;
        r_sum <= OWIDTH'(s20) + OWIDTH'(s21);

        //if(v4 == 1) begin
        //    $display("ovalid = 1 for output = %0d", r_sum);
        //end

    end
end

assign ovalid = v4;
assign result = r_sum;

/******* Your code ends here ********/

endmodule
