//Custom dot8 tb - liam
`timescale 1ns / 1ps

module dot8_tb();

    // Parameters
    parameter IWIDTH = 8;
    parameter OWIDTH = 32;

    // Signals
    logic clk;
    logic rst;
    logic signed [8*IWIDTH-1:0] vec0;
    logic signed [8*IWIDTH-1:0] vec1;
    logic ivalid;
    logic signed [OWIDTH-1:0] result;
    logic ovalid;

    // Instantiate the Device Under Test (DUT)
    dot8 #(
        .IWIDTH(IWIDTH),
        .OWIDTH(OWIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .vec0(vec0),
        .vec1(vec1),
        .ivalid(ivalid),
        .result(result),
        .ovalid(ovalid)
    );

    // Clock generation (10ns period -> 100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Helper function to easily pack 8 integers into a 64-bit vector
    // Note: v7 is the MSB chunk, v0 is the LSB chunk
    function logic [8*IWIDTH-1:0] pack_vec(
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

    // Test Stimulus
    initial begin
        // 1. Initialize inputs and apply reset
        rst = 1;
        vec0 = 0;
        vec1 = 0;
        ivalid = 0;

        // Hold reset for a few clock cycles, then release
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        @(negedge clk);

        $display("--- Starting dot8 Simulation ---");

        // ---------------------------------------------------------
        // Test Case 1: Simple Multiplication (All 1s)
        // Expected: (1*1) * 8 lanes = 8
        // ---------------------------------------------------------
        vec0 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        vec1 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0; // Deassert ivalid to test pipeline isolation
        
        // Wait for pipeline to complete (ovalid goes high)
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 1 Result: %0d | Expected: 8", $time, result);
        if (result !== 32'd8) $error("Test 1 Failed!");
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 2: Mixed Positive and Negative Numbers
        // vec0:  1,  2, -3,  4,  5, -6,  7,  8
        // vec1:  2, -1,  2, -2,  1,  1, -1,  2
        //
        // Math: (1*2) + (2*-1) + (-3*2) + (4*-2) + (5*1) + (-6*1) + (7*-1) + (8*2)
        //       = 2 - 2 - 6 - 8 + 5 - 6 - 7 + 16 
        //       = -6
        // ---------------------------------------------------------
        vec0 = pack_vec( 1,  2, -3,  4,  5, -6,  7,  8);
        vec1 = pack_vec( 2, -1,  2, -2,  1,  1, -1,  2);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0;
        
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 2 Result: %0d | Expected: -6", $time, result);
        if (result !== -32'd6) $error("Test 2 Failed!");
        @(negedge clk);
        
// ---------------------------------------------------------
        // Test Case 3: Back-to-Back transactions
        // Ensures the pipeline doesn't overwrite data incorrectly
        // ---------------------------------------------------------
        vec0 = pack_vec(0, 0, 0, 0, 0, 0, 0, 2);
        vec1 = pack_vec(0, 0, 0, 0, 0, 0, 0, 3);
        ivalid = 1;
        @(negedge clk); // Drive first set
        
        vec0 = pack_vec(0, 0, 0, 0, 0, 0, 0, 4);
        vec1 = pack_vec(0, 0, 0, 0, 0, 0, 0, 5);
        ivalid = 1;
        @(negedge clk); // Drive second set back-to-back
        ivalid = 0;

        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 3a Result: %0d | Expected: 6", $time, result);
        
        // FIX: Wait for the next full clock cycle to clock in the back-to-back result
        @(posedge clk); 
        @(negedge clk); 
        $display("Time: %0t | Test 3b Result: %0d | Expected: 20", $time, result);
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 4: Extreme Edge Cases (Min/Max 8-bit Signed)
        // Testing the boundaries of 8-bit signed integers (-128 to 127)
        // vec0: -128, 127, -128, 127, 0, 0, 0, 0
        // vec1: -128, 127,   -1,  -1, 0, 0, 0, 0
        //
        // Math: (-128*-128) + (127*127) + (-128*-1) + (127*-1)
        //       = 16384 + 16129 + 128 - 127 
        //       = 32514
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 4 (Extreme Boundaries)...", $time);
        vec0 = pack_vec(0, 0, 0, 0,  127, -128,  127, -128);
        vec1 = pack_vec(0, 0, 0, 0,   -1,   -1,  127, -128);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0;

        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 4 Result: %0d | Expected: 32514", $time, result);
        if (result !== 32'd32514) $error("Test 4 Failed! Check bit-growth and sign extension.");
        @(negedge clk);

        // ---------------------------------------------------------
        // Test Case 5: Dirty Data / Invalid Signal Toggling
        // Ensuring that changing data while `ivalid` is low does 
        // NOT trigger a false `ovalid` or corrupt the pipeline.
        // ---------------------------------------------------------
        $display("Time: %0t | Injecting Test 5 (Dirty Valid Toggling)...", $time);
        
        // Drive valid data
        vec0 = pack_vec(0, 0, 0, 0, 0, 0, 0, 10);
        vec1 = pack_vec(0, 0, 0, 0, 0, 0, 0, 10);
        ivalid = 1;
        @(negedge clk);
        
        // Drop valid, but continuously change inputs to "garbage"
        ivalid = 0;
        vec0 = pack_vec(1, 2, 3, 4, 5, 6, 7, 8);
        vec1 = pack_vec(8, 7, 6, 5, 4, 3, 2, 1);
        @(negedge clk);
        
        vec0 = pack_vec(-1, -1, -1, -1, -1, -1, -1, -1);
        vec1 = pack_vec(-1, -1, -1, -1, -1, -1, -1, -1);
        @(negedge clk);

        // Wait for the single valid result to propagate
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 5a Result: %0d | Expected: 100", $time, result);
        if (result !== 32'd100) $error("Test 5a Failed!");
        
        // FIX: Wait for the next positive edge to clock the ovalid signal low
        @(posedge clk);
        @(negedge clk);
        if (ovalid !== 1'b0) $error("Test 5b Failed! ovalid asserted on garbage data.");
        $display("Time: %0t | Test 5b: Pipeline correctly ignored garbage data.", $time);
        
        @(posedge clk);
        @(negedge clk);
        if (ovalid !== 1'b0) $error("Test 5c Failed! ovalid asserted on garbage data.");

        // ---------------------------------------------------------
        // Test Case 6: Simple Invalid (All 1s)
        // Expected: (1*1) * 8 lanes = 8
        // ---------------------------------------------------------
        vec0 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        vec1 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0; // Deassert ivalid to test pipeline isolation
        
        // Wait for pipeline to complete (ovalid goes high)
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 6a Result: %0d | Expected: 8", $time, result);
        if (result !== 32'd8) $error("Test 6a Failed!");
        @(negedge clk);

        vec0 = pack_vec(2, 2, 2, 2, 2, 2, 2, 2);
        vec1 = pack_vec(2, 2, 2, 2, 2, 2, 2, 2);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0; // Deassert ivalid to test pipeline isolation
        
        // Wait for pipeline to complete (ovalid goes high)
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 6b Result: %0d | Expected: 32", $time, result);
        if (result !== 32'd32) $error("Test 6b Failed!");
        @(negedge clk);

        vec0 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        vec1 = pack_vec(1, 1, 1, 1, 1, 1, 1, 1);
        ivalid = 0;
        @(negedge clk);
        
        // Wait for pipeline to complete (ovalid goes high)
        vec0 = pack_vec(3, 3, 3, 3, 3, 3, 3, 3);
        vec1 = pack_vec(3, 3, 3, 3, 3, 3, 3, 3);
        ivalid = 1;
        @(negedge clk);
        ivalid = 0; // Deassert ivalid to test pipeline isolation
        
        // Wait for pipeline to complete (ovalid goes high)
        wait(ovalid == 1'b1);
        $display("Time: %0t | Test 6c Result: %0d | Expected: 72", $time, result);
        if (result !== 32'd72) $error("Test 6c Failed!");
        @(negedge clk);

        // Finish simulation
        #20;
        $display("--- Simulation Complete ---");
        $finish;
    end

endmodule
