/***************************************************/
/* Matrix Vector Multiplication (MVM) Engine       */
/* ctrl — Control FSM                              */
/* Generates the vector/matrix memory read address */
/* sequence and accumulator control signals that   */
/* orchestrate the MVM datapath                    */
/*                                                 */
/* Author: Liam Ung                                */
/* Originally developed for ECE 327 (Digital       */
/* Hardware Systems), University of Waterloo       */
/***************************************************/
`timescale 1 ns / 1 ps //REMOVE
module ctrl # (
    parameter VEC_ADDRW = 8,
    parameter MAT_ADDRW = 9,
    parameter VEC_SIZEW = VEC_ADDRW + 1,
    parameter MAT_SIZEW = MAT_ADDRW + 1
    
)(
    input  clk,
    input  rst,
    input  start,
    input  [VEC_ADDRW-1:0] vec_start_addr,
    input  [VEC_SIZEW-1:0] vec_num_words,
    input  [MAT_ADDRW-1:0] mat_start_addr,
    input  [MAT_SIZEW-1:0] mat_num_rows_per_olane,
    output [VEC_ADDRW-1:0] vec_raddr,
    output [MAT_ADDRW-1:0] mat_raddr,
    output accum_first,
    output accum_last,
    output ovalid,
    output busy
);

/******* Your code starts here *******/
typedef enum logic {IDLE, COMPUTE} state_t;
state_t state;

// Internal registers to lock in the starting parameters
logic [VEC_ADDRW-1:0] r_vec_start_addr;
logic [VEC_SIZEW-1:0] r_vec_num_words;
logic [MAT_ADDRW-1:0] r_mat_start_addr;
logic [MAT_SIZEW-1:0] r_mat_num_rows;

// Counters to track progress through the vector and matrix rows
logic [VEC_SIZEW-1:0] vec_word_count;
logic [MAT_SIZEW-1:0] row_count;

logic [VEC_ADDRW-1:0] r_vec_raddr;
logic [MAT_ADDRW-1:0] r_mat_raddr;
logic r_accum_first, r_accum_last, r_ovalid, r_busy;

always_ff @(posedge clk) begin
    if (rst) begin
        state <= IDLE;
        r_vec_raddr <= 0;
        r_mat_raddr <= 0;
        r_accum_first <= 0;
        r_accum_last <= 0;
        r_ovalid <= 0;
        r_busy <= 0;
        vec_word_count <= 0;
        row_count <= 0;
    end else begin
        case (state)
            IDLE: begin
                r_ovalid <= 0;
                r_busy <= 0;
                r_accum_first <= 0;
                r_accum_last <= 0;

                if (start) begin
                    state <= COMPUTE;
                    
                    // Lock in the parameters from the top-level
                    r_vec_start_addr <= vec_start_addr;
                    r_vec_num_words <= vec_num_words;
                    r_mat_start_addr <= mat_start_addr;
                    r_mat_num_rows <= mat_num_rows_per_olane;

                    // Setup the very first memory read
                    r_vec_raddr <= vec_start_addr;
                    r_mat_raddr <= mat_start_addr;
                    vec_word_count <= 0;
                    row_count <= 0;

                    r_busy <= 1;
                    r_ovalid <= 1;
                    r_accum_first <= 1;
                    
                    // Edge case: if the vector is only 1 word long, first is also last
                    r_accum_last <= (vec_num_words == 1) ? 1'b1 : 1'b0;
                end
            end

            COMPUTE: begin
                if (vec_word_count == r_vec_num_words - 1) begin
                    // We have reached the end of the current vector
                    
                    if (row_count == r_mat_num_rows - 1) begin
                        // We have finished all assigned matrix rows; return to IDLE
                        state <= IDLE;
                        r_ovalid <= 0;
                        r_busy <= 0;
                        r_accum_first <= 0;
                        r_accum_last <= 0;
                    end else begin
                        // Move on to process the next matrix row
                        row_count <= row_count + 1;
                        vec_word_count <= 0;

                        r_vec_raddr <= r_vec_start_addr; // Reset vector address back to the start
                        r_mat_raddr <= mat_raddr + 1;    // Continue reading the next matrix address

                        r_accum_first <= 1;
                        r_accum_last <= (r_vec_num_words == 1) ? 1'b1 : 1'b0;
                    end
                end else begin
                    // Continue moving along the current vector/row
                    vec_word_count <= vec_word_count + 1;
                    r_vec_raddr <= r_vec_raddr + 1;
                    r_mat_raddr <= r_mat_raddr + 1;

                    r_accum_first <= 0;
                    // Trigger 'last' when we are on the second-to-last word
                    r_accum_last <= (vec_word_count == r_vec_num_words - 2) ? 1'b1 : 1'b0;
                end
            end
        endcase
    end
end

assign accum_first = r_accum_first;
assign accum_last = r_accum_last;
assign ovalid = r_ovalid;
assign busy = r_busy;
assign vec_raddr = r_vec_raddr;
assign mat_raddr = r_mat_raddr;


/******* Your code ends here ********/

endmodule