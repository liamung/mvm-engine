//DO NOT USE - liam
`timescale 1ns / 1ps

module mvm_datapath_tb();

    // ====================================================================
    // Parameters (Matching MVM module)
    // ====================================================================
    parameter IWIDTH = 8;
    parameter OWIDTH = 32;
    parameter MEM_DATAW = IWIDTH * 8;
    parameter VEC_MEM_DEPTH = 256;
    parameter VEC_ADDRW = $clog2(VEC_MEM_DEPTH);
    parameter MAT_MEM_DEPTH = 512;
    parameter MAT_ADDRW = $clog2(MAT_MEM_DEPTH);
    parameter NUM_OLANES = 8;

    // ====================================================================
    // Signals
    // ====================================================================
    logic clk;
    logic rst;
    
    // Memory Write Interfaces
    logic [MEM_DATAW-1:0] i_vec_wdata;
    logic [VEC_ADDRW-1:0] i_vec_waddr;
    logic i_vec_wen;
    
    logic [MEM_DATAW-1:0] i_mat_wdata;
    logic [MAT_ADDRW-1:0] i_mat_waddr;
    logic [NUM_OLANES-1:0] i_mat_wen;
    
    // Top-Level Control (Unused in this forced testbench, but required for wiring)
    logic i_start;
    logic [VEC_ADDRW-1:0] i_vec_start_addr;
    logic [VEC_ADDRW:0]   i_vec_num_words;
    logic [MAT_ADDRW-1:0] i_mat_start_addr;
    logic [MAT_ADDRW:0]   i_mat_num_rows_per_olane;
    
    // Outputs
    logic o_busy;
    logic [OWIDTH*NUM_OLANES-1:0] o_result;
    logic o_valid;

    // ====================================================================
    // DUT Instantiation
    // ====================================================================
    mvm #(
        .IWIDTH(IWIDTH),
        .OWIDTH(OWIDTH),
        .MEM_DATAW(MEM_DATAW),
        .VEC_MEM_DEPTH(VEC_MEM_DEPTH),
        .VEC_ADDRW(VEC_ADDRW),
        .MAT_MEM_DEPTH(MAT_MEM_DEPTH),
        .MAT_ADDRW(MAT_ADDRW),
        .NUM_OLANES(NUM_OLANES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .i_vec_wdata(i_vec_wdata),
        .i_vec_waddr(i_vec_waddr),
        .i_vec_wen(i_vec_wen),
        .i_mat_wdata(i_mat_wdata),
        .i_mat_waddr(i_mat_waddr),
        .i_mat_wen(i_mat_wen),
        .i_start(i_start),
        .i_vec_start_addr(i_vec_start_addr),
        .i_vec_num_words(i_vec_num_words),
        .i_mat_start_addr(i_mat_start_addr),
        .i_mat_num_rows_per_olane(i_mat_num_rows_per_olane),
        .o_busy(o_busy),
        .o_result(o_result),
        .o_valid(o_valid)
    );

    // ====================================================================
    // Clock Generation (10ns period -> 100MHz)
    // ====================================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper function to easily pack 8 integers into a 64-bit memory word
    function logic [MEM_DATAW-1:0] pack_vec(
        input int v7, input int v6, input int v5, input int v4,
        input int v3, input int v2, input int v1, input int v0
    );
        begin
            pack_vec = { 
                v7[IWIDTH-1:0], v6[IWIDTH-1:0], v5[IWIDTH-1:0], v4[IWIDTH-1:0], 
                v3[IWIDTH-1:0], v2[IWIDTH-1:0], v1[IWIDTH-1:0], v0[IWIDTH-1:0] 
            };
        end
    endfunction

    // ====================================================================
    // Test Stimulus
    // ====================================================================
    initial begin
        // 1. Initialize Inputs & Reset
        rst = 1;
        i_vec_wen = 0;
        i_mat_wen = 0;
        i_start = 0;
        
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        @(negedge clk);
        $display("--- Starting MVM Datapath Test ---");

        // ---------------------------------------------------------
        // PHASE 1: Load Memories
        // ---------------------------------------------------------
        $display("Loading Vector and Matrix Memories...");
        
        // Load Vector Memory (Addresses 8, 9, 10, 11) with all 1s
        i_vec_wen = 1;
        i_vec_waddr = 8; i_vec_wdata = pack_vec(1,1,1,1,1,1,1,1); @(negedge clk);
        i_vec_waddr = 9; i_vec_wdata = pack_vec(1,1,1,1,1,1,1,1); @(negedge clk);
        i_vec_waddr = 10; i_vec_wdata = pack_vec(1,1,1,1,1,1,1,1); @(negedge clk);
        i_vec_waddr = 11; i_vec_wdata = pack_vec(1,1,1,1,1,1,1,1); @(negedge clk);
        i_vec_wen = 0;

        // Load Matrix Memory Lane 0 (Addresses 0, 1, 2, 3) with all 2s
        i_mat_wen = 8'b00000001; // One-hot for Lane 0
        i_mat_waddr = 0; i_mat_wdata = pack_vec(2,2,2,2,2,2,2,2); @(negedge clk);
        i_mat_waddr = 1; i_mat_wdata = pack_vec(2,2,2,2,2,2,2,2); @(negedge clk);
        i_mat_waddr = 2; i_mat_wdata = pack_vec(2,2,2,2,2,2,2,2); @(negedge clk);
        i_mat_waddr = 3; i_mat_wdata = pack_vec(2,2,2,2,2,2,2,2); @(negedge clk);
        
        // Load Matrix Memory Lane 1 (Addresses 0, 1, 2, 3) with all 3s
        i_mat_wen = 8'b00000010; // One-hot for Lane 1
        i_mat_waddr = 0; i_mat_wdata = pack_vec(3,3,3,3,3,3,3,3); @(negedge clk);
        i_mat_waddr = 1; i_mat_wdata = pack_vec(3,3,3,3,3,3,3,3); @(negedge clk);
        i_mat_waddr = 2; i_mat_wdata = pack_vec(3,3,3,3,3,3,3,3); @(negedge clk);
        i_mat_waddr = 3; i_mat_wdata = pack_vec(3,3,3,3,3,3,3,3); @(negedge clk);
        i_mat_wen = 0;
        
        @(negedge clk);

        // ---------------------------------------------------------
        // PHASE 2: Force FSM Control Signals
        // ---------------------------------------------------------
        $display("Manually driving FSM sequence to test datapath latency...");

        // Cycle 1: First chunk
        force dut.vec_raddr = 8;
        force dut.mat_raddr = 0;
        force dut.ctrl_accum_first = 1;
        force dut.ctrl_accum_last = 0;
        force dut.ctrl_ovalid = 1;
        @(negedge clk);

        // Cycle 2: Middle chunk
        force dut.vec_raddr = 9;
        force dut.mat_raddr = 1;
        force dut.ctrl_accum_first = 0;
        force dut.ctrl_accum_last = 0;
        force dut.ctrl_ovalid = 1;
        @(negedge clk);

        // Cycle 3: Middle chunk
        force dut.vec_raddr = 10;
        force dut.mat_raddr = 2;
        force dut.ctrl_accum_first = 0;
        force dut.ctrl_accum_last = 0;
        force dut.ctrl_ovalid = 1;
        @(negedge clk);

        // Cycle 4: Last chunk
        force dut.vec_raddr = 11;
        force dut.mat_raddr = 3;
        force dut.ctrl_accum_first = 0;
        force dut.ctrl_accum_last = 1;
        force dut.ctrl_ovalid = 1;
        @(negedge clk);

        // Cycle 5: Deassert Valid (pipeline continues to flush)
        force dut.ctrl_ovalid = 0;
        
        // ---------------------------------------------------------
        // PHASE 3: Wait and Verify
        // ---------------------------------------------------------
        $display("Waiting for the 6-cycle pipeline latency to complete...");
        
        wait(o_valid == 1'b1);
        
        // Math check:
        // Lane 0: 32 elements of (1 * 2) = 64
        // Lane 1: 32 elements of (1 * 3) = 96
        
        $display("Time: %0t | MVM Computation Complete!", $time);
        $display("Lane 0 Result: %0d | Expected: 64", $signed(o_result[0 +: OWIDTH]));
        $display("Lane 1 Result: %0d | Expected: 96", $signed(o_result[OWIDTH +: OWIDTH]));
        
        if ($signed(o_result[0 +: OWIDTH]) !== 32'd64) $error("Lane 0 Integration Failed!");
        if ($signed(o_result[OWIDTH +: OWIDTH]) !== 32'd96) $error("Lane 1 Integration Failed!");
        
        // Ensure o_valid drops properly on the next cycle
        @(posedge clk);
        @(negedge clk);
        if (o_valid !== 1'b0) $error("o_valid failed to drop after 1 cycle!");

        #20;
        $display("--- Datapath Integration Verified Successfully ---");
        $finish;
    end

endmodule