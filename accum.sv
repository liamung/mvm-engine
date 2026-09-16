/***************************************************/
/* Matrix Vector Multiplication (MVM) Engine       */
/* accum — Accumulator                             */
/* Sums a stream of signed values into a running   */
/* total, enabling dot products longer than 8      */
/* elements to be computed over multiple cycles    */
/*                                                 */
/* Author: Liam Ung                                */
/* Originally developed for ECE 327 (Digital       */
/* Hardware Systems), University of Waterloo       */
/***************************************************/
`timescale 1ns / 1ps //REMOVE
module accum # (
    parameter DATAW = 32,
    parameter ACCUMW = 32
)(
    input  clk,
    input  rst,
    input  signed [DATAW-1:0] data,
    input  ivalid,
    input  first,
    input  last,
    output signed [ACCUMW-1:0] result,
    output ovalid
);

/******* Your code starts here *******/
logic signed [ACCUMW-1:0] r_sum;
logic r_ivalid, r_first, r_last;
// Internal registers to drive the outputs
logic signed [ACCUMW-1:0] r_result;
logic r_ovalid;

always_ff @(posedge clk) begin
    if(rst) begin
        r_sum <= 0;
        r_result <= 0;
        r_ovalid <= 0;
    end else begin
        // Default ovalid to 0 so it only pulses for one cycle
        r_ovalid <= 0;

        if(ivalid) begin
            if(first && last) begin
                // Handle edge case of 1-cycle accumulation
                r_result <= data;
                r_ovalid <= 1;
            end else if(first) begin
                // Start a new accumulation
                r_sum <= data;
            end else if(last) begin
                // Finish accumulation and pulse valid
                r_result <= r_sum + data;
                r_ovalid <= 1;
            end else begin
                // Normal accumulation
                r_sum <= r_sum + data;
            end
        end
    end
end

// Continuously assign the internal registers to the output wires
assign result = r_result;
assign ovalid = r_ovalid;

/******* Your code ends here ********/

endmodule