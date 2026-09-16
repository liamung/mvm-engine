/***************************************************/
/* Matrix Vector Multiplication (MVM) Engine       */
/* mvm — Top-level module                          */
/* Instantiates and connects the vector memory,    */
/* per-lane matrix memories, dot product units,    */
/* accumulators, and control FSM into a complete   */
/* parallel-lane MVM engine                        */
/*                                                 */
/* Author: Liam Ung                                */
/* Originally developed for ECE 327 (Digital       */
/* Hardware Systems), University of Waterloo       */
/***************************************************/
`timescale 1ns / 1ps //REMOVE
module mvm # (
    parameter IWIDTH = 8,
    parameter OWIDTH = 32,
    parameter MEM_DATAW = IWIDTH * 8,
    parameter VEC_MEM_DEPTH = 256,
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH),
    parameter MAT_MEM_DEPTH = 512,
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH),
    parameter NUM_OLANES = 8
)(
    input clk,
    input rst,
    input [MEM_DATAW-1:0] i_vec_wdata,
    input [VEC_ADDRW-1:0] i_vec_waddr,
    input i_vec_wen,
    input [MEM_DATAW-1:0] i_mat_wdata,
    input [MAT_ADDRW-1:0] i_mat_waddr,
    input [NUM_OLANES-1:0] i_mat_wen,
    input i_start,
    input [VEC_ADDRW-1:0] i_vec_start_addr,
    input [VEC_ADDRW:0] i_vec_num_words,
    input [MAT_ADDRW-1:0] i_mat_start_addr,
    input [MAT_ADDRW:0] i_mat_num_rows_per_olane,
    output o_busy,
    output [OWIDTH*NUM_OLANES-1:0] o_result,
    output o_valid
);

/******* Your code starts here *******/
// ====================================================================
// 1. Internal Signal Declarations
// ====================================================================
// Controller signals
logic [VEC_ADDRW-1:0] vec_raddr;
logic [MAT_ADDRW-1:0] mat_raddr;
logic ctrl_accum_first, ctrl_accum_last;
logic ctrl_ovalid;

// Memory read data signals
logic [MEM_DATAW-1:0] vec_rdata;
logic [MEM_DATAW-1:0] mat_rdata [0:NUM_OLANES-1]; // Array for multiple matrix memories

// Dot product outputs
logic signed [OWIDTH-1:0] dot_result [0:NUM_OLANES-1];
logic dot_ovalid [0:NUM_OLANES-1];

// Accumulator signals
logic signed [OWIDTH-1:0] accum_result [0:NUM_OLANES-1];
logic accum_ovalid [0:NUM_OLANES-1];

// ====================================================================
// 2. Pipeline Delay Shift Registers (6 Cycles)
// ====================================================================
// The memory read takes 1 cycle, and dot8 takes 5 cycles. 
// We must delay the controller's first/last signals by 6 cycles 
// so they arrive at the accumulators exactly when the dot8 data arrives.

logic [5:0] first_shift;
logic [5:0] last_shift;

always_ff @(posedge clk) begin
    if (rst) begin
        first_shift <= 0;
        last_shift <= 0;
    end else begin
        // Shift left, pulling in the new control signals at the LSB
        first_shift <= {first_shift[4:0], ctrl_accum_first};
        last_shift  <= {last_shift[4:0], ctrl_accum_last};
    end
end

// 1-Cycle delay for dot product valid signal
logic delayed_ctrl_ovalid;

always_ff @(posedge clk) begin
    if (rst) begin
        delayed_ctrl_ovalid <= 0;
    end else begin
        delayed_ctrl_ovalid <= ctrl_ovalid;
    end
end

// The delayed signals are tapped from the MSB (index 5 = 6th cycle)
logic delayed_accum_first;
logic delayed_accum_last;
assign delayed_accum_first = first_shift[5];
assign delayed_accum_last  = last_shift[5];

// ====================================================================
// 3. Controller Instantiation
// ====================================================================
ctrl #(
    .VEC_ADDRW(VEC_ADDRW),
    .MAT_ADDRW(MAT_ADDRW),
    .VEC_SIZEW(VEC_ADDRW + 1),
    .MAT_SIZEW(MAT_ADDRW + 1)
) controller_inst (
    .clk(clk),
    .rst(rst),
    .start(i_start),
    .vec_start_addr(i_vec_start_addr),
    .vec_num_words(i_vec_num_words),
    .mat_start_addr(i_mat_start_addr),
    .mat_num_rows_per_olane(i_mat_num_rows_per_olane),
    .vec_raddr(vec_raddr),
    .mat_raddr(mat_raddr),
    .accum_first(ctrl_accum_first),
    .accum_last(ctrl_accum_last),
    .ovalid(ctrl_ovalid),
    .busy(o_busy)
);

// ====================================================================
// 4. Vector Memory Instantiation (Broadcast to all lanes)
// ====================================================================
mem #(
    .DATAW(MEM_DATAW),
    .DEPTH(VEC_MEM_DEPTH)
) vec_mem_inst (
    .clk(clk),
    .wdata(i_vec_wdata),
    .waddr(i_vec_waddr),
    .wen(i_vec_wen),
    .raddr(vec_raddr),
    .rdata(vec_rdata)
);

// ====================================================================
// 5. Output Lanes (Matrix Mems, Dot8s, Accumulators)
// ====================================================================
// Using a generate block to instantiate the NUM_OLANES compute lanes.

genvar i;
generate
    for (i = 0; i < NUM_OLANES; i++) begin : compute_lane
    
        // Matrix Memory for Lane 'i'
        mem #(
            .DATAW(MEM_DATAW),
            .DEPTH(MAT_MEM_DEPTH)
        ) mat_mem_inst (
            // Connect matrix memory ports here
            // Hint: Use i_mat_wen[i] to route the correct write enable bit
            .clk(clk),
            .wdata(i_mat_wdata),
            .waddr(i_mat_waddr),
            .wen(i_mat_wen[i]),
            .raddr(mat_raddr),
            .rdata(mat_rdata[i])
        );

        // Dot Product Unit for Lane 'i'
        dot8 #(
            .IWIDTH(IWIDTH),
            .OWIDTH(OWIDTH)
        ) dot8_inst (
            // Connect dot8 ports here
            .clk(clk),
            .rst(rst),
            .vec0(vec_rdata),
            .vec1(mat_rdata[i]),
            .ivalid(delayed_ctrl_ovalid),
            .result(dot_result[i]),
            .ovalid(dot_ovalid[i])
        );

        // Accumulator for Lane 'i'
        accum #(
            .DATAW(OWIDTH),
            .ACCUMW(OWIDTH)
        ) accum_inst (
            // Connect accumulator ports here
            // Hint: Plug in delayed_accum_first and delayed_accum_last!
            .clk(clk),
            .rst(rst),
            .data(dot_result[i]),
            .ivalid(dot_ovalid[i]),
            .first(delayed_accum_first),
            .last(delayed_accum_last),
            .result(accum_result[i]),
            .ovalid(accum_ovalid[i])
        );

        // Map this lane's 32-bit accumulator result into the massive concatenated o_result bus
        assign o_result[(i*OWIDTH) +: OWIDTH] = accum_result[i];

    end
endgenerate

assign o_valid = accum_ovalid[0];

/******* Your code ends here ********/

endmodule